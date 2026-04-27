import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tache.dart';

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
    for (final t in taches) {
      if (t.statut != 'termine' && t.dateFin != null) {
        final fin = DateTime.tryParse(t.dateFin!);
        if (fin != null && fin.isBefore(today)) {
          await _db.from('taches').update({'statut': 'termine'}).eq('id', t.id);
          if (t.budgetEstime > 0) await _addToDepense(projetId, t.budgetEstime);
        }
      }
    }
  }

  static Future<String> addTache(Tache tache) async {
    final payload = <String, dynamic>{
      'projet_id':     tache.projetId,
      'titre':         tache.titre,
      'description':   tache.description,
      'statut':        tache.statut,
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
    return result['id'] as String;
  }

  static Future<void> updateTache(Tache tache) async {
    await _db.from('taches').update({
      'titre':         tache.titre,
      'description':   tache.description,
      'statut':        tache.statut,
      'phase_id':      tache.phaseId,
      'date_debut':    tache.dateDebut,
      'date_fin':      tache.dateFin,
      'budget_estime': tache.budgetEstime,
      'remarques':     tache.remarques,
      'phase':         tache.phase,
    }).eq('id', tache.id);
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