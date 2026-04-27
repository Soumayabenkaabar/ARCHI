import 'package:flutter/foundation.dart';
import '../core/supabase_config.dart';
import '../models/membre.dart';
import '../service/auth_service.dart';

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

  // ── TÂCHES D'UN PROJET (simple, sans auto-update) ────────────────────────
  static Future<List<Map<String, dynamic>>> getTachesForProject(String projetId) async {
    final data = await supabase
        .from('taches')
        .select('id, titre, statut, date_debut, date_fin')
        .eq('projet_id', projetId)
        .order('created_at');
    return (data as List).cast<Map<String, dynamic>>();
  }

  // ── TÂCHES ASSIGNÉES À UN MEMBRE (IDs) ───────────────────────────────────
  static Future<List<String>> getMembreTacheIds(String membreId) async {
    final data = await supabase
        .from('membre_taches')
        .select('tache_id')
        .eq('membre_id', membreId);
    return (data as List).map((e) => e['tache_id'] as String).toList();
  }

  // ── TÂCHES ASSIGNÉES POUR UN PROJET PRÉCIS ───────────────────────────────
  static Future<List<String>> getMembreTacheIdsForProject(
      String membreId, String projetId) async {
    final data = await supabase
        .from('membre_taches')
        .select('tache_id')
        .eq('membre_id', membreId)
        .eq('projet_id', projetId);
    return (data as List).map((e) => e['tache_id'] as String).toList();
  }

  // ── TÂCHES ASSIGNÉES AVEC DÉTAILS (pour la fiche membre) ─────────────────
  static Future<List<Map<String, dynamic>>> getMembreTachesDetail(
      String membreId) async {
    final data = await supabase
        .from('membre_taches')
        .select('tache_id, projet_id, taches(id, titre, statut), projets(id, titre)')
        .eq('membre_id', membreId);
    return (data as List).cast<Map<String, dynamic>>();
  }

  // ── ASSIGNER TÂCHES + SYNC AUTOMATIQUE projets_assignes ──────────────────
  //
  // Règle métier : si un membre est affecté à au moins une tâche d'un projet,
  // ce projet doit apparaître dans son champ `projets_assignes`.
  // Si toutes ses tâches d'un projet sont retirées, le projet est retiré aussi.
  //
  // Flux :
  //   1. Remplace les tâches dans membre_taches pour ce projet.
  //   2. Relit TOUS les projet_ids distincts du membre depuis membre_taches.
  //   3. Résout les titres des projets actifs.
  //   4. Met à jour membres.projets_assignes + membres.disponible.
  static Future<void> assignTaches(
      String membreId, List<String> tacheIds, String projetId) async {

    // 1. Supprimer les anciennes liaisons pour ce projet
    await supabase
        .from('membre_taches')
        .delete()
        .eq('membre_id', membreId)
        .eq('projet_id', projetId);

    // 2. Insérer les nouvelles (si non vides)
    if (tacheIds.isNotEmpty) {
      await supabase.from('membre_taches').insert(
        tacheIds.map((tid) => {
          'membre_id': membreId,
          'tache_id':  tid,
          'projet_id': projetId,
        }).toList(),
      );
    }

    // 3. Resynchroniser projets_assignes depuis membre_taches ─────────────
    await _syncProjetsAssignes(membreId);
  }

  // ── SYNC projets_assignes d'un membre depuis membre_taches ───────────────
  //
  // Lit tous les projet_id distincts présents dans membre_taches pour ce membre,
  // résout leurs titres, et met à jour membres.projets_assignes + disponible.
  static Future<void> _syncProjetsAssignes(String membreId) async {
    // 3a. Récupérer les projet_ids distincts actifs dans membre_taches
    final rows = await supabase
        .from('membre_taches')
        .select('projet_id')
        .eq('membre_id', membreId);

    final projetIds = (rows as List)
        .map((r) => r['projet_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    List<String> titres = [];

    if (projetIds.isNotEmpty) {
      // 3b. Résoudre les titres depuis la table projets
      final projets = await supabase
          .from('projets')
          .select('id, titre')
          .inFilter('id', projetIds);

      titres = (projets as List)
          .map((p) => p['titre'] as String? ?? '')
          .where((t) => t.isNotEmpty)
          .toList()
        ..sort(); // ordre alphabétique stable
    }

    // 3c. Mettre à jour le membre
    await supabase.from('membres').update({
      'projets_assignes': titres,
      // disponible = true seulement s'il n'a plus aucun projet
      'disponible': titres.isEmpty,
    }).eq('id', membreId);

    debugPrint('[MembreService] sync projets_assignes → membre $membreId : $titres');
  }

  // ── TÂCHES DE TOUS LES MEMBRES (avec dates) ──────────────────────────────
  static Future<Map<String, List<Map<String, dynamic>>>> getAllMembresTachesWithDates() async {
    final data = await supabase
        .from('membre_taches')
        .select('membre_id, taches(id, date_debut, date_fin, statut)');
    final result = <String, List<Map<String, dynamic>>>{};
    for (final row in data as List) {
      final mid   = row['membre_id'] as String?;
      final tache = row['taches']   as Map<String, dynamic>?;
      if (mid == null || tache == null) continue;
      result.putIfAbsent(mid, () => []).add(tache);
    }
    return result;
  }

  // ── TÂCHES DE TOUS LES MEMBRES (enrichi pour Gantt) ──────────────────────
  static Future<Map<String, List<Map<String, dynamic>>>> getAllMembresTachesForGantt() async {
    final data = await supabase
        .from('membre_taches')
        .select('membre_id, projet_id, taches(id, titre, date_debut, date_fin, statut)');
    final result = <String, List<Map<String, dynamic>>>{};
    for (final row in data as List) {
      final mid    = row['membre_id'] as String?;
      final projId = row['projet_id'] as String?;
      final tache  = row['taches']   as Map<String, dynamic>?;
      if (mid == null || tache == null) continue;
      result.putIfAbsent(mid, () => []).add({
        ...tache,
        if (projId != null) 'projet_id': projId,
      });
    }
    return result;
  }

  // ── DÉTAIL COMPLET DES TÂCHES D'UN MEMBRE (pour tableau expandable) ──────
  static Future<List<Map<String, dynamic>>> getMembreTachesWithDetails(String membreId) async {
    final data = await supabase
        .from('membre_taches')
        .select('projet_id, taches(id, titre, statut, date_debut, date_fin), projets(id, titre)')
        .eq('membre_id', membreId);
    return (data as List).cast<Map<String, dynamic>>();
  }

  // ── MEMBRES PAR TÂCHE (pour un projet) ───────────────────────────────────
  static Future<Map<String, List<Map<String, String>>>> getMembresParTacheDetail(
      String projetId) async {
    final data = await supabase
        .from('membre_taches')
        .select('tache_id, membres(id, nom)')
        .eq('projet_id', projetId);
    final result = <String, List<Map<String, String>>>{};
    for (final row in data as List) {
      final tacheId    = row['tache_id']  as String?;
      final membreInfo = row['membres']   as Map<String, dynamic>?;
      if (tacheId == null || membreInfo == null) continue;
      result.putIfAbsent(tacheId, () => []);
      result[tacheId]!.add({
        'id':  membreInfo['id']  as String? ?? '',
        'nom': membreInfo['nom'] as String? ?? '',
      });
    }
    return result;
  }

  // ── ASSIGNER MEMBRES À UNE TÂCHE (depuis la vue projet/tâches) ───────────
  //
  // Remplace les membres d'une tâche ET synchronise projets_assignes
  // pour chaque membre ajouté ou retiré.
  static Future<void> assignMembresForTache(
      String tacheId, List<String> membreIds, String projetId) async {

    // Récupérer les anciens membres de cette tâche avant suppression
    final oldRows = await supabase
        .from('membre_taches')
        .select('membre_id')
        .eq('tache_id', tacheId)
        .eq('projet_id', projetId);
    final oldMembreIds = (oldRows as List)
        .map((r) => r['membre_id'] as String?)
        .whereType<String>()
        .toSet();

    // Supprimer les anciennes liaisons
    await supabase
        .from('membre_taches')
        .delete()
        .eq('tache_id', tacheId)
        .eq('projet_id', projetId);

    // Insérer les nouvelles liaisons
    if (membreIds.isNotEmpty) {
      await supabase.from('membre_taches').insert(
        membreIds.map((mid) => {
          'membre_id': mid,
          'tache_id':  tacheId,
          'projet_id': projetId,
        }).toList(),
      );
    }

    // Synchroniser projets_assignes pour tous les membres impactés
    final allImpacted = {...oldMembreIds, ...membreIds};
    for (final mid in allImpacted) {
      await _syncProjetsAssignes(mid);
    }
  }
  // ── SYNC GLOBALE — à appeler au démarrage pour corriger les données existantes ──
  // Reconstruit projets_assignes pour TOUS les membres depuis membre_taches.
  // Utile pour migrer des données existantes créées avant l'auto-sync.
  static Future<void> syncAllProjetsAssignes() async {
    // 1. Récupérer tous les membre_ids distincts dans membre_taches
    final rows = await supabase
        .from('membre_taches')
        .select('membre_id');

    final memberIds = (rows as List)
        .map((r) => r['membre_id'] as String?)
        .whereType<String>()
        .toSet();

    // 2. Récupérer tous les membres (pour inclure ceux sans tâches)
    final allMembres = await supabase.from('membres').select('id');
    for (final m in allMembres as List) {
      memberIds.add(m['id'] as String);
    }

    // 3. Sync chaque membre
    for (final mid in memberIds) {
      await _syncProjetsAssignes(mid);
    }
    debugPrint('[MembreService] syncAllProjetsAssignes → ${memberIds.length} membres synchronisés');
  }


}