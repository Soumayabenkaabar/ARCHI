import 'package:archi_manager/models/project.dart';
import 'package:archi_manager/screens/projet_detail_screen.dart';
import 'package:archi_manager/screens/projets_screen.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';
import '../models/notification.dart';
import '../service/notification_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MODELS
// ═══════════════════════════════════════════════════════════════════════════════

class DashboardStats {
  final int totalProjets;
  final int projetsActifs;
  final int projetsTermines;
  final double budgetTotal;
  final double budgetDepense;
  final int totalAlertes;
  final int alertesBudget;
  final int alertesRetard;

  double get progressionGlobale =>
      budgetTotal > 0 ? (budgetDepense / budgetTotal).clamp(0.0, 1.0) : 0.0;

  double get progressionPourcent => progressionGlobale * 100;

  const DashboardStats({
    required this.totalProjets,
    required this.projetsActifs,
    required this.projetsTermines,
    required this.budgetTotal,
    required this.budgetDepense,
    required this.totalAlertes,
    required this.alertesBudget,
    required this.alertesRetard,
  });
}

class ProjetResume {
  final String id;
  final String titre;
  final String client;
  final String localisation;
  final int avancement;
  final double budgetTotal;
  final double budgetDepense;
  final String? dateFin;
  final String statut;
  final int taches;

  const ProjetResume({
    required this.id,
    required this.titre,
    required this.client,
    required this.localisation,
    required this.avancement,
    required this.budgetTotal,
    required this.budgetDepense,
    this.dateFin,
    required this.statut,
    required this.taches,
  });

