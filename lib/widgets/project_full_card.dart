import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../constants/colors.dart';
import '../models/project.dart';


class ProjectFullCard extends StatefulWidget {
  final Project project;
  final VoidCallback? onDelete;

  const ProjectFullCard({super.key, required this.project, this.onDelete});

  @override
  State<ProjectFullCard> createState() => _ProjectFullCardState();
}

class _ProjectFullCardState extends State<ProjectFullCard> {
  Project get project => widget.project;
  VoidCallback? get onDelete => widget.onDelete;


  String _formatDt(double amount) {
    if (amount == 0) return '0 DT';
    final str = amount.toInt().toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
      count++;
    }
    return '${buffer.toString().split('').reversed.join()} DT';
  }

  Color get _statusColor {
    switch (project.status) {
      case 'En cours':
        return kAccent;
      case 'Planification':
        return const Color(0xFFADB5BD);
      case 'Terminé':
        return const Color(0xFF28A745);
      default:
        return kAccent;
    }
  }

  @override
  Widget build(BuildContext _) {
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: _statusColor, width: 3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + status badge + delete
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        project.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: kTextMain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Status badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor,
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
                            if (onDelete != null) ...[
                              const SizedBox(width: 6),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: onDelete,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFEBEB),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: const Icon(
                                    LucideIcons.trash2,
                                    size: 13,
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Accès client badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                LucideIcons.userCheck,
                                size: 11,
                                color: Color(0xFF28A745),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Accès Client',
                                style: TextStyle(
                                  color: Color(0xFF28A745),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Client
                Text(
                  project.client,
                  style: const TextStyle(color: kTextSub, fontSize: 13),
                ),

                const SizedBox(height: 8),

                // Progression bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Progression',
                      style: TextStyle(color: kTextSub, fontSize: 13),
                    ),
                    Text(
                      '${(project.progress * 100).toInt()}%',
                      style: const TextStyle(
                        color: kTextMain,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: project.progress,
                    minHeight: 7,
                    backgroundColor: const Color(0xFFE9ECEF),
                    valueColor: AlwaysStoppedAnimation<Color>(_statusColor),
                  ),
                ),

                const SizedBox(height: 14),

                // Localisation, Chef, Dates
                _InfoRow(icon: LucideIcons.mapPin, text: project.localisation),
                const SizedBox(height: 6),
                _InfoRow(icon: LucideIcons.user, text: project.chef),
                const SizedBox(height: 6),
                _InfoRow(
                  icon: LucideIcons.calendar,
                  text: '${project.dateDebut} — ${project.dateFin}',
                ),
              ],
            ),
          ),

          // ── Divider ────────────────────────────────────────────────────
          const Divider(height: 1, color: Color(0xFFF0F0F0)),

          // ── Budget section ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Column(
              children: [
                _BudgetRow(
                  label: 'Budget',
                  value: _formatDt(project.budgetTotal),
                ),
                const SizedBox(height: 4),
                _BudgetRow(
                  label: 'Dépensé',
                  value: _formatDt(project.budgetDepense),
                  bold: true,
                ),
              ],
            ),
          ),

          // ── Divider ────────────────────────────────────────────────────
          const Divider(height: 1, color: Color(0xFFF0F0F0)),

          // ── Footer stats ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                const Icon(LucideIcons.checkSquare, size: 13, color: kTextSub),
                const SizedBox(width: 4),
                Text(
                  '${project.taches} tâches',
                  style: const TextStyle(color: kTextSub, fontSize: 12),
                ),
                const _Dot(),
                const Icon(LucideIcons.users, size: 13, color: kTextSub),
                const SizedBox(width: 4),
                Text(
                  '${project.membres.length} membres',
                  style: const TextStyle(color: kTextSub, fontSize: 12),
                ),
                const _Dot(),
                const Icon(LucideIcons.fileText, size: 13, color: kTextSub),
                const SizedBox(width: 4),
                Text(
                  '${project.docs.length} docs',
                  style: const TextStyle(color: kTextSub, fontSize: 12),
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// ── Helper widgets ─────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: kTextSub),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: kTextSub, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _BudgetRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _BudgetRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: kTextSub, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            color: kTextMain,
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Text('•', style: TextStyle(color: kTextSub, fontSize: 12)),
    );
  }
}
