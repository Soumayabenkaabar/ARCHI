import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../constants/colors.dart';
import '../models/project.dart';
import '../service/ai_service.dart';
import '../service/projet_service.dart';

class AiScreen extends StatefulWidget {
  const AiScreen({super.key});

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  List<Project> _projects = [];
  bool _loadingProjects = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    try {
      final data = await ProjetService.getProjets();
      if (mounted) setState(() { _projects = data; _loadingProjects = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingProjects = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kBg,
      child: Column(children: [
        // ── Header ──────────────────────────────────────────────────────────
        Container(
          color: const Color(0xFF1F2937),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(LucideIcons.sparkles, color: kAccent, size: 20),
              SizedBox(width: 10),
              Text('IA Assistant', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 4),
            Text('${_projects.length} projets chargés comme contexte',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ]),
        ),
        // ── Body ────────────────────────────────────────────────────────────
        Expanded(
          child: _loadingProjects
              ? const Center(child: CircularProgressIndicator(color: kAccent))
              : _PredictionsTab(projects: _projects),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PRÉDICTIONS
// ══════════════════════════════════════════════════════════════════════════════
class _PredictionsTab extends StatefulWidget {
  final List<Project> projects;
  const _PredictionsTab({required this.projects});

  @override
  State<_PredictionsTab> createState() => _PredictionsTabState();
}

class _PredictionsTabState extends State<_PredictionsTab> {
  final _loading     = <String, bool>{};
  final _predictions = <String, Map<String, String>>{};

  Future<void> _predire(Project p) async {
    setState(() => _loading[p.id] = true);
    try {
      final result = await AiService.predireProjet(p);
      if (mounted) setState(() => _predictions[p.id] = result);
    } catch (e) {
      if (mounted) setState(() => _predictions[p.id] = {'justification': 'Erreur : $e'});
    } finally {
      if (mounted) setState(() => _loading[p.id] = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.projects.isEmpty) {
      return const Center(child: Text('Aucun projet disponible', style: TextStyle(color: kTextSub)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: widget.projects.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final p    = widget.projects[i];
        final pred = _predictions[p.id];
        final busy = _loading[p.id] == true;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // En-tête carte
            Row(children: [
              Expanded(child: Text(p.titre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kTextMain), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              if (pred != null) _RiskBadge(risk: pred['niveau_risque'] ?? '—'),
              const SizedBox(width: 6),
              busy
                  ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2, color: kAccent))
                  : TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: kAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        backgroundColor: kAccent.withOpacity(0.08),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _predire(p),
                      icon: const Icon(LucideIcons.sparkles, size: 13),
                      label: const Text('Prédire'),
                    ),
            ]),
            // Données de base
            const SizedBox(height: 8),
            Row(children: [
              _MiniStat('Avancement', '${p.avancement}%'),
              const SizedBox(width: 12),
              _MiniStat('Budget total', '${(p.budgetTotal / 1000).toStringAsFixed(0)} k DT'),
              const SizedBox(width: 12),
              if (p.dateFin != null) _MiniStat('Fin prévue', p.dateFin!),
            ]),
            // Résultat prédiction
            if (pred != null) ...[
              const Divider(height: 20),
              _PredRow('Budget estimé',     pred['budget_final_estime'] ?? '—'),
              _PredRow('Date fin estimée',  pred['date_fin_estimee'] ?? '—'),
              _PredRow('Respect budget',    pred['probabilite_respect_budget'] ?? '—'),
              if ((pred['justification'] ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(pred['justification']!, style: const TextStyle(fontSize: 12, color: kTextSub, fontStyle: FontStyle.italic, height: 1.5)),
              ],
            ],
          ]),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGETS UTILITAIRES
// ══════════════════════════════════════════════════════════════════════════════

class _RiskBadge extends StatelessWidget {
  final String risk;
  const _RiskBadge({required this.risk});

  Color get _color {
    switch (risk) {
      case 'Élevé':    return kRed;
      case 'Moyen':    return const Color(0xFFF59E0B);
      case 'Faible':   return const Color(0xFF10B981);
      case 'Terminé':  return const Color(0xFF6366F1);
      case 'Annulé':   return kTextSub;
      default:         return kTextSub;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: _color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _color.withOpacity(0.3)),
    ),
    child: Text(risk, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _color)),
  );
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 10, color: kTextSub)),
    Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextMain)),
  ]);
}

class _PredRow extends StatelessWidget {
  final String label;
  final String value;
  const _PredRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Text('$label : ', style: const TextStyle(fontSize: 12, color: kTextSub)),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextMain), overflow: TextOverflow.ellipsis)),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// DIALOG DEVIS IA (utilisé depuis clients_screen)
// ══════════════════════════════════════════════════════════════════════════════
Future<void> showDevisIaDialog(BuildContext context, {String clientNom = ''}) async {
  final typeCtrl  = TextEditingController();
  final surfCtrl  = TextEditingController();
  final descCtrl  = TextEditingController();
  String? devis;
  bool loading = false;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, sd) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(LucideIcons.sparkles, color: kAccent, size: 18),
          SizedBox(width: 8),
          Text('Générer devis IA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (devis == null) ...[
                _DevisField('Type de projet', 'ex: Villa, Appartement, Bureau…', typeCtrl),
                const SizedBox(height: 10),
                _DevisField('Surface (m²)', 'ex: 150', surfCtrl, numeric: true),
                const SizedBox(height: 10),
                _DevisField('Description / cahier des charges', 'Décrivez les travaux souhaités…', descCtrl, lines: 4),
              ] else ...[
                Container(
                  height: 360,
                  decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE5E7EB))),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(14),
                    child: SelectableText(devis!, style: const TextStyle(fontSize: 12, color: kTextMain, height: 1.7)),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: devis!));
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Devis copié')));
                  },
                  icon: const Icon(LucideIcons.copy, size: 14),
                  label: const Text('Copier le devis'),
                  style: OutlinedButton.styleFrom(foregroundColor: kAccent, side: const BorderSide(color: kAccent)),
                ),
              ],
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
          if (devis == null)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: kAccent, foregroundColor: Colors.white, elevation: 0),
              onPressed: loading
                  ? null
                  : () async {
                      if (typeCtrl.text.trim().isEmpty) return;
                      sd(() => loading = true);
                      try {
                        final d = await AiService.genererDevis(
                          typeProjet: typeCtrl.text.trim(),
                          surface:    surfCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          clientNom:  clientNom,
                        );
                        sd(() { devis = d; loading = false; });
                      } catch (e) {
                        sd(() { devis = 'Erreur : $e'; loading = false; });
                      }
                    },
              icon: loading
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(LucideIcons.sparkles, size: 14),
              label: Text(loading ? 'Génération…' : 'Générer'),
            ),
          if (devis != null)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kAccent, foregroundColor: Colors.white, elevation: 0),
              onPressed: () => sd(() { devis = null; loading = false; }),
              child: const Text('Nouveau devis'),
            ),
        ],
      ),
    ),
  );

  typeCtrl.dispose();
  surfCtrl.dispose();
  descCtrl.dispose();
}

class _DevisField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController ctrl;
  final bool numeric;
  final int lines;
  const _DevisField(this.label, this.hint, this.ctrl, {this.numeric = false, this.lines = 1});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSub)),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        minLines: lines,
        maxLines: lines,
        keyboardType: numeric ? TextInputType.number : TextInputType.multiline,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: kTextSub, fontSize: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
      ),
    ],
  );
}
