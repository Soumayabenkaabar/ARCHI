// lib/service/facture_service.dart
// ══════════════════════════════════════════════════════════════════════════════
//  FactureService — CRUD complet avec updateFacture
// ══════════════════════════════════════════════════════════════════════════════

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/facture.dart';

class FactureService {

  static SupabaseClient get _db => Supabase.instance.client;

  // ── Lire toutes les factures d'un projet ────────────────────────────────────
  static Future<List<Facture>> getFactures(String projetId) async {
    final data = await _db
        .from('factures')
        .select()
        .eq('projet_id', projetId)
        .order('created_at', ascending: true);

    return (data as List)
        .map((e) => Facture.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Ajouter une facture ─────────────────────────────────────────────────────
  static Future<void> addFacture(Facture facture) async {
    await _db.from('factures').insert(facture.toJson());
  }

  // ── Modifier une facture existante ──────────────────────────────────────────
  static Future<void> updateFacture(Facture facture) async {
    await _db
        .from('factures')
        .update(facture.toJson())
        .eq('id', facture.id);
  }

  // ── Supprimer une facture ───────────────────────────────────────────────────
  static Future<void> deleteFacture(String id) async {
    await _db.from('factures').delete().eq('id', id);
  }

  // ── Mettre à jour le statut uniquement ─────────────────────────────────────
  static Future<void> updateStatut(String id, String statut) async {
    await _db
        .from('factures')
        .update({'statut': statut})
        .eq('id', id);
  }
}