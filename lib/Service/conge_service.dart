import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/conge.dart';
import '../models/membre.dart';
import '../models/tache.dart';
import 'membre_service.dart';

class CongeService {
  static final _db = Supabase.instance.client;

  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── GET tous les congés ───────────────────────────────────────────────────
  static Future<List<Conge>> getAllConges() async {
    final data = await _db.from('conges').select();
    return (data as List).map((e) => Conge.fromJson(e)).toList();
  }

  // ── GET pour un membre ────────────────────────────────────────────────────
  static Future<List<Conge>> getCongesForMembre(String membreId) async {
    final data = await _db
        .from('conges')
        .select()
        .eq('membre_id', membreId)
        .order('date_debut', ascending: false);
    return (data as List).map((e) => Conge.fromJson(e)).toList();
  }

  // ── GET congés actifs (aujourd'hui entre dateDebut et dateFin) ────────────
  static Future<List<Conge>> getActiveConges() async {
    final today = _dateStr(DateTime.now());
    final data = await _db
        .from('conges')
        .select()
        .lte('date_debut', today)
        .gte('date_fin', today);
    return (data as List).map((e) => Conge.fromJson(e)).toList();
  }

  // ── ADD ───────────────────────────────────────────────────────────────────
  static Future<void> addConge({
    required String membreId,
    required DateTime dateDebut,
    required DateTime dateFin,
    required String motif,
  }) async {
    await _db.from('conges').insert({
      'membre_id':  membreId,
      'date_debut': _dateStr(dateDebut),
      'date_fin':   _dateStr(dateFin),
      'motif':      motif,
    });
  }

  // ── DELETE ────────────────────────────────────────────────────────────────
  static Future<void> deleteConge(String id) async {
    await _db.from('conges').delete().eq('id', id);
  }

  // ── DÉCALER LES TÂCHES ────────────────────────────────────────────────────
  // Si le membre a des tâches spécifiquement assignées (membre_taches),
  // seules celles-ci sont décalées. Sinon, toutes les tâches non terminées
  // de ses projets sont décalées (comportement de repli).
  static Future<int> applyTaskDelay(
    Membre membre,
    DateTime dateDebutConge,
    DateTime dateFinConge,
  ) async {
    final duree = dateFinConge.difference(dateDebutConge).inDays + 1;
    int count = 0;

    // Priorité : tâches spécifiquement assignées
    final assignedIds = await MembreService.getMembreTacheIds(membre.id);

    if (assignedIds.isNotEmpty) {
      for (final tacheId in assignedIds) {
        final row = await _db
            .from('taches')
            .select()
            .eq('id', tacheId)
            .neq('statut', 'termine')
            .maybeSingle();
        if (row == null) continue;
        count += await _delayTache(Tache.fromJson(row), duree, dateDebutConge, dateFinConge);
      }
      return count;
    }

    // Repli : toutes les tâches des projets assignés
    if (membre.projetsAssignes.isEmpty) return 0;
    for (final titre in membre.projetsAssignes) {
      final projData = await _db.from('projets').select('id').eq('titre', titre);
      for (final p in projData as List) {
        final rows = await _db
            .from('taches')
            .select()
            .eq('projet_id', p['id'] as String)
            .neq('statut', 'termine');
        for (final tj in rows as List) {
          count += await _delayTache(
              Tache.fromJson(tj), duree, dateDebutConge, dateFinConge);
        }
      }
    }
    return count;
  }

  static Future<int> _delayTache(
    Tache tache,
    int duree,
    DateTime dateDebutConge,
    DateTime dateFinConge,
  ) async {
    if (tache.dateFin == null) return 0;
    final tacheFin = DateTime.tryParse(tache.dateFin!);
    if (tacheFin == null) return 0;
    final tacheDebut = tache.dateDebut != null
        ? (DateTime.tryParse(tache.dateDebut!) ?? dateDebutConge)
        : dateDebutConge;
    if (dateDebutConge.isAfter(tacheFin) || dateFinConge.isBefore(tacheDebut)) return 0;
    final newFin = tacheFin.add(Duration(days: duree));
    await _db.from('taches').update({'date_fin': _dateStr(newFin)}).eq('id', tache.id);
    return 1;
  }
}
