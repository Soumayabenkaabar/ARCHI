import 'dart:math' show max;
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';
import '../models/project.dart';
import '../service/projet_service.dart';

// ── Helpers ────────────────────────────────────────────────────────────────────
String _fmt(double v) {
  if (v == 0) return '0 DT';
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)} M DT';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)} k DT';
  return '${v.toStringAsFixed(0)} DT';
}

DateTime? _parseDate(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  final iso = DateTime.tryParse(s);
  if (iso != null) return iso;
  const monthMap = {
    'jan': 1, 'fév': 2, 'feb': 2, 'mar': 3, 'avr': 4, 'apr': 4,
    'mai': 5, 'may': 5, 'jun': 6, 'juin': 6, 'jul': 7, 'juil': 7,
    'aoû': 8, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'déc': 12, 'dec': 12,
  };
  final parts = s.toLowerCase().trim().split(RegExp(r'[\s\-/]+'));
  if (parts.length >= 2) {
    for (final entry in monthMap.entries) {
      if (parts[0].startsWith(entry.key)) {
        final year = int.tryParse(parts[1]);
        if (year != null) return DateTime(year, entry.value);
      }
    }
    final year = int.tryParse(parts[0]);
    if (year != null) {
      for (final entry in monthMap.entries) {
        if (parts.length > 1 && parts[1].startsWith(entry.key)) {
          return DateTime(year, entry.value);
        }
      }
    }
  }
  return null;
}

String _monthLabel(DateTime d) {
  const names = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
                  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
  return '${names[d.month - 1]} ${d.year.toString().substring(2)}';
}

