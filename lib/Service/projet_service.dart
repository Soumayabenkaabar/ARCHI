import '../core/supabase_config.dart';
import '../models/project.dart';
import '../service/auth_service.dart'; // ← services minuscule

class ProjetService {
  static final _db = SupabaseConfig.client;

  // 🔥 GET avec vrais comptages depuis les tables liées
  static Future<List<Project>> getProjets() async {
    final data = await _db
        .from('projets')
        .select()
        .order('created_at', ascending: false);

    final projects = (data as List).map((e) => Project.fromJson(e)).toList();
    if (projects.isEmpty) return projects;

    final ids = projects.map((p) => p.id).toList();

    // 4 requêtes parallèles pour les comptages réels
    final results = await Future.wait([
      _db.from('taches').select('projet_id').inFilter('projet_id', ids),
      _db.from('project_members').select('project_id, membre_id').inFilter('project_id', ids),
      _db.from('membre_taches').select('projet_id, membre_id').inFilter('projet_id', ids),
      _db.from('membres').select('id, projets_assignes'),          // filtrage en Dart
      _db.from('documents').select('projet_id').inFilter('projet_id', ids),
    ]);

    // ── Tâches ───────────────────────────────────────────────────────────────
    final tachesCount = <String, int>{};
    for (final row in (results[0] as List)) {
      final id = row['projet_id']?.toString() ?? '';
      if (id.isNotEmpty) tachesCount[id] = (tachesCount[id] ?? 0) + 1;
    }

    // ── Membres : union de 3 sources ─────────────────────────────────────────
    final membresParId = <String, Set<String>>{};

    // Source 1 : project_members (UUID → UUID)
    for (final row in (results[1] as List)) {
      final pid = row['project_id']?.toString() ?? '';
      final mid = row['membre_id']?.toString() ?? '';
      if (pid.isNotEmpty && mid.isNotEmpty) {
        membresParId.putIfAbsent(pid, () => {}).add(mid);
      }
    }

    // Source 2 : membre_taches (UUID → UUID)
    for (final row in (results[2] as List)) {
      final pid = row['projet_id']?.toString() ?? '';
      final mid = row['membre_id']?.toString() ?? '';
      if (pid.isNotEmpty && mid.isNotEmpty) {
        membresParId.putIfAbsent(pid, () => {}).add(mid);
      }
    }

    // Source 3 : membres.projets_assignes (tableau de titres → ID projet)
    final titreToId = {for (final p in projects) p.titre: p.id};
    for (final row in (results[3] as List)) {
      final mid     = row['id']?.toString() ?? '';
      final assigns = List<String>.from(row['projets_assignes'] ?? []);
      for (final titre in assigns) {
        final pid = titreToId[titre];
        if (pid != null && mid.isNotEmpty) {
          membresParId.putIfAbsent(pid, () => {}).add(mid);
        }
      }
    }

    final membresCount = membresParId.map((pid, set) => MapEntry(pid, set.length));

    // ── Documents ─────────────────────────────────────────────────────────────
    final docsCount = <String, int>{};
    for (final row in (results[4] as List)) {
      final id = row['projet_id']?.toString() ?? '';
      if (id.isNotEmpty) docsCount[id] = (docsCount[id] ?? 0) + 1;
    }

    return projects.map((p) {
      final t = tachesCount[p.id] ?? p.taches;
      final m = membresCount[p.id] ?? p.membres.length;
      final d = docsCount[p.id] ?? p.docs.length;
      return Project(
        id: p.id,
        clientId: p.clientId,
        titre: p.titre,
        description: p.description,
        statut: p.statut,
        avancement: p.avancement,
        dateDebut: p.dateDebut,
        dateFin: p.dateFin,
        budgetTotal: p.budgetTotal,
        budgetDepense: p.budgetDepense,
        client: p.client,
        localisation: p.localisation,
        chef: p.chef,
        taches: t,
        membres: m == p.membres.length ? p.membres : List.filled(m, ''),
        docs: d == p.docs.length ? p.docs : List.filled(d, ''),
        portailClient: p.portailClient,
        latitude: p.latitude,
        longitude: p.longitude,
      );
    }).toList();
  }

  // ➕ INSERT
  static Future<void> addProjet(Project projet) async {
    final json = Map<String, dynamic>.from(projet.toJson());
    json['user_id'] = AuthService.currentUser!.id;
    await _db.from('projets').insert(json);
  }

  // ✏️ UPDATE
  static Future<void> updateProjet(Project projet) async {
    await _db.from('projets').update(projet.toJson()).eq('id', projet.id);
  }

  // 💰 UPDATE budget_depense automatiquement depuis les factures
  static Future<void> syncBudgetDepense(String projetId) async {
    final factures = await _db.from('factures').select('montant').eq('projet_id', projetId);
    final total = (factures as List).fold<double>(0.0, (s, f) => s + ((f['montant'] as num?)?.toDouble() ?? 0));
    await _db.from('projets').update({'budget_depense': total}).eq('id', projetId);
  }

  // 🔄 UPDATE statut uniquement
  static Future<void> updateStatutProjet(String id, String statut) async {
    await _db.from('projets').update({'statut': statut}).eq('id', id);
  }

  // 🔄 UPDATE portail_client
  static Future<void> updatePortailClient(String id, bool value) async {
    await _db.from('projets').update({'portail_client': value}).eq('id', id);
  }

  // 📊 UPDATE avancement calculé depuis les tâches
  static Future<void> updateAvancement(String id, int avancement) async {
    await _db.from('projets').update({'avancement': avancement}).eq('id', id);
  }

  // 💰 UPDATE budget_depense calculé depuis les tâches terminées
  static Future<void> updateBudgetDepense(String id, double depense) async {
    await _db.from('projets').update({'budget_depense': depense}).eq('id', id);
  }

  // 🗑️ DELETE en cascade (respecte les contraintes FK)
  static Future<void> deleteProjet(String id) async {
    // 1. membre_taches (FK → taches ET projets)
    await _db.from('membre_taches').delete().eq('projet_id', id);
    // 2. taches (FK → phases ET projets) — après membre_taches
    await _db.from('taches').delete().eq('projet_id', id);
    // 3. factures (FK → phases ET projets) — avant phases
    await _db.from('factures').delete().eq('projet_id', id);
    // 4. phases (FK → projets) — après taches et factures
    await _db.from('phases').delete().eq('projet_id', id);
    // 5. commentaires (FK → projets ET client_portal_access) — avant client_portal_access
    await _db.from('commentaires').delete().eq('projet_id', id);
    // 6. Tables sans dépendances croisées
    await _db.from('documents').delete().eq('projet_id', id);
    await _db.from('photos_chantier').delete().eq('projet_id', id);
    await _db.from('comptes_rendus').delete().eq('projet_id', id);
    await _db.from('actualites_chantier').delete().eq('projet_id', id);
    await _db.from('defauts').delete().eq('projet_id', id);
    await _db.from('project_members').delete().eq('project_id', id);
    await _db.from('client_portal_access').delete().eq('projet_id', id);
    // 7. Projet lui-même
    await _db.from('projets').delete().eq('id', id);
  }
}
