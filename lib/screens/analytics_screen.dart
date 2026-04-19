import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../constants/colors.dart';
import '../models/project.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final pad = isMobile ? 16.0 : 28.0;

    return Container(
      color: kBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            const Text(
              'Analytics',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: kTextMain,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Analyses et statistiques business de vos projets',
              style: TextStyle(color: kTextSub, fontSize: 14),
            ),
            const SizedBox(height: 24),

            // ── KPI Stats ────────────────────────────────────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                final statCards = [
                  _StatCard(
                    label: 'Coût moyen par projet',
                    value: '8.666.666,67 MAD',
                    sub: 'Budget moyen alloué',
                    icon: LucideIcons.dollarSign,
                    iconColor: kAccent,
                  ),
                  _StatCard(
                    label: 'Rentabilité',
                    value: '92.7%',
                    sub: 'Marge bénéficiaire moyenne',
                    icon: LucideIcons.trendingUp,
                    iconColor: kAccent,
                  ),
                  _StatCard(
                    label: 'Durée moyenne',
                    value: '15.8 mois',
                    sub: 'Temps de réalisation moyen',
                    icon: LucideIcons.clock,
                    iconColor: kAccent,
                  ),
                  _StatCard(
                    label: 'Taux de réalisation',
                    value: '7.3%',
                    sub: 'Budget consommé',
                    icon: LucideIcons.target,
                    iconColor: kTextSub,
                  ),
                ];

                if (isWide) {
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (int i = 0; i < statCards.length; i++) ...[
                          if (i > 0) const SizedBox(width: 16),
                          Expanded(child: statCards[i]),
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
                          Expanded(child: statCards[0]),
                          const SizedBox(width: 12),
                          Expanded(child: statCards[1]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: statCards[2]),
                          const SizedBox(width: 12),
                          Expanded(child: statCards[3]),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // ── Charts row ───────────────────────────────────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 700) {
                  return const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _BarChartCard(chartHeight: 200)),
                      SizedBox(width: 20),
                      Expanded(flex: 2, child: _PieChartCard(chartHeight: 200)),
                    ],
                  );
                }
                // Mobile : graphiques plus petits empilés
                return const Column(
                  children: [
                    _BarChartCard(chartHeight: 150),
                    SizedBox(height: 14),
                    _PieChartCard(chartHeight: 150),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // ── Gantt ────────────────────────────────────────────────────
            const _GanttCard(),
          ],
        ),
      ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color iconColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 18),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: kTextSub,
                    fontSize: isMobile ? 11 : 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, color: iconColor, size: isMobile ? 16 : 20),
            ],
          ),
          SizedBox(height: isMobile ? 8 : 10),
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 15 : 20,
              fontWeight: FontWeight.w800,
              color: kTextMain,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: isMobile ? 4 : 6),
          Text(
            sub,
            style: TextStyle(color: kTextSub, fontSize: isMobile ? 10 : 12),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Bar Chart Card ───────────────────────────────────────────────────────────
class _BarChartCard extends StatelessWidget {
  final double chartHeight;
  const _BarChartCard({this.chartHeight = 220});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
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
          const Text(
            'Budget vs Dépenses par projet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kTextMain,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: chartHeight,
            child: CustomPaint(
              painter: _BarChartPainter(projects: sampleProjects),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(color: kAccent, label: 'Budget (k MAD)'),
              const SizedBox(width: 16),
              _LegendItem(
                color: const Color(0xFF4B5563),
                label: 'Dépensé (k MAD)',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: kTextSub, fontSize: 12)),
      ],
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<Project> projects;
  _BarChartPainter({required this.projects});

  @override
  void paint(Canvas canvas, Size size) {
    final maxVal = projects
        .map((p) => p.budgetTotal)
        .reduce((a, b) => a > b ? a : b);

    const padding = EdgeInsets.only(left: 40, bottom: 30, right: 10, top: 10);
    final chartW = size.width - padding.left - padding.right;
    final chartH = size.height - padding.top - padding.bottom;

    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    final textStyle = const TextStyle(color: kTextSub, fontSize: 10);

    // Grid lines + Y labels
    for (int i = 0; i <= 4; i++) {
      final y = padding.top + chartH - (chartH * i / 4);
      canvas.drawLine(
        Offset(padding.left, y),
        Offset(padding.left + chartW, y),
        gridPaint,
      );
      final label = '${(maxVal / 1000 * i / 4).toStringAsFixed(0)}';
      _drawText(canvas, label, Offset(0, y - 6), textStyle, 36);
    }

    // Bars
    final n = projects.length;
    final groupW = chartW / n;
    const barW = 28.0;
    const gap = 6.0;

    for (int i = 0; i < n; i++) {
      final p = projects[i];
      final cx = padding.left + groupW * i + groupW / 2;

      // Budget bar
      final bh = (p.budgetTotal / maxVal) * chartH;
      final budgetPaint = Paint()..color = kAccent;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            cx - barW - gap / 2,
            padding.top + chartH - bh,
            barW,
            bh,
          ),
          const Radius.circular(4),
        ),
        budgetPaint,
      );

      // Dépensé bar
      final dh = (p.budgetDepense / maxVal) * chartH;
      final depPaint = Paint()..color = const Color(0xFF4B5563);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx + gap / 2, padding.top + chartH - dh, barW, dh),
          const Radius.circular(4),
        ),
        depPaint,
      );

      // X label
      final shortName = p.title.length > 18
          ? '${p.title.substring(0, 18)}...'
          : p.title;
      _drawText(
        canvas,
        shortName,
        Offset(cx - 30, size.height - 20),
        textStyle,
        70,
      );
    }

    // Axes
    final axisPaint = Paint()
      ..color = const Color(0xFFD1D5DB)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(padding.left, padding.top),
      Offset(padding.left, padding.top + chartH),
      axisPaint,
    );
    canvas.drawLine(
      Offset(padding.left, padding.top + chartH),
      Offset(padding.left + chartW, padding.top + chartH),
      axisPaint,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style,
    double maxWidth,
  ) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Pie Chart Card ───────────────────────────────────────────────────────────