// ══════════════════════════════════════════════════════════════════════════════
//  Screen
// ══════════════════════════════════════════════════════════════════════════════
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  static final _db = Supabase.instance.client;

  bool _loading = true;
  List<Project> _projets = [];
  List<Map<String, dynamic>> _taches = [];
  List<Map<String, dynamic>> _factures = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        ProjetService.getProjets(),
        _db.from('taches').select('statut, budget_estime, projet_id'),
        _db.from('factures').select('statut, montant, projet_id'),
      ]);
      if (mounted) {
        setState(() {
          _projets  = results[0] as List<Project>;
          _taches   = (results[1] as List).cast<Map<String, dynamic>>();
          _factures = (results[2] as List).cast<Map<String, dynamic>>();
          _loading  = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── KPIs ───────────────────────────────────────────────────────────────────
  double get _budgetTotal   => _projets.fold(0.0, (s, p) => s + p.budgetTotal);
  double get _budgetDepense => _projets.fold(0.0, (s, p) => s + p.budgetDepense);
  double get _tauxConso     => _budgetTotal > 0 ? (_budgetDepense / _budgetTotal * 100).clamp(0, 100) : 0;
  int    get _enCours       => _projets.where((p) => p.statut == 'en_cours').length;
  int    get _termines      => _projets.where((p) => p.statut == 'termine').length;
  int    get _enAttente     => _projets.where((p) => p.statut == 'en_attente').length;
  int    get _annules       => _projets.where((p) => p.statut == 'annule').length;

  double get _avancementMoyen {
    final actifs = _projets.where((p) => p.statut == 'en_cours').toList();
    if (actifs.isEmpty) return 0;
    return actifs.fold(0.0, (s, p) => s + p.avancement) / actifs.length;
  }

  int get _tachesTotal     => _taches.length;
  int get _tachesTerminees => _taches.where((t) => t['statut'] == 'termine').length;
  int get _facPayees       => _factures.where((f) => f['statut'] == 'payee').length;
  int get _facAttente      => _factures.where((f) => f['statut'] == 'en_attente').length;
  int get _facRetard       => _factures.where((f) => f['statut'] == 'en_retard').length;
  double get _montantFactures => _factures.fold(0.0, (s, f) => s + ((f['montant'] as num?)?.toDouble() ?? 0));

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final pad = isMobile ? 16.0 : 28.0;

    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kAccent));
    }

    return Container(
      color: kBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Analytics',
                          style: TextStyle(fontSize: isMobile ? 24 : 28,
                              fontWeight: FontWeight.w800, color: kTextMain)),
                      const SizedBox(height: 4),
                      Text('Tableau de bord — ${_projets.length} projet${_projets.length > 1 ? 's' : ''}',
                          style: const TextStyle(color: kTextSub, fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _load,
                  icon: const Icon(LucideIcons.refreshCw, size: 18, color: kTextSub),
                  tooltip: 'Actualiser',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── KPI row ──────────────────────────────────────────────────────
            LayoutBuilder(builder: (_, c) {
              final w = (c.maxWidth - 36) / (c.maxWidth > 700 ? 4 : 2);
              final cards = [
                _KpiCard(
                  label: 'Budget total',
                  value: _fmt(_budgetTotal),
                  sub: '${_projets.length} projets',
                  icon: LucideIcons.banknote,
                  color: kAccent,
                ),
                _KpiCard(
                  label: 'Budget consommé',
                  value: _fmt(_budgetDepense),
                  sub: '${_tauxConso.toStringAsFixed(1)}% du total',
                  icon: LucideIcons.trendingUp,
                  color: _tauxConso > 80
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF10B981),
                  progress: _tauxConso / 100,
                ),
                _KpiCard(
                  label: 'Avancement moyen',
                  value: '${_avancementMoyen.toStringAsFixed(0)}%',
                  sub: '$_enCours projet${_enCours > 1 ? 's' : ''} en cours',
                  icon: LucideIcons.activity,
                  color: const Color(0xFF3B82F6),
                  progress: _avancementMoyen / 100,
                ),
                _KpiCard(
                  label: 'Tâches terminées',
                  value: '$_tachesTerminees / $_tachesTotal',
                  sub: _tachesTotal > 0
                      ? '${(_tachesTerminees / _tachesTotal * 100).toStringAsFixed(0)}% complétées'
                      : 'Aucune tâche',
                  icon: LucideIcons.checkSquare,
                  color: const Color(0xFF8B5CF6),
                  progress: _tachesTotal > 0 ? _tachesTerminees / _tachesTotal : 0,
                ),
              ];
              return Wrap(
                spacing: 12, runSpacing: 12,
                children: cards.map((c) => SizedBox(width: w, child: c)).toList(),
              );
            }),

            const SizedBox(height: 20),

            // ── Statuts + Factures row ────────────────────────────────────
            LayoutBuilder(builder: (_, c) {
              if (c.maxWidth > 700) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 3, child: _StatutsCard(
                        enCours: _enCours, enAttente: _enAttente,
                        termines: _termines, annules: _annules,
                        total: _projets.length,
                      )),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: _FacturesCard(
                        payees: _facPayees, attente: _facAttente,
                        retard: _facRetard, montant: _montantFactures,
                      )),
                    ],
                  ),
                );
              }
              return Column(children: [
                _StatutsCard(enCours: _enCours, enAttente: _enAttente,
                    termines: _termines, annules: _annules, total: _projets.length),
                const SizedBox(height: 12),
                _FacturesCard(payees: _facPayees, attente: _facAttente,
                    retard: _facRetard, montant: _montantFactures),
              ]);
            }),

            const SizedBox(height: 20),

            // ── Charts row ───────────────────────────────────────────────
            if (_projets.isNotEmpty) ...[
              LayoutBuilder(builder: (_, c) {
                if (c.maxWidth > 700) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _BarChartCard(projects: _projets)),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: _PieChartCard(
                        enCours: _enCours, enAttente: _enAttente,
                        termines: _termines, annules: _annules,
                        total: _projets.length,
                      )),
                    ],
                  );
                }
                return Column(children: [
                  _BarChartCard(projects: _projets),
                  const SizedBox(height: 14),
                  _PieChartCard(enCours: _enCours, enAttente: _enAttente,
                      termines: _termines, annules: _annules, total: _projets.length),
                ]);
              }),
              const SizedBox(height: 20),
              _GanttCard(projects: _projets),
            ] else
              _EmptyState(),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  KPI Card