  factory ProjetResume.fromJson(Map<String, dynamic> j) => ProjetResume(
        id: j['id'] as String,
        titre: j['titre'] as String? ?? '',
        client: j['client'] as String? ?? '',
        localisation: j['localisation'] as String? ?? '',
        avancement: j['avancement'] as int? ?? 0,
        budgetTotal: (j['budget_total'] as num?)?.toDouble() ?? 0,
        budgetDepense: (j['budget_depense'] as num?)?.toDouble() ?? 0,
        dateFin: j['date_fin'] as String?,
        statut: j['statut'] as String? ?? 'en_cours',
        taches: j['taches'] as int? ?? 0,
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onNavigateToProjects;
  final Function(Project)? onViewProject;
  const DashboardScreen({super.key, this.onNavigateToProjects, this.onViewProject});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _supabase = Supabase.instance.client;

  bool _loading = true;
  String? _error;

  DashboardStats? _stats;
  List<AppNotification> _notifications = [];
  List<ProjetResume> _projets = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  // ── Data Fetching ────────────────────────────────────────────────────────────

  Future<void> _loadAll({int retry = 0}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = _supabase.auth.currentUser;
      // Si pas encore authentifié, on réessaie une fois après 800ms
      if (user == null && retry == 0) {
        await Future.delayed(const Duration(milliseconds: 800));
        return _loadAll(retry: 1);
      }
      final userId = user?.id;

      await Future.wait([
        _fetchStats(userId),
        _fetchProjetsEnCours(userId),
      ]);
    } catch (e) {
      debugPrint('ERREUR dashboard: $e');
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchStats(String? userId) async {
    List projetsRaw;
    if (userId != null) {
      projetsRaw = await _supabase
          .from('projets')
          .select('id, statut, budget_total, budget_depense, avancement, titre, date_fin')
          .eq('user_id', userId) as List;
    } else {
      projetsRaw = await _supabase.from('projets').select(
          'id, statut, budget_total, budget_depense, avancement, titre, date_fin') as List;
    }

    int actifs = 0;
    int termines = 0;
    double budgetTotal = 0;
    double budgetDepense = 0;

    for (final p in projetsRaw) {
      final statut = (p['statut'] as String? ?? '').trim().toLowerCase();
      budgetTotal  += (p['budget_total']   as num?)?.toDouble() ?? 0;
      budgetDepense += (p['budget_depense'] as num?)?.toDouble() ?? 0;
      if (statut == 'en_cours') actifs++;
      if (statut == 'termine')  termines++;
    }

    // Notifications réelles depuis Supabase (triées par date desc)
    final allNotifs   = await NotificationService.getAll();
    final nonLues     = allNotifs.where((n) => !n.lue).toList();
    final budgetCount = nonLues.where((n) => n.type == NotifType.budget).length;
    final retardCount = nonLues.where((n) => n.type == NotifType.retard).length;

    setState(() {
      _stats = DashboardStats(
        totalProjets:    projetsRaw.length,
        projetsActifs:   actifs,
        projetsTermines: termines,
        budgetTotal:     budgetTotal,
        budgetDepense:   budgetDepense,
        totalAlertes:    nonLues.length,
        alertesBudget:   budgetCount,
        alertesRetard:   retardCount,
      );
      // Affiche uniquement les notifications non lues, triées par date décroissante
      _notifications = allNotifs.where((n) => !n.lue).toList();
    });
  }

  Future<void> _fetchProjetsEnCours(String? userId) async {
    List data;

    if (userId != null) {
      // Essai 1 : user_id + statut en_cours
      data = await _supabase
          .from('projets')
          .select()
          .eq('user_id', userId)
          .eq('statut', 'en_cours')
          .order('created_at', ascending: false)
          .limit(4) as List;

      debugPrint('║ Projets en_cours (user_id filter): ${data.length}');

      // Essai 2 : si vide, on prend tous les projets du user (tous statuts)
      if (data.isEmpty) {
        final allUser = await _supabase
            .from('projets')
            .select('id, titre, statut')
            .eq('user_id', userId) as List;

        debugPrint('║ Tous projets de ce user: ${allUser.length}');
        for (final p in allUser) {
          debugPrint(
              '║   → "${p['titre']}" | statut brut: "${p['statut']}"');
        }

        // Essai 3 : sans filtre statut
        data = await _supabase
            .from('projets')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(4) as List;

        debugPrint('║ Fallback tous statuts (user_id): ${data.length}');
      }

      // Essai 4 : si toujours vide (RLS ou user_id non renseigné),
      // on tente sans filtre user_id
      if (data.isEmpty) {
        debugPrint(
            '║ Aucun projet avec user_id → tentative sans filtre user_id');
        data = await _supabase
            .from('projets')
            .select()
            .order('created_at', ascending: false)
            .limit(4) as List;

        debugPrint('║ Fallback global: ${data.length}');
      }
    } else {
      // Pas d'authentification → on prend tout
      data = await _supabase
          .from('projets')
          .select()
          .order('created_at', ascending: false)
          .limit(4) as List;

      debugPrint('║ Projets (sans auth): ${data.length}');
    }

    final list = data
        .map((e) => ProjetResume.fromJson(e as Map<String, dynamic>))
        .toList();

    debugPrint('║ Projets affichés sur le dashboard: ${list.length}');
    setState(() => _projets = list);
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final pad = isMobile ? 16.0 : 28.0;

    return Container(
      color: kBg,
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: kAccent))
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _loadAll)
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  color: kAccent,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(isMobile),
                        SizedBox(height: isMobile ? 20 : 28),
                        _buildKpiGrid(isMobile),
                        SizedBox(height: isMobile ? 20 : 28),
                        if (_notifications.isNotEmpty) ...[
                          _buildSectionTitle(
                            LucideIcons.bell,
                            'Notifications non lues',
                            kAccent,
                          ),
                          const SizedBox(height: 12),
                          ..._notifications.map(
                            (n) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _AlertCard(notif: n),
                            ),
                          ),
                          SizedBox(height: isMobile ? 16 : 20),
                        ],
                        _buildProjetsSection(isMobile),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dashboard',
          style: TextStyle(
            fontSize: isMobile ? 20 : 28,
            fontWeight: FontWeight.w800,
            color: kTextMain,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          "Vue d'ensemble de vos projets et activités",
          style: TextStyle(color: kTextSub, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildKpiGrid(bool isMobile) {
    final s = _stats ??
        const DashboardStats(
          totalProjets: 0,
          projetsActifs: 0,
          projetsTermines: 0,
          budgetTotal: 0,
          budgetDepense: 0,
          totalAlertes: 0,
          alertesBudget: 0,
          alertesRetard: 0,
        );

    final cards = [
      _KpiCard(
        title: 'Projets',
        icon: Icons.folder_copy_outlined,
        iconBg: kAccent.withOpacity(0.1),
        iconColor: kAccent,
        value: '${s.totalProjets}',
        sub1Icon: Icons.circle,
        sub1Text: '${s.projetsActifs} actif${s.projetsActifs > 1 ? 's' : ''}',
        sub1Color: kAccent,
        sub2Icon: Icons.check_circle_outline,
        sub2Text:
            '${s.projetsTermines} terminé${s.projetsTermines > 1 ? 's' : ''}',
        sub2Color: kTextSub,
      ),
      _KpiCard(
        title: 'Progression globale',
        icon: Icons.trending_up_rounded,
        iconBg: kAccent.withOpacity(0.1),
        iconColor: kAccent,
        value: '${s.progressionPourcent.toStringAsFixed(0)}%',
        hasProgress: true,
        progressValue: s.progressionGlobale,
        progressColor: kAccent,
      ),
      _KpiCard(
        title: 'Coût réalisé',
        icon: Icons.attach_money_rounded,
        iconBg: const Color(0xFFEAF3DE),
        iconColor: const Color(0xFF3B6D11),
        value: _formatMoney(s.budgetDepense),
        valueSuffix: ' DT',
        sub1Text: 'Sur ${_formatMoney(s.budgetTotal)} DT',
        sub1Color: kTextSub,
      ),
      _KpiCard(
        title: 'Alertes',
        icon: Icons.warning_amber_rounded,
        iconBg: kRed.withOpacity(0.1),
        iconColor: kRed,
        value: '${s.totalAlertes}',
        valueColor: s.totalAlertes > 0 ? kRed : kTextMain,
        sub1Icon: Icons.attach_money_rounded,
        sub1Text: '${s.alertesBudget} budget',
        sub1Color: kRed,
        sub2Icon: Icons.access_time_rounded,
        sub2Text:
            '${s.alertesRetard} retard${s.alertesRetard > 1 ? 's' : ''}',
        sub2Color: kAccent,
        borderColor: s.totalAlertes > 0 ? kRed : null,
      ),
    ];

    if (!isMobile) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: cards[i]),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 12),
              Expanded(child: cards[1]),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cards[2]),
              const SizedBox(width: 12),
              Expanded(child: cards[3]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(IconData icon, String title, Color iconColor) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: kTextMain,
          ),
        ),
      ],
    );
  }

  Widget _buildProjetsSection(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle(
              Icons.folder_open_outlined,
              'Projets en cours',
              kAccent,
            ),
            TextButton(
            onPressed: () {
  if (widget.onNavigateToProjects != null) {
    widget.onNavigateToProjects!();
  } else {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) =>  ProjetsScreen()),
    );
  }
},
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
              ),
              child: const Text(
                'Voir tous →',
                style: TextStyle(
                  color: kTextMain,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_projets.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: Column(
              children: [
                Icon(Icons.folder_open_outlined,
                    size: 40, color: kTextSub.withOpacity(0.4)),
                const SizedBox(height: 10),
                const Text(
                  'Aucun projet trouvé',
                  style: TextStyle(color: kTextSub, fontSize: 14),
                ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 600) {
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _projets
                      .map(
                        (p) => SizedBox(
                          width: (constraints.maxWidth - 12) / 2,
                          child: _ProjectCard(projet: p, onViewProject: widget.onViewProject),
                        ),
                      )
                      .toList(),
                );
              }
              return Column(
                children: _projets
                    .map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ProjectCard(projet: p, onViewProject: widget.onViewProject),
                      ),
                    )
                    .toList(),
              );
            },
          ),
      ],
    );
  }

  String _formatMoney(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(2)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// KPI CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _KpiCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String value;
  final Color? valueColor;
  final String? valueSuffix;
  final bool hasProgress;
  final double? progressValue;
  final Color? progressColor;
  final IconData? sub1Icon;
  final String? sub1Text;
  final Color? sub1Color;
  final IconData? sub2Icon;
  final String? sub2Text;
  final Color? sub2Color;
  final Color? borderColor;

  const _KpiCard({
    required this.title,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.value,
    this.valueColor,
    this.valueSuffix,
    this.hasProgress = false,
    this.progressValue,
    this.progressColor,
    this.sub1Icon,
    this.sub1Text,
    this.sub1Color,
    this.sub2Icon,
    this.sub2Text,
    this.sub2Color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor ?? const Color(0xFFEEEEEE),
          width: borderColor != null ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(color: kTextSub, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: valueColor ?? kTextMain,
              ),
              children: valueSuffix != null
                  ? [
                      TextSpan(
                        text: valueSuffix,
                        style: const TextStyle(
                          fontSize: 13,
                          color: kTextSub,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ]
                  : [],
            ),
          ),
          const SizedBox(height: 8),
          if (hasProgress && progressValue != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressValue,
                backgroundColor: const Color(0xFFF0F0F0),
                valueColor:
                    AlwaysStoppedAnimation(progressColor ?? kAccent),
                minHeight: 6,
              ),
            )
          else
            Row(
              children: [
                if (sub1Text != null)
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (sub1Icon != null)
                          Icon(sub1Icon, size: 12, color: sub1Color),
                        if (sub1Icon != null) const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            sub1Text!,
                            style:
                                TextStyle(color: sub1Color, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (sub1Text != null && sub2Text != null)
                  const SizedBox(width: 12),
                if (sub2Text != null)
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (sub2Icon != null)
                          Icon(sub2Icon, size: 12, color: sub2Color),
                        if (sub2Icon != null) const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            sub2Text!,
                            style:
                                TextStyle(color: sub2Color, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ALERT CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _AlertCard extends StatelessWidget {
  final AppNotification notif;
  const _AlertCard({required this.notif});

  @override
  Widget build(BuildContext context) {
    final color = notif.typeColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 1),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(notif.typeIcon, size: 13, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  if (notif.projet.isNotEmpty)
                    Flexible(child: Text(
                      notif.projet,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                      overflow: TextOverflow.ellipsis,
                    )),
                  if (!notif.lue) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                      child: const Text('Nouveau', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(
                  notif.message,
                  style: TextStyle(fontSize: 12, color: color.withOpacity(0.85)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(notif.date,  style: const TextStyle(fontSize: 10, color: kTextSub)),
              if (notif.heure.isNotEmpty)
                Text(notif.heure, style: const TextStyle(fontSize: 10, color: kTextSub)),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROJECT CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _ProjectCard extends StatelessWidget {
  final ProjetResume projet;
  final Function(Project)? onViewProject;
  const _ProjectCard({required this.projet, this.onViewProject});

  @override
  Widget build(BuildContext context) {
    final budgetRatio = projet.budgetTotal > 0
        ? (projet.budgetDepense / projet.budgetTotal).clamp(0.0, 1.0)
        : 0.0;
    final budgetAlert = budgetRatio >= 0.9;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
       onTap: () {
  final project = projet.toProject();
  if (onViewProject != null) {
    onViewProject!(project);
  } else {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjetDetailScreen(
          project: project,
          projectIndex: 0,
        ),
      ),
    );
  }
},
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        projet.titre,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kTextMain,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatutBadge(statut: projet.statut),
                  ],
                ),
                if (projet.client.isNotEmpty ||
                    projet.localisation.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (projet.client.isNotEmpty) ...[
                        const Icon(Icons.person_outline,
                            size: 13, color: kTextSub),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            projet.client,
                            style: const TextStyle(
                                color: kTextSub, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (projet.client.isNotEmpty &&
                          projet.localisation.isNotEmpty)
                        const SizedBox(width: 10),
                      if (projet.localisation.isNotEmpty) ...[
                        const Icon(Icons.location_on_outlined,
                            size: 13, color: kTextSub),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            projet.localisation,
                            style: const TextStyle(
                                color: kTextSub, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Progression',
                        style: TextStyle(color: kTextSub, fontSize: 12)),
                    Text(
                      '${projet.avancement}%',
                      style: TextStyle(
                        color: kAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: projet.avancement / 100,
                    backgroundColor: const Color(0xFFF0F0F0),
                    valueColor: AlwaysStoppedAnimation(kAccent),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Budget',
                        style: TextStyle(color: kTextSub, fontSize: 12)),
                    Text(
                      '${_fmt(projet.budgetDepense)} / ${_fmt(projet.budgetTotal)} DT',
                      style: TextStyle(
                        color: budgetAlert ? kRed : kTextSub,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: budgetRatio,
                    backgroundColor: const Color(0xFFF0F0F0),
                    valueColor: AlwaysStoppedAnimation(
                        budgetAlert ? kRed : kGreen),
                    minHeight: 6,
                  ),
                ),
                if (projet.dateFin != null || projet.taches > 0) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      if (projet.dateFin != null)
                        _Meta(
                          icon: Icons.calendar_today_outlined,
                          label: projet.dateFin!,
                          color: kTextSub,
                        ),
                      if (projet.taches > 0)
                        _Meta(
                          icon: Icons.task_alt_outlined,
                          label:
                              '${projet.taches} tâche${projet.taches > 1 ? 's' : ''}',
                          color: kTextSub,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}


extension ProjetResumeMapper on ProjetResume {
  Project toProject() {
    return Project(
      id: id,
      clientId: '',
      titre: titre,
      description: '',
      statut: statut,
      avancement: avancement,
      dateDebut: null,
      dateFin: dateFin,
      budgetTotal: budgetTotal,
      budgetDepense: budgetDepense,
      client: client,
      localisation: localisation,
      chef: '',
      taches: taches,
      membres: const [],
      docs: const [],
    );
  }
}

// ── Statut Badge ──────────────────────────────────────────────────────────────

class _StatutBadge extends StatelessWidget {
  final String statut;
  const _StatutBadge({required this.statut});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    final s = statut.trim().toLowerCase();

    switch (s) {
      case 'en_cours':
        bg = kAccent.withOpacity(0.12);
        fg = kAccent;
        label = 'En cours';
        break;
      case 'en_attente':
        bg = const Color(0xFFFFF3CD);
        fg = const Color(0xFF856404);
        label = 'En attente';
        break;
      case 'termine':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF065F46);
        label = 'Terminé';
        break;
      case 'annule':
        bg = kRed.withOpacity(0.1);
        fg = kRed;
        label = 'Annulé';
        break;
      default:
        bg = Colors.grey.withOpacity(0.1);
        fg = Colors.grey.shade600;
        label = statut;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: TextStyle(
            color: fg, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Meta chip ────────────────────────────────────────────────────────────────

class _Meta extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Meta(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: kRed.withOpacity(0.7)),
            const SizedBox(height: 12),
            const Text(
              'Erreur de chargement',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kTextMain),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: kTextSub, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}