import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/document.dart';

/// Service Supabase pour la table `documents`
///
/// Table attendue :
/// ```
/// documents (
///   id          uuid primary key default gen_random_uuid(),
///   projet_id   uuid references projets(id) on delete cascade,
///   nom         text not null,
///   url         text not null,
///   type        text default 'autre',   -- 'pdf' | 'dwg' | 'xlsx' | 'image' | 'autre'
///   created_at  timestamptz default now()
/// )
/// ```
class DocumentService {
  static final _db = Supabase.instance.client;

  // ── Lire tous les documents d'un projet ───────────────────────────────────
  static Future<List<Document>> getDocuments(String projetId) async {
    final response = await _db
        .from('documents')
        .select()
        .eq('projet_id', projetId)
        .order('uploaded_at', ascending: true);

    return (response as List).map((json) => Document.fromJson(json)).toList();
  }

  // ── Ajouter un document ────────────────────────────────────────────────────
  static Future<void> addDocument(Document document) async {
    await _db.from('documents').insert({
      'projet_id': document.projetId,
      'nom': document.nom,
      'url': document.url,
      'type': document.type,
    });
  }

  // ── Supprimer un document ──────────────────────────────────────────────────
  static Future<void> deleteDocument(String id) async {
    await _db.from('documents').delete().eq('id', id);
  }
}