// ══════════════════════════════════════════════════════════════════════════════
class _KpiCard extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final Color color;
  final double? progress;

  const _KpiCard({
    required this.label, required this.value, required this.sub,
    required this.icon, required this.color, this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16),
          ),
          const Spacer(),
          if (progress != null)
            Text('${(progress! * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kTextMain)),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: kTextMain, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(sub, style: const TextStyle(color: kTextSub, fontSize: 11), overflow: TextOverflow.ellipsis),
        if (progress != null) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress!.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Statuts Card
// ══════════════════════════════════════════════════════════════════════════════
class _StatutsCard extends StatelessWidget {
  final int enCours, enAttente, termines, annules, total;
  const _StatutsCard({required this.enCours, required this.enAttente,
      required this.termines, required this.annules, required this.total});

  @override
  Widget build(BuildContext context) {
    final items = [
      _SItem('En cours', enCours, const Color(0xFF3B82F6)),
      _SItem('Planification', enAttente, const Color(0xFFF59E0B)),
      _SItem('Terminés', termines, const Color(0xFF10B981)),
      _SItem('Annulés', annules, const Color(0xFF9CA3AF)),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Répartition des projets',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextMain)),
        const SizedBox(height: 14),
        Row(children: items.map((it) => Expanded(child: _StatutItem(item: it, total: total))).toList()),
        const SizedBox(height: 14),
        // Stacked progress bar
        if (total > 0) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Row(children: items.map((it) => Expanded(
                flex: max(it.count, 0),
                child: Container(color: it.color),
              )).toList()),
            ),
          ),
        ],
      ]),
    );
  }
}

class _SItem {
  final String label;
  final int count;
  final Color color;
  const _SItem(this.label, this.count, this.color);
}

class _StatutItem extends StatelessWidget {
  final _SItem item;
  final int total;
  const _StatutItem({required this.item, required this.total});

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: item.color.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: Center(child: Text('${item.count}',
          style: TextStyle(color: item.color, fontWeight: FontWeight.w800, fontSize: 14))),
    ),
    const SizedBox(height: 6),
    Text(item.label, style: const TextStyle(color: kTextSub, fontSize: 10),
        textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
    if (total > 0) Text('${(item.count / total * 100).toStringAsFixed(0)}%',
        style: TextStyle(color: item.color, fontSize: 11, fontWeight: FontWeight.w700)),
  ]);
}

// ══════════════════════════════════════════════════════════════════════════════
//  Factures Card
// ══════════════════════════════════════════════════════════════════════════════
class _FacturesCard extends StatelessWidget {
  final int payees, attente, retard;
  final double montant;
  const _FacturesCard({required this.payees, required this.attente,
      required this.retard, required this.montant});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Factures', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextMain)),
          const Spacer(),
          Text(_fmt(montant), style: const TextStyle(color: kAccent, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 14),
        _FacRow(LucideIcons.checkCircle, 'Payées', payees, const Color(0xFF10B981)),
        const SizedBox(height: 8),
        _FacRow(LucideIcons.clock, 'En attente', attente, const Color(0xFFF59E0B)),
        const SizedBox(height: 8),
        _FacRow(LucideIcons.alertCircle, 'En retard', retard, const Color(0xFFEF4444)),
      ]),
    );
  }
}

class _FacRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  const _FacRow(this.icon, this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 14, color: color),
    const SizedBox(width: 8),
    Expanded(child: Text(label, style: const TextStyle(color: kTextSub, fontSize: 12))),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text('$count', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    ),
  ]);
}

// ══════════════════════════════════════════════════════════════════════════════
//  Bar Chart — Budget vs Dépenses
// ══════════════════════════════════════════════════════════════════════════════
class _BarChartCard extends StatelessWidget {
  final List<Project> projects;
  const _BarChartCard({required this.projects});

  @override
  Widget build(BuildContext context) {
    // Limit to 8 projects for readability
    final shown = projects.take(8).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Budget vs Dépenses', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextMain)),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: shown.isEmpty
              ? const Center(child: Text('Aucun projet', style: TextStyle(color: kTextSub)))
              : CustomPaint(painter: _BarPainter(shown), size: Size.infinite),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _Legend(color: kAccent, label: 'Budget alloué'),
          const SizedBox(width: 16),
          _Legend(color: const Color(0xFF4B5563), label: 'Consommé'),
        ]),
      ]),
    );
  }
}

