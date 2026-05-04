import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification.dart';
import 'auth_service.dart';
import 'notification_service.dart';

class NotificationChecker {
  static final _db = Supabase.instance.client;

  // ── Point d'entrée principal ───────────────────────────────────────────────
  static Future<void> checkAll() async {
    final uid = AuthService.currentUser?.id;
    if (uid == null) return;

    try {
      final projets = await _db
          .from('projets')
          .select('id, titre, date_fin, statut')
          .eq('user_id', uid);

      for (final p in projets as List) {
        final id     = p['id']     as String? ?? '';
        final titre  = p['titre']  as String? ?? '';
        final statut = p['statut'] as String? ?? '';
        if (id.isEmpty || statut == 'annule') continue;

        await Future.wait([
          _checkBudgetVsFactures(id, titre),
          _checkTachesSansMembre(id, titre, statut),
          _checkTachesEnRetard(id, titre, statut),
          _checkFacturesEnRetard(id, titre),
          _checkDeadlineProjet(titre, p['date_fin'] as String?, statut),
        ]);
      }
    } catch (_) {}
  }

  // ── 1. Budget tâches > somme des factures ──────────────────────────────────
  static Future<void> _checkBudgetVsFactures(String projetId, String titre) async {
    try {
      final taches   = await _db.from('taches').select('budget_estime').eq('projet_id', projetId);
      final factures = await _db.from('factures').select('montant').eq('projet_id', projetId);

      final totalTaches   = (taches as List).fold<double>(0, (s, t) => s + ((t['budget_estime'] as num?)?.toDouble() ?? 0));
      final totalFactures = (factures as List).fold<double>(0, (s, f) => s + ((f['montant'] as num?)?.toDouble() ?? 0));

      if (totalTaches > totalFactures && totalFactures > 0) {
        await NotificationService.add(
          message: 'Budget des tâches (${totalTaches.toStringAsFixed(0)} DT) dépasse le total facturé (${totalFactures.toStringAsFixed(0)} DT)',
          projet: titre,
          type: NotifType.budget,
        );
      }
    } catch (_) {}
  }

  // ── 2. Tâches sans membre assigné (non terminées) ─────────────────────────
  static Future<void> _checkTachesSansMembre(String projetId, String titre, String statut) async {
    if (statut == 'termine') return;
    try {
      final taches = await _db
          .from('taches')
          .select('id, titre')
          .eq('projet_id', projetId)
          .neq('statut', 'termine');

      final assignedRows = await _db
          .from('membre_taches')
          .select('tache_id')
          .eq('projet_id', projetId);
      final assigned = (assignedRows as List).map((r) => r['tache_id'] as String).toSet();

      for (final t in taches as List) {
        final tacheId    = t['id']    as String? ?? '';
        final tacheTitre = t['titre'] as String? ?? '';
        if (tacheId.isEmpty || assigned.contains(tacheId)) continue;
        await NotificationService.add(
          message: 'Tâche «$tacheTitre» sans membre assigné',
          projet: titre,
          type: NotifType.retard,
        );
      }
    } catch (_) {}
  }

  // ── 3. Tâches en retard (date_fin dépassée, non terminées) ────────────────
  static Future<void> _checkTachesEnRetard(String projetId, String titre, String statut) async {
    if (statut == 'termine') return;
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final taches = await _db
          .from('taches')
          .select('titre')
          .eq('projet_id', projetId)
          .neq('statut', 'termine')
          .lt('date_fin', today)
          .not('date_fin', 'is', null);

      for (final t in taches as List) {
        final tacheTitre = t['titre'] as String? ?? '';
        if (tacheTitre.isEmpty) continue;
        await NotificationService.add(
          message: 'Tâche «$tacheTitre» en retard (échéance dépassée)',
          projet: titre,
          type: NotifType.retard,
        );
      }
    } catch (_) {}
  }

  // ── 4. Factures en retard de paiement ─────────────────────────────────────
  static Future<void> _checkFacturesEnRetard(String projetId, String titre) async {
    try {
      final factures = await _db
          .from('factures')
          .select('numero')
          .eq('projet_id', projetId)
          .eq('statut', 'en_retard');

      for (final f in factures as List) {
        final numero = f['numero'] as String? ?? '';
        if (numero.isEmpty) continue;
        await NotificationService.add(
          message: 'Facture N° $numero en retard de paiement',
          projet: titre,
          type: NotifType.budget,
        );
      }
    } catch (_) {}
  }

  // ── 5. Délai du projet bientôt atteint (≤ 7 jours) ───────────────────────
  static Future<void> _checkDeadlineProjet(String titre, String? dateFin, String statut) async {
    if (dateFin == null || statut == 'termine') return;
    try {
      final fin  = DateTime.parse(dateFin);
      final diff = fin.difference(DateTime.now()).inDays;
      if (diff >= 0 && diff <= 7) {
        await NotificationService.add(
          message: 'Délai du projet bientôt atteint (moins de 7 jours)',
          projet: titre,
          type: NotifType.retard,
        );
      }
    } catch (_) {}
  }
}
