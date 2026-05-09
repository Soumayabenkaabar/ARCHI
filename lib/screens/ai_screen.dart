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

class _AiScreenState extends State<AiScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Project> _projects = [];
  bool _loadingProjects = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _loadProjects();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(LucideIcons.sparkles, color: kAccent, size: 20),
              SizedBox(width: 10),
              Text('IA Assistant', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 4),
            Text('${_projects.length} projets chargés comme contexte',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 14),
            TabBar(
              controller: _tab,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: kAccent,
              labelColor: kAccent,
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Chatbot'),
                Tab(text: 'Rapports'),
                Tab(text: 'Analyse & Alertes'),
                Tab(text: 'Prédictions'),
              ],
            ),
          ]),
        ),
        // ── Body ────────────────────────────────────────────────────────────
        Expanded(
          child: _loadingProjects
              ? const Center(child: CircularProgressIndicator(color: kAccent))
              : TabBarView(
                  controller: _tab,
                  children: [
                    _ChatbotTab(projects: _projects),
                    _RapportsTab(projects: _projects),
                    _AnalyseTab(projects: _projects),
                    _PredictionsTab(projects: _projects),
                  ],
                ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ONGLET 1 — CHATBOT
// ══════════════════════════════════════════════════════════════════════════════
class _ChatbotTab extends StatefulWidget {
  final List<Project> projects;
  const _ChatbotTab({required this.projects});

  @override
  State<_ChatbotTab> createState() => _ChatbotTabState();
}

class _ChatbotTabState extends State<_ChatbotTab> {
  final _ctrl     = TextEditingController();
  final _scroll   = ScrollController();
  final _messages = <Map<String, String>>[];
  bool _loading   = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _loading) return;
    _ctrl.clear();

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _loading = true;
    });
    _scrollBottom();

    try {
      final reply = await AiService.chat(
        userMessage: text,
        history: _messages.sublist(0, _messages.length - 1),
        projects: widget.projects,
      );
      if (mounted) setState(() { _messages.add({'role': 'assistant', 'content': reply}); });
    } catch (e) {
      if (mounted) setState(() { _messages.add({'role': 'assistant', 'content': 'Erreur : $e'}); });
    } finally {
      if (mounted) setState(() => _loading = false);
      _scrollBottom();
    }
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Messages
      Expanded(
        child: _messages.isEmpty
            ? _EmptyChat()
            : ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_loading ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (i == _messages.length) return const _TypingIndicator();
                  final msg   = _messages[i];
                  final isUser = msg['role'] == 'user';
                  return _Bubble(text: msg['content']!, isUser: isUser);
                },
              ),
      ),
      // Input bar
      Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Posez une question sur vos projets…',
                hintStyle: const TextStyle(color: kTextSub, fontSize: 13),
                filled: true,
                fillColor: kBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: _loading ? kTextSub : kAccent, shape: BoxShape.circle),
              child: const Icon(LucideIcons.send, size: 16, color: Colors.white),
            ),
          ),
        ]),
      ),
    ]);
  }
}

class _EmptyChat extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: kAccent.withOpacity(0.1), shape: BoxShape.circle),
        child: const Icon(LucideIcons.sparkles, size: 36, color: kAccent),
      ),
      const SizedBox(height: 16),
      const Text('IA Assistant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kTextMain)),
      const SizedBox(height: 6),
      const Text('Posez une question sur vos projets,\nbudgets, équipes ou délais.',
          textAlign: TextAlign.center,
          style: TextStyle(color: kTextSub, fontSize: 13)),
    ]),
  );
}

class _Bubble extends StatelessWidget {
  final String text;
  final bool isUser;
  const _Bubble({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) => Align(
    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isUser ? kAccent : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft:     const Radius.circular(16),
          topRight:    const Radius.circular(16),
          bottomLeft:  Radius.circular(isUser ? 16 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 16),
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Text(text, style: TextStyle(fontSize: 13, color: isUser ? Colors.white : kTextMain, height: 1.5)),
    ),
  );
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(
          width: 32, height: 12,
          child: LinearProgressIndicator(color: kAccent, backgroundColor: Color(0xFFE5E7EB), minHeight: 3),
        ),
        const SizedBox(width: 8),
        Text('IA réfléchit…', style: TextStyle(fontSize: 12, color: kTextSub)),
      ]),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// ONGLET 2 — RAPPORTS
