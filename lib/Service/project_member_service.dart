import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/membre.dart';

/// Service Supabase pour la table `projet_membres`
///
/// Table attendue :
/// ```
/// projet_membres (
///   id          uuid primary key default gen_random_uuid(),
///   projet_id   uuid references projets(id) on delete cascade,
///   membre_id   uuid references membres(id) on delete cascade,
///   created_at  timestamptz default now()
/// )
///
/// membres (
///   id          uuid primary key default gen_random_uuid(),
///   nom         text not null,
///   role        text not null,
///   email       text,
///   telephone   text,
///   created_at  timestamptz default now()
/// )
/// ```
class ProjectMemberService {
  static final _db = Supabase.instance.client;

  // ── Lire tous les membres d'un projet ─────────────────────────────────────
  /// Fait un JOIN entre `projet_membres` et `membres`
  static Future<List<Membre>> getMembres(String projetId) async {
    final response = await _db
        .from('projet_membres')
        .select('membres(*)')
        .eq('projet_id', projetId)
        .order('created_at', ascending: true);

    return (response as List)
        .map((row) => Membre.fromJson(row['membres'] as Map<String, dynamic>))
        .toList();
  }

  // ── Ajouter un membre à un projet ──────────────────────────────────────────
  static Future<void> addMembre(String projetId, String membreId) async {
    await _db.from('projet_membres').insert({
      'projet_id': projetId,
      'membre_id': membreId,
    });
  }

  // ── Retirer un membre d'un projet ─────────────────────────────────────────
  static Future<void> removeMembre(String projetId, String membreId) async {
    await _db
        .from('projet_membres')
        .delete()
        .eq('projet_id', projetId)
        .eq('membre_id', membreId);
  }
}