class _BarPainter extends CustomPainter {
  final List<Project> projects;
  _BarPainter(this.projects);

  @override
  void paint(Canvas canvas, Size size) {
    final maxVal = projects.map((p) => p.budgetTotal).fold(0.0, (a, b) => a > b ? a : b);
    if (maxVal == 0) return;

    const pl = 50.0, pb = 30.0, pr = 10.0, pt = 10.0;
    final chartW = size.width - pl - pr;
    final chartH = size.height - pt - pb;

    final gridP = Paint()..color = const Color(0xFFE5E7EB)..strokeWidth = 1;
    final ts = const TextStyle(color: kTextSub, fontSize: 9);

    // Grid + Y labels
    for (int i = 0; i <= 4; i++) {
      final y = pt + chartH - chartH * i / 4;
      canvas.drawLine(Offset(pl, y), Offset(pl + chartW, y), gridP);
      final val = maxVal * i / 4;
      final lbl = val >= 1000000 ? '${(val / 1000000).toStringAsFixed(1)}M' : val >= 1000 ? '${(val / 1000).toStringAsFixed(0)}k' : val.toStringAsFixed(0);
      _text(canvas, lbl, Offset(0, y - 6), ts, 46);
    }

    // Axes
    final axisP = Paint()..color = const Color(0xFFD1D5DB)..strokeWidth = 1.5;
    canvas.drawLine(Offset(pl, pt), Offset(pl, pt + chartH), axisP);
    canvas.drawLine(Offset(pl, pt + chartH), Offset(pl + chartW, pt + chartH), axisP);

    // Bars
    final n = projects.length;
    final groupW = chartW / n;
    const barW = 22.0, gap = 4.0;

    for (int i = 0; i < n; i++) {
      final p = projects[i];
      final cx = pl + groupW * i + groupW / 2;

      final bh = (p.budgetTotal / maxVal) * chartH;
      canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - barW - gap / 2, pt + chartH - bh, barW, bh),
        const Radius.circular(3)), Paint()..color = kAccent);

      if (p.budgetDepense > 0) {
        final dh = (p.budgetDepense / maxVal) * chartH;
        canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(cx + gap / 2, pt + chartH - dh, barW, dh),
          const Radius.circular(3)), Paint()..color = const Color(0xFF4B5563));
      }

      final name = p.titre.length > 10 ? '${p.titre.substring(0, 10)}…' : p.titre;
      _text(canvas, name, Offset(cx - groupW / 2 + 2, size.height - 18), ts, groupW - 4);
    }
  }

  void _text(Canvas c, String t, Offset o, TextStyle s, double mw) {
    final tp = TextPainter(text: TextSpan(text: t, style: s), textDirection: TextDirection.ltr)
      ..layout(maxWidth: mw);
    tp.paint(c, o);
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) => old.projects != projects;
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 6),
    Text(label, style: const TextStyle(color: kTextSub, fontSize: 12)),
  ]);
}

// ══════════════════════════════════════════════════════════════════════════════
//  Pie Chart — Répartition statuts
// ══════════════════════════════════════════════════════════════════════════════
class _PieChartCard extends StatelessWidget {
  final int enCours, enAttente, termines, annules, total;
  const _PieChartCard({required this.enCours, required this.enAttente,
      required this.termines, required this.annules, required this.total});

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox();
    final slices = [
      (enCours / total,  const Color(0xFF3B82F6), 'En cours'),
      (enAttente / total, const Color(0xFFF59E0B), 'Planification'),
      (termines / total, const Color(0xFF10B981), 'Terminés'),
      (annules / total,  const Color(0xFF9CA3AF), 'Annulés'),
    ].where((s) => s.$1 > 0).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Répartition par statut', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextMain)),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          SizedBox(
            width: 120, height: 120,
            child: CustomPaint(painter: _PiePainter(slices.map((s) => (s.$1, s.$2)).toList())),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: slices.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: s.$2, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 6),
                  Expanded(child: Text(s.$3, style: const TextStyle(color: kTextSub, fontSize: 11))),
                  Text('${(s.$1 * 100).toStringAsFixed(0)}%',
                      style: TextStyle(color: s.$2, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              )).toList(),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _PiePainter extends CustomPainter {
  final List<(double, Color)> slices;
  _PiePainter(this.slices);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.48;
    double angle = -1.5708;
    for (final (frac, color) in slices) {
      if (frac <= 0) continue;
      final sweep = frac * 6.28318;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
          angle, sweep, true, Paint()..color = color);
      angle += sweep;
    }
    canvas.drawCircle(center, radius * 0.5, Paint()..color = kCardBg);
  }

  @override
  bool shouldRepaint(covariant _PiePainter old) => old.slices != slices;
}

