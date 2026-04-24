import 'package:flutter/foundation.dart';
import '../core/supabase_config.dart';
import '../models/membre.dart';
import '../service/auth_service.dart'; // ← services minuscule

class MembreService {
  static final supabase = SupabaseConfig.client;

  // ── GET ───────────────────────────────────────────────────────────────────
  static Future<List<Membre>> getMembres() async {
    final data = await supabase.from('membres').select();
    return (data as List).map((e) => Membre.fromJson(e)).toList();
  }

  // ── ADD ───────────────────────────────────────────────────────────────────
  static Future<void> addMembre(Membre membre) async {
    final json = Map<String, dynamic>.from(membre.toJson());
    json['user_id'] = AuthService.currentUser!.id;
    await supabase.from('membres').insert(json);
  }

  // ── UPDATE ────────────────────────────────────────────────────────────────
  static Future<void> updateMembre(Membre membre) async {
    if (membre.id.isEmpty) throw Exception("ID membre invalide");
    await supabase.from('membres').update(membre.toJson()).eq('id', membre.id);
  }

  // ── DELETE ────────────────────────────────────────────────────────────────
  static Future<void> deleteMembre(String id) async {
    await supabase.from('membres').delete().eq('id', id);
  }

  // ── ASSIGN TO PROJECT ─────────────────────────────────────────────────────
  static Future<void> assignToProject({
    required String membreId,
    required String projectId,
  }) async {
    await supabase.from('project_members').insert({
      'membre_id': membreId,
      'project_id': projectId,
    });
  }

  // ── ASSIGN ────────────────────────────────────────────────────────────────
  static Future<void> assignMembre({
    required Membre membre,
    required String projet,
  }) async {
    if (membre.id.isEmpty) return;
    final updatedProjects = List<String>.from(membre.projetsAssignes);
    if (!updatedProjects.contains(projet)) updatedProjects.add(projet);
    await supabase
        .from('membres')
        .update({'projets_assignes': updatedProjects, 'disponible': false})
        .eq('id', membre.id);
    debugPrint("ASSIGNED: $projet to ${membre.nom}");
  }

  // ── GET PAR PROJET (via projets_assignes = tableau de titres) ────────────
  static Future<List<Membre>> getMembresByProject(String projetTitre) async {
    final data = await supabase
        .from('membres')
        .select()
        .contains('projets_assignes', [projetTitre]);
    return (data as List).map((e) => Membre.fromJson(e)).toList();
  }
}