import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../models/project.dart';

class ProjectCard extends StatelessWidget {
  final Project project;

  const ProjectCard({super.key, required this.project});

  String _formatMad(double amount) {
    // Format: 1.070.000 MAD
    final str = amount.toInt().toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
      count++;
    }
    return '${buffer.toString().split('').reversed.join()} MAD';
  }

  @override
  Widget build(BuildContext context) {
    final progressLabel = '${(project.progress * 100).toInt()}%';
    final budgetLabel =
        '${_formatMad(project.budgetDepense)} / ${_formatMad(project.budgetTotal)}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: const Border(left: BorderSide(color: kAccent, width: 3)),
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
          // ── Title + badge ──────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  project.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: kTextMain,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: kAccent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  project.status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // ── Client ─────────────────────────────────────────────────────
          Text(
            'Client: ${project.client}',
            style: const TextStyle(color: kTextSub, fontSize: 13),
          ),

          const SizedBox(height: 16),

          // ── Progression ────────────────────────────────────────────────
          _LabeledBar(
            label: 'Progression',
            trailingLabel: progressLabel,
            value: project.progress,
            barColor: kAccent,
          ),

          const SizedBox(height: 14),

          // ── Budget ─────────────────────────────────────────────────────
          _LabeledBar(
            label: 'Budget',
            trailingLabel: budgetLabel,
            value: project.budgetProgress,
            barColor: const Color(0xFF374151),
          ),

          const SizedBox(height: 16),

          // ── Chef + Tâches ──────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Chef: ${project.chef}',
                style: const TextStyle(color: kTextSub, fontSize: 13),
              ),
              Text(
                '${project.taches} tâches',
                style: const TextStyle(
                  color: kTextMain,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Helper widget ──────────────────────────────────────────────────────────────
class _LabeledBar extends StatelessWidget {
  final String label;
  final String trailingLabel;
  final double value;
  final Color barColor;

  const _LabeledBar({
    required this.label,
    required this.trailingLabel,
    required this.value,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: kTextSub, fontSize: 13)),
            Text(
              trailingLabel,
              style: const TextStyle(
                color: kTextMain,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 7,
            backgroundColor: const Color(0xFFE0E0E0),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}