// ══════════════════════════════════════════════════════════════════════════════
//  Gantt Card
// ══════════════════════════════════════════════════════════════════════════════
class _GanttCard extends StatelessWidget {
  final List<Project> projects;
  const _GanttCard({required this.projects});

  void _openFullscreen(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: kBg,
          appBar: AppBar(
            backgroundColor: const Color(0xFF1F2937),
            elevation: 0,
            title: const Text('Planning Gantt',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            leading: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: _GanttContent(projects: projects, expanded: true),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCardBg, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: kAccent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
              child: const Icon(LucideIcons.ganttChart, color: kAccent, size: 16),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Planning Gantt', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextMain)),
              Text('Vue chronologique des projets', style: TextStyle(fontSize: 11, color: kTextSub)),
            ])),
            Tooltip(
              message: 'Plein écran',
              child: InkWell(
                onTap: () => _openFullscreen(context),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE0E0E0))),
                  child: const Icon(Icons.open_in_full_rounded, size: 15, color: kTextSub),
                ),
              ),
            ),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFFF3F4F6)),
        _GanttContent(projects: projects),
        // Légende
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Wrap(spacing: 16, runSpacing: 6, children: [
            _GanttLegend(color: kAccent,                     label: 'En cours'),
            _GanttLegend(color: const Color(0xFFF59E0B),    label: 'Planification'),
            _GanttLegend(color: const Color(0xFF10B981),    label: 'Terminé'),
            _GanttLegend(color: const Color(0xFF9CA3AF),    label: 'Annulé'),
            _GanttLegend(color: const Color(0xFFEF4444),    label: "Aujourd'hui", isDash: true),
          ]),
        ),
      ]),
    );
  }
}

class _GanttLegend extends StatelessWidget {
  final Color color;
  final String label;
  final bool isDash;
  const _GanttLegend({required this.color, required this.label, this.isDash = false});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    isDash
        ? Container(width: 16, height: 2, color: color)
        : Container(width: 10, height: 10,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 5),
    Text(label, style: const TextStyle(color: kTextSub, fontSize: 11)),
  ]);
}

// ─── Gantt Content ─────────────────────────────────────────────────────────────
class _GanttContent extends StatefulWidget {
  final List<Project> projects;
  final bool expanded;
  const _GanttContent({required this.projects, this.expanded = false});

  @override
  State<_GanttContent> createState() => _GanttContentState();
}

class _GanttContentState extends State<_GanttContent> {
  final _scrollCtrl = ScrollController();
  int? _tooltip;

  static const _rowH    = 58.0;
  static const _barH    = 22.0;
  static const _headerH = 56.0; // year + month rows

  @override
  void dispose() { _scrollCtrl.dispose(); super.dispose(); }

  List<DateTime> _buildMonths() {
    DateTime? minD, maxD;
    for (final p in widget.projects) {
      final s = _parseDate(p.dateDebut);
      final e = _parseDate(p.dateFin);
      if (s != null && (minD == null || s.isBefore(minD))) minD = s;
      if (e != null && (maxD == null || e.isAfter(maxD))) maxD = e;
    }
    final now = DateTime.now();
    minD ??= DateTime(now.year, now.month - 3);
    maxD ??= DateTime(now.year + 1, now.month + 3);
    if (maxD.difference(minD).inDays < 300)
      maxD = DateTime(minD.year + 1, minD.month + 2);

    final months = <DateTime>[];
    var cur = DateTime(minD.year, minD.month);
    while (!cur.isAfter(DateTime(maxD.year, maxD.month))) {
      months.add(cur);
      cur = cur.month == 12
          ? DateTime(cur.year + 1, 1)
          : DateTime(cur.year, cur.month + 1);
    }
    return months;
  }

