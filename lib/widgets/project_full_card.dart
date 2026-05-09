import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../constants/colors.dart';
import '../models/project.dart';
import '../service/ai_service.dart';

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

  void _showAiAnalysis() {
    showDialog(
      context: context,
      builder: (ctx) => _AiAnalysisDialog(project: project),
    );
  }

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
                GestureDetector(
                  onTap: _showAiAnalysis,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.sparkles, size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text('IA', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── AI analysis dialog ─────────────────────────────────────────────────────────

class _AiAnalysisDialog extends StatefulWidget {
  final Project project;
  const _AiAnalysisDialog({required this.project});

  @override
  State<_AiAnalysisDialog> createState() => _AiAnalysisDialogState();
}

class _AiAnalysisDialogState extends State<_AiAnalysisDialog> {
  String? _result;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    try {
      final res = await AiService.analyserProjet(widget.project);
      if (mounted) setState(() { _result = res; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Color _riskColor(String risk) {
    if (risk.contains('Élevé')) return const Color(0xFFEF4444);
    if (risk.contains('Moyen')) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  @override
  Widget build(BuildContext context) {
    final localRisk = AiService.risqueLocal(widget.project);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.sparkles, color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.project.titre,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(LucideIcons.x, color: Colors.white70, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            // Risk badge local
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  const Text('Risque estimé :', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: _riskColor(localRisk).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      localRisk,
                      style: TextStyle(color: _riskColor(localRisk), fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _loading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                            SizedBox(height: 14),
                            Text('Analyse IA en cours…', style: TextStyle(color: Color(0xFF6B7280))),
                          ]),
                        ),
                      )
                    : _error != null
                        ? Text(_error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13))
                        : SelectableText(
                            _result ?? '',
                            style: const TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF374151)),
                          ),
              ),
            ),
            // Footer
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  child: const Text('Fermer', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
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
