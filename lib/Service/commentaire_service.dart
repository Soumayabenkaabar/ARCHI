import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/commentaire.dart';

/// Service Supabase pour la table `commentaires`
///
/// Table attendue :
/// ```
/// commentaires (
///   id          uuid primary key default gen_random_uuid(),
///   projet_id   uuid references projets(id) on delete cascade,
///   auteur      text not null,
///   role        text default 'architecte',  -- 'architecte' | 'client'
///   contenu     text not null,
///   created_at  timestamptz default now()
/// )
/// ```
class CommentaireService {
  static final _db = Supabase.instance.client;

  // ── Lire tous les commentaires d'un projet (ordre chronologique) ───────────
  static Future<List<Commentaire>> getCommentaires(String projetId) async {
    final response = await _db
        .from('commentaires')
        .select()
        .eq('projet_id', projetId)
        .order('created_at', ascending: true);

    return (response as List)
        .map((json) => Commentaire.fromJson(json))
        .toList();
  }

  // ── Ajouter un commentaire ─────────────────────────────────────────────────
  static Future<void> addCommentaire(Commentaire commentaire) async {
    await _db.from('commentaires').insert({
      'projet_id': commentaire.projetId,
      'auteur': commentaire.auteur,
      'role': commentaire.role,
      'contenu': commentaire.contenu,
    });
  }

  // ── Supprimer un commentaire ───────────────────────────────────────────────
  static Future<void> deleteCommentaire(String id) async {
    await _db.from('commentaires').delete().eq('id', id);
  }
}
