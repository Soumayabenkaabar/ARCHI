import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/phase.dart';
import '../service/auth_service.dart';

class PhaseService {
  static final _db = Supabase.instance.client;

  // ── Lire toutes les phases d'un projet (triées par ordre) ──────────────────
  static Future<List<Phase>> getPhases(String projetId) async {
    final response = await _db
        .from('phases')
        .select()
        .eq('projet_id', projetId)
        .order('ordre', ascending: true);
    return (response as List).map((j) => Phase.fromJson(j as Map<String, dynamic>)).toList();
  }

  // ── Créer une phase ────────────────────────────────────────────────────────
  static Future<Phase> addPhase(String projetId, String nom, int ordre) async {
    final payload = <String, dynamic>{
      'projet_id': projetId,
      'nom':       nom,
      'ordre':     ordre,
    };
    final uid = AuthService.currentUser?.id;
    if (uid != null) payload['user_id'] = uid;

    final res = await _db
        .from('phases')
        .insert(payload)
        .select()
        .single();
    return Phase.fromJson(res as Map<String, dynamic>);
  }

  // ── Renommer une phase ─────────────────────────────────────────────────────
  static Future<void> updatePhase(String id, String nom) async {
    await _db.from('phases').update({'nom': nom}).eq('id', id);
  }

  // ── Supprimer une phase (les tâches gardent phase_id = NULL) ───────────────
  static Future<void> deletePhase(String id) async {
    await _db.from('phases').delete().eq('id', id);
  }

  // ── Réordonner les phases ──────────────────────────────────────────────────
  static Future<void> reorderPhases(List<Phase> phases) async {
    for (int i = 0; i < phases.length; i++) {
      await _db.from('phases').update({'ordre': i}).eq('id', phases[i].id);
    }
  }
}