class _PieChartCard extends StatelessWidget {
  final double chartHeight;
  const _PieChartCard({this.chartHeight = 220});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
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
          const Text(
            'Répartition par statut',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kTextMain,
            ),
          ),
          const SizedBox(height: 16),

          // Pie + légende côte à côte
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Donut dessiné
              SizedBox(
                width: chartHeight * 0.75,
                height: chartHeight * 0.75,
                child: CustomPaint(painter: _PieChartPainter()),
              ),
              const SizedBox(width: 20),

              // Légende verticale
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _PieLegendItem(
                      color: kAccent,
                      label: 'En cours',
                      value: '67%',
                    ),
                    const SizedBox(height: 12),
                    _PieLegendItem(
                      color: const Color(0xFF4B5563),
                      label: 'Planification',
                      value: '33%',
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

class _PieLegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  const _PieLegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: kTextSub, fontSize: 12),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PieChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.48;

    const slices = [(0.67, kAccent), (0.33, Color(0xFF4B5563))];

    double startAngle = -1.5708; // -90°
    for (final (fraction, color) in slices) {
      final sweepAngle = fraction * 2 * 3.14159265;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
      startAngle += sweepAngle;
    }

    // Trou blanc central
    canvas.drawCircle(center, radius * 0.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Gantt Card (avec bouton expand) ─────────────────────────────────────────
class _GanttCard extends StatelessWidget {
  const _GanttCard();

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
            title: const Text(
              'Planning Gantt',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _GanttContent(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
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
          // ── Header avec bouton expand ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Planning Gantt de tous les projets',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: kTextMain,
                    ),
                  ),
                ),
                // Bouton expand
                Tooltip(
                  message: 'Agrandir',
                  child: InkWell(
                    onTap: () => _openFullscreen(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: kBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                      ),
                      child: const Icon(
                        Icons.open_in_full_rounded,
                        size: 16,
                        color: kTextSub,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _GanttContent(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Gantt Content (réutilisé dans card + fullscreen) ────────────────────────
class _GanttContent extends StatefulWidget {
  const _GanttContent();

  @override
  State<_GanttContent> createState() => _GanttContentState();
}

class _GanttContentState extends State<_GanttContent> {
  final ScrollController _headerScroll = ScrollController();
  final ScrollController _bodyScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _headerScroll.addListener(() {
      if (_bodyScroll.hasClients &&
          _bodyScroll.offset != _headerScroll.offset) {
        _bodyScroll.jumpTo(_headerScroll.offset);
      }
    });
    _bodyScroll.addListener(() {
      if (_headerScroll.hasClients &&
          _headerScroll.offset != _bodyScroll.offset) {
        _headerScroll.jumpTo(_bodyScroll.offset);
      }
    });
  }

  @override
  void dispose() {
    _headerScroll.dispose();
    _bodyScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const projectColW = 180.0;
    const cellW = 60.0;
    const totalMonths = 24;
    const timelineW = totalMonths * cellW;

    return Column(
      children: [
        // ── Header ──────────────────────────────────────────────────────
        Container(
          color: const Color(0xFF1F2937),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              // Colonne projet fixe
              SizedBox(
                width: projectColW,
                child: const Padding(
                  padding: EdgeInsets.only(left: 20),
                  child: Text(
                    'Projet',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              // Timeline header scrollable
              Expanded(
                child: SingleChildScrollView(
                  controller: _headerScroll,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: timelineW,
                    child: Row(
                      children: _GanttHeaderLabels.months
                          .map(
                            (m) => SizedBox(
                              width: cellW,
                              child: Text(
                                m,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Rows ────────────────────────────────────────────────────────
        ...sampleProjects.map(
          (p) => _GanttRow(
            project: p,
            projectColW: projectColW,
            cellW: cellW,
            totalMonths: totalMonths,
            scrollController: _bodyScroll,
          ),
        ),
      ],
    );
  }
}

class _GanttHeaderLabels extends StatelessWidget {
  // 24 months from Jan 2026
  static const months = [
    'janv. 26',
    'févr. 26',
    'mars 26',
    'avr. 26',
    'mai 26',
    'juin 26',
    'juil. 26',
    'août 26',
    'sept. 26',
    'oct. 26',
    'nov. 26',
    'déc. 26',
    'janv. 27',
    'févr. 27',
    'mars 27',
    'avr. 27',
    'mai 27',
    'juin 27',
    'juil. 27',
    'août 27',
    'sept. 27',
    'oct. 27',
    'nov. 27',
    'déc. 27',
  ];

  const _GanttHeaderLabels();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: months
          .map(
            (m) => SizedBox(
              width: 60,
              child: Text(
                m,
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ),
          )
          .toList(),
    );
  }
}

// ─── Gantt Mobile : cartes verticales par projet ─────────────────────────────
class _GanttMobileCard extends StatelessWidget {
  const _GanttMobileCard();

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
            title: const Text(
              'Planning Gantt',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _GanttContent(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre + bouton expand
        Row(
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              color: kTextMain,
              size: 18,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Planning Gantt',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kTextMain,
                ),
              ),
            ),
            InkWell(
              onTap: () => _openFullscreen(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: const Icon(
                  Icons.open_in_full_rounded,
                  size: 16,
                  color: kTextSub,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Une card par projet
        ...sampleProjects.map((p) {
          final isPlanning = p.status == 'Planification';
          final barColor = isPlanning ? const Color(0xFF6B7280) : kAccent;
          final pct = (p.progress * 100).toInt();

          // Dates
          String dates;
          switch (p.title) {
            case 'Villa Moderne Casablanca':
              dates = 'janv. 2026 → déc. 2026';
              break;
            case 'Immeuble Résidentiel Rabat':
              dates = 'févr. 2026 → juin 2027';
              break;
            default:
              dates = 'juin 2026 → déc. 2027';
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border(left: BorderSide(color: barColor, width: 3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titre + badge statut
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: kTextMain,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: barColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        p.status,
                        style: TextStyle(
                          color: barColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Dates
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 12,
                      color: kTextSub,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      dates,
                      style: const TextStyle(color: kTextSub, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Tâches
                Row(
                  children: [
                    const Icon(
                      Icons.task_alt_rounded,
                      size: 12,
                      color: kTextSub,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${p.taches} tâches',
                      style: const TextStyle(color: kTextSub, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Barre de progression pleine largeur
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Progression',
                      style: TextStyle(color: kTextSub, fontSize: 12),
                    ),
                    Text(
                      '$pct%',
                      style: TextStyle(
                        color: barColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: p.progress,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ─── Gantt Row (desktop + mobile) ────────────────────────────────────────────
class _GanttRow extends StatelessWidget {
  final Project project;
  final double projectColW;
  final double cellW;
  final int totalMonths;
  final ScrollController scrollController;

  const _GanttRow({
    required this.project,
    required this.projectColW,
    required this.cellW,
    required this.totalMonths,
    required this.scrollController,
  });

  // Map project to start/end month index (0 = Jan 2026)
  (int, int) get _range {
    switch (project.titre) {
      case 'Villa Moderne Casablanca':
        return (0, 11); // jan-déc 2026
      case 'Immeuble Résidentiel Rabat':
        return (1, 17); // fév 2026-juin 2027
      default:
        return (5, 23); // juin 2026-déc 2027
    }
  }

  @override
  Widget build(BuildContext context) {
    final (start, end) = _range;
    final totalW = totalMonths * cellW;
    final barLeft = start * cellW;
    final barW = (end - start + 1) * cellW;
    final progress = project.avancement;
    final isPlanning = project.statut == 'Planification';
    final barColor = isPlanning ? const Color(0xFF6B7280) : kAccent;

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Colonne projet fixe
          SizedBox(
            width: projectColW,
            child: Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.titre,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: kTextMain,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${project.taches} tâches · ${(project.avancement * 100).toInt()}%',
                    style: const TextStyle(color: kTextSub, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),

          // Timeline scrollable — même controller que le header
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: totalW,
                height: 36,
                child: Stack(
                  children: [
                    // Grid lines
                    ...List.generate(
                      totalMonths,
                      (i) => Positioned(
                        left: i * cellW,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 1,
                          color: const Color(0xFFF3F4F6),
                        ),
                      ),
                    ),
                    // Background bar
                    Positioned(
                      left: barLeft,
                      top: 8,
                      width: barW,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    // Progress bar
                    Positioned(
                      left: barLeft,
                      top: 8,
                      width: barW * progress,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${(progress * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