// ══════════════════════════════════════════════════════════════════════════════
class _RapportsTab extends StatefulWidget {
  final List<Project> projects;
  const _RapportsTab({required this.projects});

  @override
  State<_RapportsTab> createState() => _RapportsTabState();
}

class _RapportsTabState extends State<_RapportsTab> {
  Project? _selected;
  String?  _rapport;
  bool     _loading = false;

  Future<void> _generer() async {
    if (_selected == null || _loading) return;
    setState(() { _loading = true; _rapport = null; });
    try {
      final r = await AiService.genererRapport(_selected!);
      if (mounted) setState(() => _rapport = r);
    } catch (e) {
      if (mounted) setState(() => _rapport = 'Erreur : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Sélecteur projet
        _SectionTitle('Sélectionner un projet'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Project>(
              value: _selected,
              isExpanded: true,
              hint: const Text('Choisir un projet…', style: TextStyle(color: kTextSub, fontSize: 13)),
              items: widget.projects.map((p) => DropdownMenuItem(
                value: p,
                child: Text(p.titre, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
              )).toList(),
              onChanged: (p) => setState(() { _selected = p; _rapport = null; }),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Bouton générer
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: (_selected == null || _loading) ? null : _generer,
            icon: _loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(LucideIcons.fileText, size: 16),
            label: Text(_loading ? 'Génération en cours…' : 'Générer le rapport'),
          ),
        ),
        // Rapport généré
        if (_rapport != null) ...[
          const SizedBox(height: 16),
          Row(children: [
            _SectionTitle('Rapport généré'),
            const Spacer(),
            IconButton(
              icon: const Icon(LucideIcons.copy, size: 16, color: kTextSub),
              tooltip: 'Copier',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _rapport!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Rapport copié'), duration: Duration(seconds: 2)),
                );
              },
            ),
          ]),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: SelectableText(_rapport!, style: const TextStyle(fontSize: 13, color: kTextMain, height: 1.7)),
          ),
        ],
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ONGLET 3 — ANALYSE & ALERTES
// ══════════════════════════════════════════════════════════════════════════════
class _AnalyseTab extends StatefulWidget {
  final List<Project> projects;
  const _AnalyseTab({required this.projects});

  @override
  State<_AnalyseTab> createState() => _AnalyseTabState();
}

class _AnalyseTabState extends State<_AnalyseTab> {
  final _loading = <String, bool>{};

  Future<void> _analyser(Project p, BuildContext ctx) async {
    setState(() => _loading[p.id] = true);
    try {
      final result = await AiService.analyserProjet(p);
      if (!mounted) return;
      _showSheet(ctx, p, result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Erreur : $e'), backgroundColor: kRed));
      }
    } finally {
      if (mounted) setState(() => _loading[p.id] = false);
    }
  }

  void _showSheet(BuildContext ctx, Project p, String result) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(children: [
                const Icon(LucideIcons.sparkles, color: kAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Analyse IA — ${p.titre}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: kTextMain), overflow: TextOverflow.ellipsis)),
                _RiskBadge(risk: AiService.risqueLocal(p)),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: ctrl,
                padding: const EdgeInsets.all(16),
                child: Text(result, style: const TextStyle(fontSize: 13, color: kTextMain, height: 1.7)),
              ),
            ),
          ]),
        ),
      ),
    );
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
        final p = widget.projects[i];
        final risk = AiService.risqueLocal(p);
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(p.titre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kTextMain), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                _RiskBadge(risk: risk),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                _MiniStat('Avancement', '${p.avancement}%'),
                const SizedBox(width: 12),
                if (p.budgetTotal > 0)
                  _MiniStat('Budget consommé', '${(p.budgetDepense / p.budgetTotal * 100).toStringAsFixed(0)}%'),
              ]),
            ])),
            const SizedBox(width: 10),
            _loading[p.id] == true
                ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2, color: kAccent))
                : IconButton(
                    icon: const Icon(LucideIcons.sparkles, size: 18, color: kAccent),
                    tooltip: 'Analyser avec IA',
                    onPressed: () => _analyser(p, context),
                  ),
          ]),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ONGLET 4 — PRÉDICTIONS
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

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextMain, letterSpacing: 0.3),
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