  Color _barColor(Project p) {
    switch (p.statut) {
      case 'termine':   return const Color(0xFF10B981);
      case 'en_attente':return const Color(0xFFF59E0B);
      case 'annule':    return const Color(0xFF9CA3AF);
      default:          return kAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final projColW = isMobile ? 120.0 : 200.0;
    final cellW    = isMobile ? 52.0  : 64.0;

    final months   = _buildMonths();
    final base     = months.first;
    final timelineW = months.length * cellW;
    final now      = DateTime.now();

    int mIdx(DateTime? d) {
      if (d == null) return -1;
      return (d.year - base.year) * 12 + (d.month - base.month);
    }

    final nowIdx = mIdx(now);
    // fractional position within current month
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final nowX = nowIdx * cellW + (now.day / daysInMonth) * cellW;

    // Group months by year for the header
    final yearGroups = <int, int>{};
    for (final m in months) yearGroups[m.year] = (yearGroups[m.year] ?? 0) + 1;

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── Colonne gauche FIXE ───────────────────────────────────────────────
      SizedBox(
        width: projColW,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Header cell
          Container(
            height: _headerH,
            decoration: const BoxDecoration(
              color: Color(0xFF1F2937),
              border: Border(right: BorderSide(color: Color(0xFF374151))),
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 16),
            child: const Text('Projet',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          ),

          // Project rows
          ...List.generate(widget.projects.length, (i) {
            final p = widget.projects[i];
            final color = _barColor(p);
            final isOdd = i.isOdd;
            return GestureDetector(
              onTap: () => setState(() => _tooltip = _tooltip == i ? null : i),
              child: Container(
                height: _rowH,
                color: isOdd ? const Color(0xFFFAFAFA) : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(p.titre,
                      style: TextStyle(fontWeight: FontWeight.w600,
                          fontSize: isMobile ? 11 : 12, color: kTextMain),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(children: [
                    Container(width: 7, height: 7,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text('${p.avancement}%',
                        style: const TextStyle(color: kTextSub, fontSize: 10)),
                  ]),
                ]),
              ),
            );
          }),
        ]),
      ),

      // ── Timeline scrollable ───────────────────────────────────────────────
      Expanded(
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: timelineW,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Header années + mois ─────────────────────────────────────
              SizedBox(
                height: _headerH,
                child: Column(children: [
                  // Années
                  SizedBox(
                    height: 22,
                    child: Row(children: yearGroups.entries.map((e) => Container(
                      width: e.value * cellW,
                      color: const Color(0xFF111827),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 8),
                      child: Text('${e.key}',
                          style: const TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w800, fontSize: 11)),
                    )).toList()),
                  ),
                  // Mois
                  SizedBox(
                    height: 34,
                    child: Row(children: months.map((m) {
                      final isNow = m.year == now.year && m.month == now.month;
                      return Container(
                        width: cellW,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isNow
                              ? kAccent.withValues(alpha: 0.25)
                              : const Color(0xFF1F2937),
                        ),
                        child: Text(
                          _shortMonth(m),
                          style: TextStyle(
                            color: isNow ? kAccent : Colors.white54,
                            fontSize: 10,
                            fontWeight: isNow ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      );
                    }).toList()),
                  ),
                ]),
              ),

              // ── Lignes de projet ─────────────────────────────────────────
              Stack(children: [
                // Colonne de barres
                Column(children: List.generate(widget.projects.length, (i) {
                  final p = widget.projects[i];
                  final color = _barColor(p);
                  final startIdx = mIdx(_parseDate(p.dateDebut));
                  final endIdx   = mIdx(_parseDate(p.dateFin));
                  final hasBar   = startIdx >= 0 && endIdx >= startIdx;
                  final barLeft  = hasBar ? startIdx * cellW : 0.0;
                  final barW     = hasBar ? (endIdx - startIdx + 1) * cellW : 0.0;
                  final fillW    = hasBar ? (barW * p.avancement / 100).clamp(0.0, barW) : 0.0;
                  final isOdd    = i.isOdd;
                  final showTip  = _tooltip == i;

                  return GestureDetector(
                    onTap: () => setState(() => _tooltip = _tooltip == i ? null : i),
                    child: Container(
                      height: _rowH,
                      color: isOdd ? const Color(0xFFFAFAFA) : Colors.white,
                      child: Stack(children: [

                        // Lignes verticales mois
                        ...List.generate(months.length, (mi) => Positioned(
                          left: mi * cellW, top: 0, bottom: 0,
                          child: Container(width: 1, color: const Color(0xFFF0F0F0)),
                        )),

                        // Barre fond (durée totale)
                        if (hasBar) Positioned(
                          left: barLeft,
                          top: (_rowH - _barH) / 2,
                          width: barW,
                          height: _barH,
                          child: Container(
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),

                        // Barre remplie (avancement)
                        if (hasBar && fillW > 0) Positioned(
                          left: barLeft,
                          top: (_rowH - _barH) / 2,
                          width: fillW,
                          height: _barH,
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [BoxShadow(
                                color: color.withValues(alpha: 0.30),
                                blurRadius: 4, offset: const Offset(0, 2),
                              )],
                            ),
                            alignment: Alignment.center,
                            child: fillW > 28 ? Text('${p.avancement}%',
                                style: const TextStyle(color: Colors.white,
                                    fontSize: 9, fontWeight: FontWeight.w800)) : null,
                          ),
                        ),

                        // Tooltip sur tap
                        if (showTip && hasBar) Positioned(
                          left: (barLeft + barW / 2 - 80).clamp(0, timelineW - 160),
                          top: 2,
                          child: Material(
                            elevation: 8,
                            borderRadius: BorderRadius.circular(8),
                            color: const Color(0xFF1F2937),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min, children: [
                                Text(p.titre, style: const TextStyle(color: Colors.white,
                                    fontWeight: FontWeight.w700, fontSize: 11),
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 3),
                                if (p.dateDebut != null)
                                  Text('Début : ${p.dateDebut}',
                                      style: const TextStyle(color: Colors.white60, fontSize: 10)),
                                if (p.dateFin != null)
                                  Text('Fin : ${p.dateFin}',
                                      style: const TextStyle(color: Colors.white60, fontSize: 10)),
                                Text('Avancement : ${p.avancement}%',
                                    style: TextStyle(color: color, fontSize: 10,
                                        fontWeight: FontWeight.w700)),
                              ]),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  );
                })),

                // Ligne "Aujourd'hui" par-dessus tout
                if (nowIdx >= 0 && nowIdx < months.length)
                  Positioned(
                    left: nowX,
                    top: 0,
                    bottom: 0,
                    child: IgnorePointer(child: Container(
                      width: 2,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        boxShadow: [BoxShadow(color: const Color(0xFFEF4444).withValues(alpha: 0.3), blurRadius: 4)],
                      ),
                    )),
                  ),
              ]),
            ]),
          ),
        ),
      ),
    ]);
  }
}

String _shortMonth(DateTime d) {
  const n = ['Jan','Fév','Mar','Avr','Mai','Jun','Jul','Aoû','Sep','Oct','Nov','Déc'];
  return n[d.month - 1];
}

// ══════════════════════════════════════════════════════════════════════════════
//  Empty state
// ══════════════════════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(children: [
        Icon(LucideIcons.barChart2, size: 48, color: kTextSub.withValues(alpha: 0.3)),
        const SizedBox(height: 14),
        const Text('Aucun projet trouvé', style: TextStyle(color: kTextSub, fontSize: 15, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        const Text('Créez des projets pour voir les analytics', style: TextStyle(color: kTextSub, fontSize: 12)),
      ]),
    ),
  );
}
