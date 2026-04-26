import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:archi_manager/service/disponibilite_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  CongeService — CRUD congés
// ══════════════════════════════════════════════════════════════════════════════
class CongeService {
  static final _db = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> getConges(String membreId) async {
    final data = await _db
        .from('conges')
        .select()
        .eq('membre_id', membreId)
        .order('date_debut', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<List<Map<String, dynamic>>> getTousConges() async {
    final data = await _db
        .from('conges')
        .select('*, membres(nom, role)')
        .order('date_debut', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> addConge({
    required String membreId,
    required String type,
    required DateTime dateDebut,
    required DateTime dateFin,
    String  motif  = '',
    String  statut = 'approuve',
  }) async {
    if (dateFin.isBefore(dateDebut)) throw Exception('Date de fin avant date de début');

    final nbJours = await DisponibiliteService.calculerJoursOuvrables(
        dateDebut, dateFin);

    // Vérifier le solde si congé annuel
    if (type == 'annuel') {
      final solde = await DisponibiliteService.getSoldeConges(
          membreId, dateDebut.year);
      if (nbJours > solde) {
        throw Exception(
            'Solde insuffisant ($solde jours restants, $nbJours demandés)');
      }
    }

    await _db.from('conges').insert({
      'membre_id':  membreId,
      'type':       type,
      'date_debut': dateDebut.toIso8601String().substring(0, 10),
      'date_fin':   dateFin.toIso8601String().substring(0, 10),
      'nb_jours':   nbJours,
      'statut':     statut,
      'motif':      motif,
    });
  }

  static Future<void> updateStatut(String id, String statut) async {
    await _db.from('conges').update({'statut': statut}).eq('id', id);
  }

  static Future<void> deleteConge(String id) async {
    await _db.from('conges').delete().eq('id', id);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  AbsenceService — CRUD absences
// ══════════════════════════════════════════════════════════════════════════════
class AbsenceService {
  static final _db = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> getAbsences(
      String membreId) async {
    final data = await _db
        .from('absences')
        .select()
        .eq('membre_id', membreId)
        .order('date', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> addAbsence({
    required String  membreId,
    required DateTime date,
    required String  type,
    double  dureeHeures = 8,
    String  motif = '',
  }) async {
    await _db.from('absences').insert({
      'membre_id':    membreId,
      'date':         date.toIso8601String().substring(0, 10),
      'type':         type,
      'duree_heures': dureeHeures,
      'motif':        motif,
    });
  }

  static Future<void> deleteAbsence(String id) async {
    await _db.from('absences').delete().eq('id', id);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TacheMembreService — liaison tâche ↔ membre
// ══════════════════════════════════════════════════════════════════════════════
class TacheMembreService {
  static final _db = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> getMembresDeLatache(
      String tacheId) async {
    final data = await _db
        .from('tache_membres')
        .select('*, membres(*)')
        .eq('tache_id', tacheId);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<List<Map<String, dynamic>>> getTachesDuMembre(
      String membreId) async {
    final data = await _db
        .from('tache_membres')
        .select('*, taches(*)')
        .eq('membre_id', membreId);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> assignerMembre({
    required String tacheId,
    required String membreId,
    String roleTache = 'executant',
  }) async {
    await _db.from('tache_membres').upsert({
      'tache_id':   tacheId,
      'membre_id':  membreId,
      'role_tache': roleTache,
    }, onConflict: 'tache_id,membre_id');
  }

  static Future<void> retirerMembre({
    required String tacheId,
    required String membreId,
  }) async {
    await _db.from('tache_membres')
        .delete()
        .eq('tache_id', tacheId)
        .eq('membre_id', membreId);
  }
}