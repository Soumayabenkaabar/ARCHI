import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tache.dart';
import '../models/notification.dart';
import 'notification_service.dart';
import 'historique_service.dart';

class TacheService {
  static final _db = Supabase.instance.client;

  static Future<List<Tache>> getTaches(String projetId) async {
    final response = await _db
        .from('taches')
        .select()
        .eq('projet_id', projetId)
        .order('created_at', ascending: true);

    final taches = (response as List)
        .map((j) => Tache.fromJson(j as Map<String, dynamic>))
        .toList();

    await _autoUpdateStatuts(taches, projetId);

    final updated = await _db
        .from('taches')
        .select()
        .eq('projet_id', projetId)
        .order('created_at', ascending: true);
    return (updated as List)
        .map((j) => Tache.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  static Future<void> _autoUpdateStatuts(
      List<Tache> taches, String projetId) async {
    final today = DateTime.now();

    final projetData  = await _getProjetDates(projetId);
    final projetFin   = DateTime.tryParse(projetData['date_fin']   ?? '');
    final projetTitre = projetData['titre'] ?? '';

    for (final t in taches) {
      if (t.dateFin == null) continue;
      final tacheFin = DateTime.tryParse(t.dateFin!);
      if (tacheFin == null) continue;

      // Rule: task date_fin exceeds project date_fin → retard
      if (projetFin != null &&
          tacheFin.isAfter(projetFin) &&
          t.statut != 'retard') {
        await _db.from('taches').update({'statut': 'retard'}).eq('id', t.id);
        _fireRetardNotification(t.titre, projetTitre, t.dateFin!);
        _fireRetardHistorique(
          tacheId:     t.id,
          projetId:    projetId,
          tacheTitre:  t.titre,
          dateFin:     t.dateFin!,
          statutAvant: t.statut,
        );
        continue; // skip the auto-complete check below
      }

      // Existing: auto-complete when past today (skip already-retard tasks)
      if (t.statut != 'termine' && t.statut != 'retard' &&
          tacheFin.isBefore(today)) {
        await _db.from('taches').update({'statut': 'termine'}).eq('id', t.id);
        if (t.budgetEstime > 0) await _addToDepense(projetId, t.budgetEstime);
      }
    }
  }

  static Future<String> addTache(Tache tache) async {
    final v = await _validateDates(tache);

    final payload = <String, dynamic>{
      'projet_id':     tache.projetId,
      'titre':         tache.titre,
      'description':   tache.description,
      'statut':        v.statut,
      'date_debut':    tache.dateDebut,
      'date_fin':      tache.dateFin,
      'budget_estime': tache.budgetEstime,
      'remarques':     tache.remarques,
      'phase':         tache.phase,
    };
    if (tache.phaseId != null && tache.phaseId!.isNotEmpty) {
      payload['phase_id'] = tache.phaseId;
    }
    final result = await _db.from('taches').insert(payload).select('id').single();
    final newId  = result['id'] as String;

    if (v.isRetard) {
      _fireRetardNotification(tache.titre, v.projetTitre, tache.dateFin!);
      _fireRetardHistorique(
        tacheId:     newId,
        projetId:    tache.projetId,
        tacheTitre:  tache.titre,
        dateFin:     tache.dateFin!,
        statutAvant: null,
      );
    }

    return newId;
  }

  static Future<void> updateTache(Tache tache) async {
    final v = await _validateDates(tache);

    await _db.from('taches').update({
      'titre':         tache.titre,
      'description':   tache.description,
      'statut':        v.statut,
      'phase_id':      tache.phaseId,
      'date_debut':    tache.dateDebut,
      'date_fin':      tache.dateFin,
      'budget_estime': tache.budgetEstime,
      'remarques':     tache.remarques,
      'phase':         tache.phase,
    }).eq('id', tache.id);

    if (v.isRetard) {
      _fireRetardNotification(tache.titre, v.projetTitre, tache.dateFin!);
      _fireRetardHistorique(
        tacheId:     tache.id,
        projetId:    tache.projetId,
        tacheTitre:  tache.titre,
        dateFin:     tache.dateFin!,
        statutAvant: tache.statut,
      );
    }
  }

  static Future<void> updateStatut(
    String id,
    String nouveauStatut, {
    required String projetId,
    required String ancienStatut,
    required double budgetEstime,
  }) async {
    await _db.from('taches').update({'statut': nouveauStatut}).eq('id', id);
    if (budgetEstime > 0) {
      if (nouveauStatut == 'termine' && ancienStatut != 'termine') {
        await _addToDepense(projetId, budgetEstime);
      } else if (nouveauStatut != 'termine' && ancienStatut == 'termine') {
        await _addToDepense(projetId, -budgetEstime);
      }
    }
  }

  static Future<void> deleteTache(String id) async {
    await _db.from('taches').delete().eq('id', id);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static Future<Map<String, String?>> _getProjetDates(String projetId) async {
    final res = await _db
        .from('projets')
        .select('date_debut, date_fin, titre')
        .eq('id', projetId)
        .single();
    return {
      'date_debut': res['date_debut'] as String?,
      'date_fin':   res['date_fin']   as String?,
      'titre':      res['titre']      as String? ?? '',
    };
  }

  /// Validates task dates against the project's date range.
  /// Throws [Exception] if task starts before the project.
  /// Returns the effective statut and whether a retard was detected.
  static Future<({String statut, bool isRetard, String projetTitre})>
      _validateDates(Tache tache) async {
    final projetData  = await _getProjetDates(tache.projetId);
    final projetDebut = DateTime.tryParse(projetData['date_debut'] ?? '');
    final projetFin   = DateTime.tryParse(projetData['date_fin']   ?? '');
    final projetTitre = projetData['titre'] ?? '';

    // Rule 1: task cannot start before the project
    if (tache.dateDebut != null && projetDebut != null) {
      final tacheDebut = DateTime.tryParse(tache.dateDebut!);
      if (tacheDebut != null && tacheDebut.isBefore(projetDebut)) {
        throw Exception(
          'La date de début de la tâche ne peut pas être antérieure '
          'à la date de début du projet.',
        );
      }
    }

    // Rule 2: task date_fin exceeds project date_fin → retard
    bool   isRetard = false;
    String statut   = tache.statut;
    if (tache.dateFin != null && projetFin != null) {
      final tacheFin = DateTime.tryParse(tache.dateFin!);
      if (tacheFin != null && tacheFin.isAfter(projetFin)) {
        isRetard = true;
        statut   = 'retard';
      }
    }

    return (statut: statut, isRetard: isRetard, projetTitre: projetTitre);
  }

  /// Fire-and-forget: create a retard notification (deduplication is built in).
  static void _fireRetardNotification(
      String tacheTitre, String projetTitre, String dateFin) {
    NotificationService.add(
      message: 'La tâche "$tacheTitre" dépasse la date de fin du projet '
               '(échéance : $dateFin)',
      projet: projetTitre,
      type:   NotifType.retard,
    );
  }

  /// Fire-and-forget: record the retard event in the task history.
  static void _fireRetardHistorique({
    required String  tacheId,
    required String  projetId,
    required String  tacheTitre,
    required String  dateFin,
    required String? statutAvant,
  }) {
    HistoriqueService.addEvenement(
      tacheId:     tacheId,
      projetId:    projetId,
      evenement:   'Tâche "$tacheTitre" mise en retard : '
                   'date de fin ($dateFin) dépasse la date de fin du projet.',
      statutAvant: statutAvant,
      statutApres: 'retard',
    );
  }

  static Future<void> _addToDepense(String projetId, double montant) async {
    final res = await _db
        .from('projets')
        .select('budget_depense')
        .eq('id', projetId)
        .single();
    final current = (res['budget_depense'] as num?)?.toDouble() ?? 0;
    final newVal  = (current + montant).clamp(0.0, double.infinity);
    await _db.from('projets').update({'budget_depense': newVal}).eq('id', projetId);
  }
}
