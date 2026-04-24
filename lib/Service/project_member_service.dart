import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/membre.dart';

class ProjectMemberService {
  static final _db = Supabase.instance.client;

  // ── Lire tous les membres d'un projet ─────────────────────────────────────
  static Future<List<Membre>> getMembres(String projetId) async {
    final response = await _db
        .from('project_members')
        .select('membres(*)')
        .eq('project_id', projetId)
        .order('created_at', ascending: true);

    return (response as List)
        .map((row) => Membre.fromJson(row['membres'] as Map<String, dynamic>))
        .toList();
  }

  // ── Ajouter un membre à un projet ──────────────────────────────────────────
  static Future<void> addMembre(String projetId, String membreId) async {
    await _db.from('project_members').insert({
      'project_id': projetId,
      'membre_id': membreId,
    });
  }

  // ── Retirer un membre d'un projet ─────────────────────────────────────────
  static Future<void> removeMembre(String projetId, String membreId) async {
    await _db
        .from('project_members')
        .delete()
        .eq('project_id', projetId)
        .eq('membre_id', membreId);
  }
}