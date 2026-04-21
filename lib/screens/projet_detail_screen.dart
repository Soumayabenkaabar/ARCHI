import 'dart:convert';
import 'package:archi_manager/models/notification.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/colors.dart';
import '../models/project.dart';
import '../models/tache.dart';
import '../models/phase.dart';
import '../models/document.dart';
import '../models/facture.dart';
import '../models/commentaire.dart';
import '../models/membre.dart';
import '../service/tache_service.dart';
import '../service/phase_service.dart';
import '../service/document_service.dart';
import '../service/facture_service.dart';
import '../service/commentaire_service.dart';
import '../service/project_member_service.dart';
import '../service/projet_service.dart';


// ── Helpers globaux ───────────────────────────────────────────────────────────
Color _tacheColor(String s) {
  switch (s) {
    case 'en_cours': return kAccent;
    case 'termine':  return const Color(0xFF10B981);
    default:         return const Color(0xFF9CA3AF);
  }
}
String _tacheLabel(String s) {
  switch (s) { case 'en_cours': return 'En cours'; case 'termine': return 'Terminé'; default: return 'Pas commencé'; }
}
Color _factureColor(String s) {
  switch (s) { case 'payee': return const Color(0xFF10B981); case 'en_retard': return kRed; default: return kAccent; }
}
String _factureLabel(String s) {
  switch (s) { case 'payee': return 'Payée'; case 'en_retard': return 'En retard'; default: return 'En attente'; }
}
String _fmtNum(double v) {
  if (v == 0) return '0 DT';
  final s = v.toInt().toString(); final buf = StringBuffer(); int c = 0;
  for (int i = s.length - 1; i >= 0; i--) { if (c > 0 && c % 3 == 0) buf.write('.'); buf.write(s[i]); c++; }
  return '${buf.toString().split('').reversed.join()} DT';
}
void _snack(BuildContext ctx, String msg, Color color) {
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
    content: Row(children: [
      const Icon(Icons.info_outline_rounded, color: Colors.white, size: 15),
      const SizedBox(width: 8),
      Flexible(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500))),
    ]),
    backgroundColor: color,
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.all(12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    duration: const Duration(seconds: 2),
  ));
}

// ── Documents : phases & helpers ──────────────────────────────────────────────
const List<String> kDocPhases = ['Toutes les phases', 'ESQ', 'APS/APD', 'PC', 'DCE', 'EXE/DET'];
const List<String> kDocTypes  = ['Plan', 'Devis', 'Permis', 'Rapport', 'Contrat', 'Autre'];

Color _phaseColor(String phase) {
  switch (phase) {
    case 'ESQ':     return const Color(0xFFEC4899);
    case 'APS/APD': return const Color(0xFF8B5CF6);
    case 'PC':      return const Color(0xFF3B82F6);
    case 'DCE':     return const Color(0xFFF59E0B);
    case 'EXE/DET': return const Color(0xFF10B981);
    default:        return kAccent;
  }
}

IconData _docIconFromLabel(String typeLabel) {
  switch (typeLabel) {
    case 'Plan':    return LucideIcons.penTool;
    case 'Devis':   return LucideIcons.receipt;
    case 'Permis':  return LucideIcons.fileCheck;
    case 'Rapport': return LucideIcons.fileText;
    case 'Contrat': return LucideIcons.fileBadge;
    default:        return LucideIcons.file;
  }
}

String _fileTypeFromLabel(String typeLabel) {
  switch (typeLabel) {
    case 'Plan':    return 'dwg';
    case 'Devis':   return 'xlsx';
    case 'Permis':  return 'pdf';
    case 'Rapport': return 'pdf';
    case 'Contrat': return 'pdf';
    default:        return 'autre';
  }
}

class _DocUI {
  final Document doc;
  final String   nomAffiche;
  final String   phase;
  final String   typeLabel;
  final int      version;
  final String?  dateDoc;

  const _DocUI({
    required this.doc,
    required this.nomAffiche,
    required this.phase,
    required this.typeLabel,
    required this.version,
    this.dateDoc,
  });

  factory _DocUI.fromDocument(Document d) {
    if (d.nom.contains('\x00')) {
      final parts = d.nom.split('\x00');
      return _DocUI(
        doc:        d,
        nomAffiche: parts[0],
        phase:      parts.length > 1 ? parts[1] : 'ESQ',
        typeLabel:  parts.length > 2 ? parts[2] : 'Plan',
        version:    parts.length > 3 ? (int.tryParse(parts[3]) ?? 1) : 1,
        dateDoc:    parts.length > 4 && parts[4].isNotEmpty ? parts[4] : null,
      );
    }
    return _DocUI(
      doc:        d,
      nomAffiche: d.nom,
      phase:      'ESQ',
      typeLabel:  'Plan',
      version:    1,
    );
  }

  static String encodeNom({
    required String nomAffiche,
    required String phase,
    required String typeLabel,
    required int    version,
    String?         dateDoc,
  }) =>
      '$nomAffiche\x00$phase\x00$typeLabel\x00$version\x00${dateDoc ?? ''}';
}

// ══════════════════════════════════════════════════════════════════════════════
//  SCREEN PRINCIPAL
// ══════════════════════════════════════════════════════════════════════════════
class ProjetDetailScreen extends StatefulWidget {
  final Project project;
  final int projectIndex;
  const ProjetDetailScreen({super.key, required this.project, required this.projectIndex});
  @override State<ProjetDetailScreen> createState() => _ProjetDetailScreenState();
}

class _ProjetDetailScreenState extends State<ProjetDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const int _tabCount = 7;
  int _commentCount = 0;

  Color get _statusColor {
    switch (widget.project.statut) {
      case 'en_cours': return kAccent;
      case 'termine':  return const Color(0xFF10B981);
      case 'annule':   return kRed;
      default:         return const Color(0xFF9CA3AF);
    }
  }

  String _fmt(double v) {
    if (v == 0) return '0 DT';
    final s = v.toInt().toString(); final buf = StringBuffer(); int c = 0;
    for (int i = s.length - 1; i >= 0; i--) { if (c > 0 && c % 3 == 0) buf.write('.'); buf.write(s[i]); c++; }
    return '${buf.toString().split('').reversed.join()} DT';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
    _loadCommentCount();
  }

  Future<void> _loadCommentCount() async {
    try {
      final comments = await CommentaireService.getCommentaires(widget.project.id);
      if (mounted) setState(() => _commentCount = comments.length);
    } catch (_) {}
  }
  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final pad = isMobile ? 16.0 : 28.0;
    final p = widget.project;

    return Scaffold(
      backgroundColor: kBg,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: Material(
              color: kCardBg,
              elevation: 0,
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, isMobile ? 12 : 16, pad, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.arrow_back_ios_rounded, size: 13, color: kTextSub),
                      SizedBox(width: 4),
                      Text('Retour aux projets', style: TextStyle(color: kTextSub, fontSize: 12)),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  isMobile ? _buildMobileHeader(p) : _buildDesktopHeader(p),
                  const SizedBox(height: 10),
                  _buildCompactInfoBar(p),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Progression globale', style: TextStyle(color: kTextSub, fontSize: 12, fontWeight: FontWeight.w500)),
                    Text('${p.avancement}%', style: const TextStyle(fontWeight: FontWeight.w700, color: kTextMain, fontSize: 12)),
                  ]),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: p.progress, minHeight: 6,
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor: AlwaysStoppedAnimation<Color>(_statusColor),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: kTextMain,
                    unselectedLabelColor: kTextSub,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    unselectedLabelStyle: const TextStyle(fontSize: 13),
                    indicatorColor: kAccent,
                    indicatorWeight: 3,
                    dividerColor: const Color(0xFFE5E7EB),
                    tabs: [
                      const Tab(text: 'Planning & Tâches'),
                      const Tab(text: 'Finances'),
                      const Tab(text: 'Suivi & Photos'),
                      const Tab(text: 'Équipe'),
                      const Tab(text: 'Documents'),
                      const Tab(text: 'Modèle 3D'),
                      Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Text('Commentaires'),
                        if (_commentCount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(10)),
                            child: Text('$_commentCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ])),
                    ],
                  ),
                ]),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _TachesTab(project: widget.project),
            _FinancesTab(project: widget.project, fmt: _fmt),
            _SuiviPhotosTab(project: widget.project),
            _EquipeTab(project: widget.project),
            _DocumentsTab(project: widget.project),
            _Modele3DTab(project: widget.project),
            _CommentairesTab(
              project: widget.project,
              onCountChanged: (count) {
                if (mounted) setState(() => _commentCount = count);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopHeader(Project p) => Row(children: [
    Expanded(child: Row(children: [
      Flexible(child: Text(p.titre, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kTextMain))),
      const SizedBox(width: 10),
      _StatusBadge(label: p.status, color: _statusColor),
    ])),
    Material(color: Colors.transparent, child: Row(children: [
      _AccessToggle(),
      const SizedBox(width: 10),
      OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFD1D5DB)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        child: const Text('Terminer', style: TextStyle(color: kTextMain, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
      const SizedBox(width: 8),
      OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(side: const BorderSide(color: kRed), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        child: const Text('Annuler', style: TextStyle(color: kRed, fontSize: 12)),
      ),
    ])),
  ]);

  Widget _buildMobileHeader(Project p) => Row(children: [
    Expanded(child: Row(children: [
      Expanded(child: Text(p.titre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kTextMain))),
      const SizedBox(width: 8),
      _StatusBadge(label: p.status, color: _statusColor),
    ])),
    const SizedBox(width: 8),
    _AccessToggle(),
  ]);

  Widget _buildCompactInfoBar(Project p) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(children: [
      Text('Client : ${p.client}', style: const TextStyle(color: kTextSub, fontSize: 11, fontWeight: FontWeight.w500)),
      Container(margin: const EdgeInsets.symmetric(horizontal: 10), width: 1, height: 14, color: const Color(0xFFE5E7EB)),
      _CompactChip(icon: LucideIcons.mapPin,     text: p.localisation.isEmpty ? '—' : p.localisation),
      const SizedBox(width: 8),
      _CompactChip(icon: LucideIcons.user,       text: p.chef.isEmpty ? '—' : p.chef),
      const SizedBox(width: 8),
      _CompactChip(icon: LucideIcons.calendar,   text: '${p.dateDebut ?? "—"} → ${p.dateFin ?? "—"}'),
      const SizedBox(width: 8),
      _CompactChip(icon: LucideIcons.dollarSign, text: '${_fmt(p.budgetDepense)} / ${_fmt(p.budgetTotal)}'),
    ]),
  );
}

class _CompactChip extends StatelessWidget {
  final IconData icon; final String text;
  const _CompactChip({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 11, color: kTextSub),
    const SizedBox(width: 4),
    Text(text, style: const TextStyle(color: kTextSub, fontSize: 11)),
  ]);
}

// ══════════════════════════════════════════════════════════════════════════════
//  ONGLET TÂCHES
// ══════════════════════════════════════════════════════════════════════════════
class _TachesTab extends StatefulWidget {
  final Project project;
  const _TachesTab({required this.project});
  @override State<_TachesTab> createState() => _TachesTabState();
}

class _TachesTabState extends State<_TachesTab> {
  List<Tache> taches = [];
  List<Phase> phases = [];
  bool loading    = true;
  bool _showGantt = false;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        TacheService.getTaches(widget.project.id),
        PhaseService.getPhases(widget.project.id),
      ]);
      setState(() {
        taches  = results[0] as List<Tache>;
        phases  = results[1] as List<Phase>;
        loading = false;
      });
    } catch (_) { setState(() => loading = false); }
  }

  int    get _total      => taches.length;
  int    get _terminees  => taches.where((t) => t.statut == 'termine').length;
  int    get _enCours    => taches.where((t) => t.statut == 'en_cours').length;
  int    get _enAttente  => taches.where((t) => t.statut != 'en_cours' && t.statut != 'termine').length;
  double get _progression => _total == 0 ? 0 : _terminees / _total;

  List<Tache> _tachesDePhase(String? phaseId) {
    if (phaseId == null) return taches.where((t) => t.phaseId == null || t.phaseId!.isEmpty).toList();
    return taches.where((t) => t.phaseId == phaseId).toList();
  }
  double _progressionPhase(String? phaseId) {
    final list = _tachesDePhase(phaseId);
    if (list.isEmpty) return 0;
    return list.where((t) => t.statut == 'termine').length / list.length;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final pad = isMobile ? 16.0 : 28.0;
    if (loading) return const Center(child: CircularProgressIndicator(color: kAccent));

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Planning & Tâches', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kTextMain)),
            SizedBox(height: 2),
            Text('Gérez et suivez l\'avancement de chaque tâche', style: TextStyle(color: kTextSub, fontSize: 12)),
          ])),
          Container(
            decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _ViewToggleBtn(label: 'Liste', icon: LucideIcons.list,      active: !_showGantt, onTap: () => setState(() => _showGantt = false)),
              _ViewToggleBtn(label: 'Gantt', icon: LucideIcons.barChart2, active: _showGantt,  onTap: () => setState(() => _showGantt = true)),
            ]),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _showPhaseDialog(context, null),
            icon: const Icon(LucideIcons.folderPlus, size: 13),
            label: Text(isMobile ? '' : 'Phase', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: 10),
              side: const BorderSide(color: Color(0xFFD1D5DB)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _showTacheDialog(context, null, preselectedPhaseId: null),
            icon: const Icon(LucideIcons.plus, size: 14, color: Colors.white),
            label: Text(isMobile ? '' : 'Nouvelle tâche', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
            style: ElevatedButton.styleFrom(backgroundColor: kAccent, elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          ),
        ]),
        const SizedBox(height: 20),
        _ProgressionCard(total: _total, terminees: _terminees, enCours: _enCours, enAttente: _enAttente, progression: _progression),
        const SizedBox(height: 16),
        IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _KpiCard(label: 'Total',      value: '$_total',     color: kAccent,                  icon: LucideIcons.listChecks)),
          const SizedBox(width: 10),
          Expanded(child: _KpiCard(label: 'En cours',   value: '$_enCours',   color: const Color(0xFF3B82F6),  icon: LucideIcons.activity)),
          const SizedBox(width: 10),
          Expanded(child: _KpiCard(label: 'Terminées',  value: '$_terminees', color: const Color(0xFF10B981),  icon: LucideIcons.checkCircle)),
          const SizedBox(width: 10),
          Expanded(child: _KpiCard(label: 'Phases',     value: '${phases.length}', color: const Color(0xFF8B5CF6), icon: LucideIcons.layers)),
        ])),
        const SizedBox(height: 24),
        if (_showGantt)
          _GanttView(taches: taches, phases: phases)
        else if (taches.isEmpty && phases.isEmpty)
          _EmptyState(icon: LucideIcons.listChecks, message: 'Aucune tâche — créez une phase ou une tâche directe')
        else
          _buildListeGroupee(),
      ]),
    );
  }

  Widget _buildListeGroupee() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    ...phases.map((ph) {
      final list = _tachesDePhase(ph.id);
      final prog = _progressionPhase(ph.id);
      return _PhaseSection(
        phase: ph, taches: list, progression: prog,
        onAddTache:      () => _showTacheDialog(context, null, preselectedPhaseId: ph.id),
        onEditTache:     (t) => _showTacheDialog(context, t),
        onViewTache:     (t) => _showViewDialog(context, t),
        onDeleteTache:   (t) async { await TacheService.deleteTache(t.id); _load(); },
        onStatusChanged: (t, s) async {
          await TacheService.updateStatut(t.id, s, projetId: widget.project.id, ancienStatut: t.statut, budgetEstime: t.budgetEstime);
          _load();
        },
        onEditPhase:   () => _showPhaseDialog(context, ph),
        onDeletePhase: () => _confirmDeletePhase(context, ph),
      );
    }),
    ..._buildTachesSansPhase(),
  ]);

  List<Widget> _buildTachesSansPhase() {
    final list = _tachesDePhase(null);
    if (list.isEmpty && phases.isNotEmpty) return [];
    return [
      if (phases.isNotEmpty) ...[
        Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
          const Icon(LucideIcons.listChecks, size: 13, color: kTextSub),
          const SizedBox(width: 7),
          const Text('Sans phase', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextSub)),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _showTacheDialog(context, null, preselectedPhaseId: null),
            icon: const Icon(LucideIcons.plus, size: 12, color: kAccent),
            label: const Text('Ajouter', style: TextStyle(fontSize: 12, color: kAccent)),
          ),
        ])),
      ],
      if (list.isEmpty && phases.isEmpty)
        _EmptyState(icon: LucideIcons.listChecks, message: 'Aucune tâche — commencez par en créer une'),
      ...list.asMap().entries.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _TacheCard(
          tache: e.value, index: e.key + 1,
          onStatusChanged: (s) async {
            await TacheService.updateStatut(e.value.id, s, projetId: widget.project.id, ancienStatut: e.value.statut, budgetEstime: e.value.budgetEstime);
            _load();
          },
          onDelete: () async { await TacheService.deleteTache(e.value.id); _load(); },
          onEdit:   () => _showTacheDialog(context, e.value),
          onView:   () => _showViewDialog(context, e.value),
        ),
      )),
    ];
  }

  void _showPhaseDialog(BuildContext context, Phase? existing) {
    final ctrl  = TextEditingController(text: existing?.nom ?? '');
    final isEdit = existing != null;
    showDialog(context: context, builder: (_) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 400), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.07), borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), border: Border(bottom: BorderSide(color: const Color(0xFF8B5CF6).withOpacity(0.15)))),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(isEdit ? LucideIcons.pencil : LucideIcons.folderPlus, color: const Color(0xFF8B5CF6), size: 18)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isEdit ? 'Renommer la phase' : 'Nouvelle phase', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF8B5CF6))),
              Text(isEdit ? 'Modifiez le nom de la phase' : 'Créez un groupe de tâches', style: const TextStyle(color: kTextSub, fontSize: 12)),
            ]),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(20), child: _DField(icon: LucideIcons.layers, label: 'NOM DE LA PHASE *', hint: 'Ex: Gros œuvre', controller: ctrl)),
        _DialogActions(
          onCancel: () => Navigator.pop(context),
          onConfirm: () async {
            final nom = ctrl.text.trim();
            if (nom.isEmpty)    { _snack(context, 'Nom de la phase obligatoire', kRed); return; }
            if (nom.length < 2) { _snack(context, 'Le nom doit contenir au moins 2 caractères', kRed); return; }
            if (nom.length > 100){ _snack(context, 'Le nom ne peut pas dépasser 100 caractères', kRed); return; }
            if (isEdit) {
              await PhaseService.updatePhase(existing!.id, ctrl.text.trim());
              _snack(context, 'Phase modifiée', kAccent);
            } else {
              await PhaseService.addPhase(widget.project.id, ctrl.text.trim(), phases.length);
              _snack(context, 'Phase créée', kAccent);
            }
            Navigator.pop(context); _load();
          },
          label: isEdit ? 'Enregistrer' : 'Créer',
        ),
      ])),
    ));
  }

  void _confirmDeletePhase(BuildContext context, Phase ph) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Supprimer la phase ?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      content: Text('La phase "${ph.nom}" sera supprimée. Les tâches associées resteront sans phase.', style: const TextStyle(color: kTextSub, fontSize: 13)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        TextButton(
          onPressed: () async { await PhaseService.deletePhase(ph.id); Navigator.pop(context); _load(); _snack(context, 'Phase supprimée', kRed); },
          child: const Text('Supprimer', style: TextStyle(color: kRed, fontWeight: FontWeight.w700)),
        ),
      ],
    ));
  }

  void _showTacheDialog(BuildContext context, Tache? existing, {String? preselectedPhaseId}) {
    final titreCtrl     = TextEditingController(text: existing?.titre ?? '');
    final descCtrl      = TextEditingController(text: existing?.description ?? '');
    final debutCtrl     = TextEditingController(text: existing?.dateDebut ?? '');
    final finCtrl       = TextEditingController(text: existing?.dateFin ?? '');
    final budgetCtrl    = TextEditingController(text: existing != null && existing.budgetEstime > 0 ? existing.budgetEstime.toInt().toString() : '');
    final remarquesCtrl = TextEditingController(text: existing?.remarques ?? '');
    String  statut  = existing?.statut ?? 'en_attente';
    String? phaseId = existing?.phaseId ?? preselectedPhaseId;
    final isEdit    = existing != null;

    Future<void> pickDate(BuildContext ctx, TextEditingController ctrl, {DateTime? firstDate}) async {
      DateTime initial = DateTime.now();
      if (ctrl.text.isNotEmpty) { final parsed = DateTime.tryParse(ctrl.text); if (parsed != null) initial = parsed; }
      final picked = await showDatePicker(
        context: ctx, initialDate: initial,
        firstDate: firstDate ?? DateTime(2020), lastDate: DateTime(2035),
        locale: const Locale('fr', 'FR'),
        builder: (ctx2, child) => Theme(data: Theme.of(ctx2).copyWith(colorScheme: ColorScheme.light(primary: kAccent, onPrimary: Colors.white, surface: Colors.white, onSurface: kTextMain)), child: child!),
      );
      if (picked != null) ctrl.text = '${picked.year}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}';
    }

    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (ctx, sd) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            _DialogHeader(icon: isEdit ? LucideIcons.pencil : LucideIcons.listPlus, title: isEdit ? 'Modifier la tâche' : 'Nouvelle tâche', subtitle: isEdit ? 'Mettez à jour les informations' : 'Ajoutez une tâche au projet'),
            Padding(padding: const EdgeInsets.all(20), child: Column(children: [
              if (phases.isNotEmpty) ...[
                const Align(alignment: Alignment.centerLeft, child: Text('PHASE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSub, letterSpacing: 0.5))),
                const SizedBox(height: 7),
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE5E7EB))),
                  child: DropdownButtonHideUnderline(child: DropdownButton<String?>(
                    value: phaseId, isExpanded: true, padding: const EdgeInsets.symmetric(horizontal: 12),
                    hint: const Text('Aucune phase', style: TextStyle(color: kTextSub, fontSize: 13)),
                    style: const TextStyle(color: kTextMain, fontSize: 13), borderRadius: BorderRadius.circular(8),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Aucune phase', style: TextStyle(color: kTextSub))),
                      ...phases.map((ph) => DropdownMenuItem<String?>(value: ph.id, child: Row(children: [const Icon(LucideIcons.layers, size: 13, color: Color(0xFF8B5CF6)), const SizedBox(width: 8), Text(ph.nom)]))),
                    ],
                    onChanged: (v) => sd(() => phaseId = v),
                  )),
                ),
                const SizedBox(height: 14),
              ],
              _DField(icon: LucideIcons.checkSquare, label: 'TITRE *', hint: 'Ex: Fondations', controller: titreCtrl),
              const SizedBox(height: 12),
              _DField(icon: LucideIcons.fileText, label: 'DESCRIPTION', hint: 'Détails de la tâche...', controller: descCtrl, maxLines: 2),
              const SizedBox(height: 12),
              const Align(alignment: Alignment.centerLeft, child: Text('DATES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSub, letterSpacing: 0.5))),
              const SizedBox(height: 7),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () async { await pickDate(ctx, debutCtrl); sd(() {}); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE5E7EB))),
                    child: Row(children: [
                      const Icon(LucideIcons.calendarDays, size: 14, color: kTextSub), const SizedBox(width: 8),
                      Expanded(child: Text(debutCtrl.text.isEmpty ? 'Date début' : debutCtrl.text, style: TextStyle(fontSize: 13, color: debutCtrl.text.isEmpty ? kTextSub : kTextMain))),
                      if (debutCtrl.text.isNotEmpty) GestureDetector(onTap: () { debutCtrl.clear(); sd(() {}); }, child: const Icon(LucideIcons.x, size: 13, color: kTextSub)),
                    ]),
                  ),
                )),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('→', style: TextStyle(color: kTextSub, fontWeight: FontWeight.w600))),
                Expanded(child: GestureDetector(
                  onTap: () async { DateTime? first; if (debutCtrl.text.isNotEmpty) first = DateTime.tryParse(debutCtrl.text); await pickDate(ctx, finCtrl, firstDate: first); sd(() {}); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE5E7EB))),
                    child: Row(children: [
                      const Icon(LucideIcons.calendarCheck, size: 14, color: kTextSub), const SizedBox(width: 8),
                      Expanded(child: Text(finCtrl.text.isEmpty ? 'Date fin' : finCtrl.text, style: TextStyle(fontSize: 13, color: finCtrl.text.isEmpty ? kTextSub : kTextMain))),
                      if (finCtrl.text.isNotEmpty) GestureDetector(onTap: () { finCtrl.clear(); sd(() {}); }, child: const Icon(LucideIcons.x, size: 13, color: kTextSub)),
                    ]),
                  ),
                )),
              ]),
              if (debutCtrl.text.isNotEmpty && finCtrl.text.isNotEmpty)
                Builder(builder: (_) {
                  final d = DateTime.tryParse(debutCtrl.text); final f = DateTime.tryParse(finCtrl.text);
                  if (d != null && f != null && !f.isAfter(d)) return const Padding(padding: EdgeInsets.only(top: 6), child: Row(children: [Icon(LucideIcons.alertCircle, size: 12, color: kRed), SizedBox(width: 5), Text('La date de fin doit être après la date de début', style: TextStyle(fontSize: 11, color: kRed))]));
                  return const SizedBox.shrink();
                }),
              const SizedBox(height: 12),
              _DField(icon: LucideIcons.banknote, label: 'BUDGET PRÉVU (DT)', hint: '50 000', controller: budgetCtrl, keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              _DField(icon: LucideIcons.messageSquare, label: 'REMARQUES', hint: 'Notes, observations...', controller: remarquesCtrl, maxLines: 3),
              const SizedBox(height: 14),
              const Align(alignment: Alignment.centerLeft, child: Text('STATUT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSub, letterSpacing: 0.5))),
              const SizedBox(height: 8),
              Row(children: [
                for (final s in ['en_attente', 'en_cours', 'termine'])
                  Expanded(child: Padding(
                    padding: EdgeInsets.only(right: s == 'termine' ? 0 : 8),
                    child: GestureDetector(onTap: () => sd(() => statut = s), child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: statut == s ? _tacheColor(s).withOpacity(0.1) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: statut == s ? _tacheColor(s) : const Color(0xFFE5E7EB), width: statut == s ? 2 : 1),
                      ),
                      child: Text(_tacheLabel(s), textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: statut == s ? FontWeight.w700 : FontWeight.w500, color: statut == s ? _tacheColor(s) : kTextSub)),
                    )),
                  )),
              ]),
            ])),
            _DialogActions(
              onCancel: () => Navigator.pop(ctx),
              onConfirm: () async {
                final titre = titreCtrl.text.trim();
                if (titre.isEmpty)     { _snack(ctx, 'Titre de la tâche obligatoire', kRed); return; }
                if (titre.length < 2)  { _snack(ctx, 'Le titre doit contenir au moins 2 caractères', kRed); return; }
                if (titre.length > 150){ _snack(ctx, 'Le titre ne peut pas dépasser 150 caractères', kRed); return; }
                final budgetVal = budgetCtrl.text.trim();
                if (budgetVal.isNotEmpty) {
                  final b = double.tryParse(budgetVal.replaceAll(' ', ''));
                  if (b == null) { _snack(ctx, 'Budget invalide', kRed); return; }
                  if (b < 0)    { _snack(ctx, 'Le budget ne peut pas être négatif', kRed); return; }
                  if (b > 999999999) { _snack(ctx, 'Budget trop élevé', kRed); return; }
                }
                if (debutCtrl.text.isNotEmpty && finCtrl.text.isNotEmpty) {
                  final d = DateTime.tryParse(debutCtrl.text); final f = DateTime.tryParse(finCtrl.text);
                  if (d != null && f != null && !f.isAfter(d)) { _snack(ctx, 'La date de fin doit être après la date de début', kRed); return; }
                }
                final t = Tache(id: isEdit ? existing!.id : '', projetId: widget.project.id, phaseId: phaseId, titre: titreCtrl.text.trim(), description: descCtrl.text.trim(), statut: statut, dateDebut: debutCtrl.text.trim().isEmpty ? null : debutCtrl.text.trim(), dateFin: finCtrl.text.trim().isEmpty ? null : finCtrl.text.trim(), budgetEstime: double.tryParse(budgetCtrl.text.replaceAll(' ', '')) ?? 0, remarques: remarquesCtrl.text.trim(), createdAt: isEdit ? existing!.createdAt : '');
                if (isEdit) {
                  if (statut != existing!.statut) await TacheService.updateStatut(t.id, statut, projetId: widget.project.id, ancienStatut: existing.statut, budgetEstime: t.budgetEstime);
                  await TacheService.updateTache(t);
                  _snack(context, 'Tâche modifiée', kAccent);
                } else {
                  await TacheService.addTache(t);
                  _snack(context, 'Tâche ajoutée', kAccent);
                }
                Navigator.pop(ctx); _load();
              },
              label: isEdit ? 'Enregistrer' : 'Ajouter',
            ),
          ])),
        ),
      );
    }));
  }

  void _showViewDialog(BuildContext context, Tache t) {
    final color = _tacheColor(t.statut);
    final phase = phases.where((p) => p.id == t.phaseId).firstOrNull;
    showDialog(context: context, builder: (_) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: const Icon(LucideIcons.checkSquare, color: Colors.white, size: 22)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.titre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
              const SizedBox(height: 5),
              Wrap(spacing: 6, children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(10)), child: Text(t.statutLabel, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                if (phase != null) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(LucideIcons.layers, size: 10, color: Colors.white70), const SizedBox(width: 4), Text(phase.nom, style: const TextStyle(color: Colors.white70, fontSize: 10))])),
              ]),
            ])),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (t.description.isNotEmpty) ...[
            Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE5E7EB))), child: Text(t.description, style: const TextStyle(fontSize: 13, color: kTextMain, height: 1.5))),
            const SizedBox(height: 14),
          ],
          Row(children: [
            Expanded(child: _ViewInfoTile(icon: LucideIcons.calendarDays,  label: 'Début', value: t.dateDebut ?? '—')),
            const SizedBox(width: 10),
            Expanded(child: _ViewInfoTile(icon: LucideIcons.calendarCheck, label: 'Fin',   value: t.dateFin   ?? '—')),
          ]),
          const SizedBox(height: 10),
          _ViewInfoTile(icon: LucideIcons.banknote, label: 'Budget prévu', value: t.budgetEstime > 0 ? _fmtNum(t.budgetEstime) : '—'),
          if (t.remarques.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFDE68A))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: const [Icon(LucideIcons.messageSquare, size: 12, color: Color(0xFFD97706)), SizedBox(width: 5), Text('Remarques', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFD97706)))]), const SizedBox(height: 5), Text(t.remarques, style: const TextStyle(fontSize: 13, color: kTextMain, height: 1.5))])),
          ],
        ])),
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), child: SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: color, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Fermer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))))),
      ])),
    ));
  }
}

// ── Phase section & Tache card ────────────────────────────────────────────────
class _PhaseSection extends StatefulWidget {
  final Phase phase; final List<Tache> taches; final double progression;
  final VoidCallback onAddTache, onEditPhase, onDeletePhase;
  final void Function(Tache) onEditTache, onViewTache, onDeleteTache;
  final void Function(Tache, String) onStatusChanged;
  const _PhaseSection({required this.phase, required this.taches, required this.progression, required this.onAddTache, required this.onEditTache, required this.onViewTache, required this.onDeleteTache, required this.onStatusChanged, required this.onEditPhase, required this.onDeletePhase});
  @override State<_PhaseSection> createState() => _PhaseSectionState();
}
class _PhaseSectionState extends State<_PhaseSection> {
  bool _expanded = true;
  @override
  Widget build(BuildContext context) {
    final pct   = (widget.progression * 100).round();
    final color = pct == 100 ? const Color(0xFF10B981) : pct > 0 ? kAccent : const Color(0xFF9CA3AF);
    return Padding(padding: const EdgeInsets.only(bottom: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.fromLTRB(12, 10, 8, 0), decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)), child: Column(children: [
        Row(children: [
          GestureDetector(onTap: () => setState(() => _expanded = !_expanded), child: Icon(_expanded ? LucideIcons.chevronDown : LucideIcons.chevronRight, size: 16, color: kTextSub)),
          const SizedBox(width: 8),
          Expanded(child: GestureDetector(onTap: () => setState(() => _expanded = !_expanded), child: Text(widget.phase.nom, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextMain)))),
          Text('$pct% complété', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            onSelected: (v) { if (v == 'add') widget.onAddTache(); if (v == 'edit') widget.onEditPhase(); if (v == 'delete') widget.onDeletePhase(); },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'add',    child: Row(children: [Icon(LucideIcons.plus,   size: 14, color: kAccent),  SizedBox(width: 8), Text('Ajouter une tâche')])),
              const PopupMenuItem(value: 'edit',   child: Row(children: [Icon(LucideIcons.pencil, size: 14, color: kTextSub), SizedBox(width: 8), Text('Renommer')])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(LucideIcons.trash2, size: 14, color: kRed),     SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: kRed))])),
            ],
            child: const Padding(padding: EdgeInsets.all(6), child: Icon(LucideIcons.moreVertical, size: 15, color: kTextSub)),
          ),
        ]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: widget.progression, minHeight: 5, backgroundColor: color.withOpacity(0.15), valueColor: AlwaysStoppedAnimation<Color>(color))),
        const SizedBox(height: 10),
      ])),
      if (_expanded) ...[
        const SizedBox(height: 8),
        if (widget.taches.isEmpty)
          GestureDetector(onTap: widget.onAddTache, child: Container(margin: const EdgeInsets.only(left: 2), padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE5E7EB))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.plus, size: 13, color: kAccent), const SizedBox(width: 6), const Text('Ajouter une tâche à cette phase', style: TextStyle(fontSize: 12, color: kAccent, fontWeight: FontWeight.w500))])))
        else
          ...widget.taches.asMap().entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _TacheCard(tache: e.value, index: e.key + 1, onStatusChanged: (s) => widget.onStatusChanged(e.value, s), onDelete: () => widget.onDeleteTache(e.value), onEdit: () => widget.onEditTache(e.value), onView: () => widget.onViewTache(e.value)))),
      ],
    ]));
  }
}

class _TacheCard extends StatefulWidget {
  final Tache tache; final int index;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onDelete, onEdit, onView;
  const _TacheCard({required this.tache, required this.index, required this.onStatusChanged, required this.onDelete, required this.onEdit, required this.onView});
  @override State<_TacheCard> createState() => _TacheCardState();
}
class _TacheCardState extends State<_TacheCard> {
  bool _remarquesExpanded = false;
  @override
  Widget build(BuildContext context) {
    final tache = widget.tache; final color = _tacheColor(tache.statut);
    final pct = tache.statut == 'termine' ? 100 : tache.statut == 'en_cours' ? 65 : 0;
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF0F0F0)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))]),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(tache.titre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: kTextMain))), const SizedBox(width: 12), Text('$pct%', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: pct == 100 ? const Color(0xFF10B981) : pct > 0 ? kAccent : const Color(0xFF9CA3AF)))]),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct / 100, minHeight: 4, backgroundColor: const Color(0xFFE5E7EB), valueColor: AlwaysStoppedAnimation<Color>(color))),
        const SizedBox(height: 10),
        Row(children: [
          Material(color: Colors.transparent, child: PopupMenuButton<String>(onSelected: widget.onStatusChanged, itemBuilder: (_) => [for (final s in ['en_attente', 'en_cours', 'termine']) PopupMenuItem(value: s, child: Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: _tacheColor(s), shape: BoxShape.circle)), const SizedBox(width: 8), Text(_tacheLabel(s), style: const TextStyle(fontSize: 13))]))], child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 5), Text(tache.statutLabel, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)), const SizedBox(width: 3), Icon(LucideIcons.chevronsUpDown, size: 10, color: color)])))),
          const Spacer(),
          PopupMenuButton<String>(onSelected: (v) { if (v == 'view') widget.onView(); if (v == 'edit') widget.onEdit(); if (v == 'delete') widget.onDelete(); }, itemBuilder: (_) => [const PopupMenuItem(value: 'view', child: Row(children: [Icon(LucideIcons.eye, size: 14, color: kTextSub), SizedBox(width: 8), Text('Consulter')])), const PopupMenuItem(value: 'edit', child: Row(children: [Icon(LucideIcons.pencil, size: 14, color: kAccent), SizedBox(width: 8), Text('Modifier')])), const PopupMenuItem(value: 'delete', child: Row(children: [Icon(LucideIcons.trash2, size: 14, color: kRed), SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: kRed))]))], child: const Padding(padding: EdgeInsets.all(4), child: Icon(LucideIcons.moreVertical, size: 16, color: kTextSub))),
        ]),
        if (tache.dateDebut != null || tache.dateFin != null || tache.budgetEstime > 0) ...[const SizedBox(height: 10), const Divider(height: 1, color: Color(0xFFF3F4F6)), const SizedBox(height: 10), if (tache.dateDebut != null || tache.dateFin != null) _InfoRow(icon: LucideIcons.calendarDays, label: 'Dates', value: '${tache.dateDebut ?? "?"} → ${tache.dateFin ?? "?"}'), if (tache.budgetEstime > 0) ...[const SizedBox(height: 6), _InfoRow(icon: LucideIcons.dollarSign, label: 'Budget prévu', value: _fmtNum(tache.budgetEstime))]],
        if (tache.remarques.isNotEmpty) ...[
          const SizedBox(height: 10), const Divider(height: 1, color: Color(0xFFF3F4F6)), const SizedBox(height: 6),
          GestureDetector(onTap: () => setState(() => _remarquesExpanded = !_remarquesExpanded), child: Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFFDE68A))), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(LucideIcons.messageSquare, size: 11, color: Color(0xFFD97706)), const SizedBox(width: 4), const Text('Remarques', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD97706)))])), const SizedBox(width: 6), Icon(_remarquesExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 13, color: const Color(0xFFD97706))])),
          if (_remarquesExpanded) ...[const SizedBox(height: 8), Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFDE68A))), child: Text(tache.remarques, style: const TextStyle(fontSize: 12, color: kTextMain, height: 1.5)))],
        ],
      ])),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon; final String label, value;
  const _InfoRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(4)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 11, color: kTextSub), const SizedBox(width: 4), Text(label, style: const TextStyle(fontSize: 10, color: kTextSub, fontWeight: FontWeight.w600))]))]),
    const SizedBox(height: 3),
    Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextMain)),
  ]);
}


// ══════════════════════════════════════════════════════════════════════════════
//  ONGLET FINANCES — Devis initial + Tableau unique toutes factures
// ══════════════════════════════════════════════════════════════════════════════
class _FinancesTab extends StatefulWidget {
  final Project project;
  final String Function(double) fmt;
  const _FinancesTab({required this.project, required this.fmt});
  @override State<_FinancesTab> createState() => _FinancesTabState();
}

class _FinancesTabState extends State<_FinancesTab> {
  List<Facture> _factures = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data = await FactureService.getFactures(widget.project.id);
      setState(() { _factures = data; _loading = false; });
      await ProjetService.syncBudgetDepense(widget.project.id);
    } catch (_) { setState(() => _loading = false); }
  }

  // ── Accesseurs ──────────────────────────────────────────────────────────────
  Facture? get _devisInitial =>
      _factures.where((f) => (f.factureType ?? 'extra') == 'initiale').firstOrNull;

  List<Facture> get _facturesExtra =>
      _factures.where((f) => (f.factureType ?? 'extra') == 'extra').toList();

  double get _montantDevis    => _devisInitial?.montant ?? 0;
  double get _totalExtra      => _facturesExtra.fold(0.0, (s, f) => s + f.montant);
  double get _totalFacture    => _montantDevis + _totalExtra;
  double get _budgetTotal     => widget.project.budgetTotal;
  double get _ecart           => _totalFacture - _budgetTotal;
  double get _pct             => _budgetTotal > 0 ? (_totalFacture / _budgetTotal).clamp(0.0, 1.1) : 0.0;
  bool   get _depasse         => _totalFacture > _budgetTotal;
  bool   get _approche        => !_depasse && _budgetTotal > 0 && _pct >= 0.85;

  // ── Actions ─────────────────────────────────────────────────────────────────
  void _ouvrirDialog({bool isInitiale = false, Facture? existing}) {
    showDialog(
      context: context,
      builder: (_) => _FactureDialog(
        project: widget.project,
        isInitiale: isInitiale,
        existing: existing,
        onSaved: (String msg) { _load(); _snack(context, msg, kAccent); },
      ),
    );
  }

  Future<void> _supprimerFacture(Facture f) async {
    await FactureService.deleteFacture(f.id);
    await ProjetService.syncBudgetDepense(widget.project.id);
    _load();
    _snack(context, 'Facture supprimée', kRed);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final pad = isMobile ? 16.0 : 28.0;

    if (_loading) return const Center(child: CircularProgressIndicator(color: kAccent));

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── HEADER ─────────────────────────────────────────────────────────
        _buildHeader(isMobile),
        const SizedBox(height: 20),

        // ── KPIs ───────────────────────────────────────────────────────────
        _buildKpis(),
        const SizedBox(height: 16),

        // ── BARRE BUDGET ───────────────────────────────────────────────────
        _buildBudgetBar(),
        const SizedBox(height: 24),

        // ── DEVIS INITIAL ──────────────────────────────────────────────────
        _buildDevisInitialSection(),
        const SizedBox(height: 24),

        // ── TABLEAU TOUTES FACTURES ────────────────────────────────────────
        _buildTableauFactures(),
      ]),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader(bool isMobile) {
    return Row(children: [
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Finances', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kTextMain)),
        SizedBox(height: 3),
        Text('Devis initial · Factures · Suivi budgétaire', style: TextStyle(color: kTextSub, fontSize: 12)),
      ])),
      if (_devisInitial == null)
        _FinBtn(
          label: isMobile ? 'Devis' : 'Créer le devis initial',
          icon: LucideIcons.filePlus,
          color: const Color(0xFF8B5CF6),
          onTap: () => _ouvrirDialog(isInitiale: true),
        ),
      const SizedBox(width: 8),
      _FinBtn(
        label: isMobile ? 'Facture' : 'Nouvelle facture',
        icon: LucideIcons.plus,
        color: kAccent,
        onTap: () => _ouvrirDialog(isInitiale: false),
      ),
    ]);
  }

  // ── KPIs ────────────────────────────────────────────────────────────────────
  Widget _buildKpis() {
    final barColor = _depasse ? kRed : _approche ? const Color(0xFFF59E0B) : kAccent;
    return Row(children: [
      Expanded(child: _KpiCard(label: 'Budget projet',  value: widget.fmt(_budgetTotal),     color: const Color(0xFF6366F1), icon: LucideIcons.wallet)),
      const SizedBox(width: 10),
      Expanded(child: _KpiCard(label: 'Devis initial',  value: _devisInitial != null ? widget.fmt(_montantDevis) : '—',   color: const Color(0xFF8B5CF6), icon: LucideIcons.fileText)),
      const SizedBox(width: 10),
      Expanded(child: _KpiCard(label: 'Total factures', value: widget.fmt(_totalFacture),    color: barColor,               icon: LucideIcons.receipt)),
      const SizedBox(width: 10),
      Expanded(child: _KpiCard(label: _depasse ? 'Dépassement' : 'Reste', value: widget.fmt(_ecart.abs()), color: _depasse ? kRed : const Color(0xFF10B981), icon: _depasse ? LucideIcons.alertTriangle : LucideIcons.trendingDown)),
    ]);
  }

  // ── Barre budget ─────────────────────────────────────────────────────────────
  Widget _buildBudgetBar() {
    final barColor = _depasse ? kRed : _approche ? const Color(0xFFF59E0B) : kAccent;
    final pctDisplay = (_pct * 100).clamp(0, 999).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _depasse ? kRed.withOpacity(0.25) : _approche ? const Color(0xFFFDE68A) : const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Consommation du budget', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kTextMain)),
          const Spacer(),
          Text('$pctDisplay%', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: barColor)),
        ]),
        if (_depasse) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: kRed.withOpacity(0.07), borderRadius: BorderRadius.circular(8), border: Border.all(color: kRed.withOpacity(0.2))),
            child: Row(children: [const Icon(LucideIcons.alertTriangle, size: 13, color: kRed), const SizedBox(width: 8), Text('Budget dépassé de ${widget.fmt(_ecart.abs())}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kRed))]),
          ),
        ] else if (_approche) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFDE68A))),
            child: Row(children: [const Icon(LucideIcons.alertCircle, size: 13, color: Color(0xFFD97706)), const SizedBox(width: 8), Text('Attention — ${widget.fmt(_budgetTotal - _totalFacture)} restants', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFD97706)))]),
          ),
        ],
        const SizedBox(height: 12),
        // Barre empilée : devis + extras
        LayoutBuilder(builder: (ctx, cs) {
          final W = cs.maxWidth;
          final maxVal = _budgetTotal > 0 ? _budgetTotal : (_totalFacture > 0 ? _totalFacture * 1.1 : 1.0);
          final wDevis = _budgetTotal > 0 ? ((_montantDevis / maxVal) * W).clamp(0.0, W) : 0.0;
          final wExtra = _budgetTotal > 0 ? ((_totalExtra  / maxVal) * W).clamp(0.0, W - wDevis) : 0.0;
          final wBudget = W;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Barre budget (fond)
            Stack(children: [
              Container(height: 10, width: wBudget, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(6))),
              // Segment devis
              if (wDevis > 0) Positioned(left: 0, child: Container(height: 10, width: wDevis, decoration: BoxDecoration(color: const Color(0xFF8B5CF6), borderRadius: BorderRadius.only(topLeft: const Radius.circular(6), bottomLeft: const Radius.circular(6), topRight: Radius.circular(wExtra == 0 ? 6 : 0), bottomRight: Radius.circular(wExtra == 0 ? 6 : 0))))),
              // Segment extras
              if (wExtra > 0) Positioned(left: wDevis, child: Container(height: 10, width: wExtra, decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.only(topLeft: Radius.circular(wDevis == 0 ? 6 : 0), bottomLeft: Radius.circular(wDevis == 0 ? 6 : 0), topRight: const Radius.circular(6), bottomRight: const Radius.circular(6))))),
            ]),
            const SizedBox(height: 8),
            // Légende
            Row(children: [
              _BarLegend(color: const Color(0xFF8B5CF6), label: 'Devis initial', value: widget.fmt(_montantDevis)),
              const SizedBox(width: 16),
              _BarLegend(color: const Color(0xFFF59E0B), label: 'Extras', value: widget.fmt(_totalExtra)),
              const Spacer(),
              _BarLegend(color: const Color(0xFFE5E7EB), label: 'Budget', value: widget.fmt(_budgetTotal), dark: true),
            ]),
          ]);
        }),
      ]),
    );
  }

  // ── Devis initial ────────────────────────────────────────────────────────────
  Widget _buildDevisInitialSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(LucideIcons.fileText, size: 15, color: Color(0xFF8B5CF6))),
        const SizedBox(width: 10),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Devis initial', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextMain)),
          Text('Premier devis estimatif du projet', style: TextStyle(fontSize: 11, color: kTextSub)),
        ])),
        if (_devisInitial == null)
          _FinBtn(label: 'Créer', icon: LucideIcons.plus, color: const Color(0xFF8B5CF6), onTap: () => _ouvrirDialog(isInitiale: true))
        else
          _FinBtn(label: 'Modifier', icon: LucideIcons.pencil, color: const Color(0xFF8B5CF6), onTap: () => _ouvrirDialog(isInitiale: true, existing: _devisInitial)),
      ]),
      const SizedBox(height: 12),
      if (_devisInitial == null)
        _EmptyDevis(onTap: () => _ouvrirDialog(isInitiale: true))
      else
        _DevisCard(facture: _devisInitial!, fmt: widget.fmt, onDelete: () => _supprimerFacture(_devisInitial!)),
    ]);
  }

  // ── Tableau toutes factures ──────────────────────────────────────────────────
  Widget _buildTableauFactures() {
    final toutes = _factures; // initiale + extras mélangées, triées par date
    toutes.sort((a, b) => (a.createdAt).compareTo(b.createdAt));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── En-tête tableau ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
          child: Row(children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Toutes les factures', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextMain)),
              SizedBox(height: 2),
              Text('Devis initial + avenants + factures entreprises', style: TextStyle(fontSize: 11, color: kTextSub)),
            ])),
            _FinBtn(label: 'Ajouter', icon: LucideIcons.plus, color: kAccent, onTap: () => _ouvrirDialog(isInitiale: false)),
          ]),
        ),

        const SizedBox(height: 14),
        const Divider(height: 1, color: Color(0xFFF3F4F6)),

        // ── Colonnes header ──────────────────────────────────────────────
        Container(
          color: const Color(0xFFF9FAFB),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(children: const [
            SizedBox(width: 100, child: Text('TYPE',       style: _hStyle)),
            SizedBox(width: 8),
            Expanded(flex: 3, child: Text('N° / DÉSIGNATION', style: _hStyle)),
            Expanded(flex: 2, child: Text('ÉMETTEUR',     style: _hStyle)),
            Expanded(flex: 2, child: Text('ÉCHÉANCE',     style: _hStyle)),
            Expanded(flex: 2, child: Text('MONTANT',      style: _hStyle, textAlign: TextAlign.right)),
            SizedBox(width: 80, child: Text('STATUT',     style: _hStyle, textAlign: TextAlign.center)),
            SizedBox(width: 48),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFFF3F4F6)),

        // ── Lignes ───────────────────────────────────────────────────────
        if (toutes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text('Aucune facture — créez d\'abord le devis initial', style: TextStyle(color: kTextSub, fontSize: 13))),
          )
        else
          ...toutes.asMap().entries.map((e) {
            final i = e.key; final f = e.value;
            return _LigneFacture(
              facture: f,
              index: i,
              fmt: widget.fmt,
              onDelete: () => _supprimerFacture(f),
              onEdit: () => _ouvrirDialog(
                isInitiale: (f.factureType ?? 'extra') == 'initiale',
                existing: f,
              ),
            );
          }),

        // ── Total ────────────────────────────────────────────────────────
        if (toutes.isNotEmpty) ...[
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(children: [
              const Spacer(),
              Text('TOTAL  ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextSub)),
              Text(widget.fmt(_totalFacture), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _depasse ? kRed : kTextMain)),
              const SizedBox(width: 128),
            ]),
          ),
        ],
      ]),
    );
  }

  static const _hStyle = TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kTextSub, letterSpacing: 0.6);
}

// ── Ligne tableau ─────────────────────────────────────────────────────────────
class _LigneFacture extends StatelessWidget {
  final Facture facture;
  final int index;
  final String Function(double) fmt;
  final VoidCallback onDelete, onEdit;

  const _LigneFacture({required this.facture, required this.index, required this.fmt, required this.onDelete, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final f = facture;
    final isInitiale = (f.factureType ?? 'extra') == 'initiale';
    // TYPE : Facture Globale (devis initial) ou Facture Supplémentaire (extra)
    final typeColor  = isInitiale ? const Color(0xFF8B5CF6) : const Color(0xFFF59E0B);
    final typeLabel  = isInitiale ? 'Fact. Globale' : 'Fact. Suppl.';
    final statColor  = _factureColor(f.statut);
    final hasPj      = f.urlPdf != null && f.urlPdf!.isNotEmpty;

    return Container(
      color: index % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [

        // Type badge
        SizedBox(width: 100, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: typeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: typeColor.withOpacity(0.3)),
          ),
          child: Text(typeLabel, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: typeColor), textAlign: TextAlign.center),
        )),
        const SizedBox(width: 8),

        // N° / désignation
        Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(f.numero.isNotEmpty ? f.numero : '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextMain), overflow: TextOverflow.ellipsis),
          if (f.tacheAssociee.isNotEmpty) Text(f.tacheAssociee, style: const TextStyle(fontSize: 10, color: kTextSub), overflow: TextOverflow.ellipsis),
        ])),

        // Émetteur
        Expanded(flex: 2, child: Text(f.fournisseur.isNotEmpty ? f.fournisseur : (f.chefProjet.isNotEmpty ? f.chefProjet : '—'), style: const TextStyle(fontSize: 12, color: kTextSub), overflow: TextOverflow.ellipsis)),

        // Échéance
        Expanded(flex: 2, child: Text(f.dateEcheance?.isNotEmpty == true ? f.dateEcheance! : '—', style: const TextStyle(fontSize: 12, color: kTextSub))),

        // Montant
        Expanded(flex: 2, child: Text(fmt(f.montant), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextMain), textAlign: TextAlign.right)),

        // Statut
        SizedBox(width: 80, child: Center(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: statColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Text(_factureLabel(f.statut), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statColor), textAlign: TextAlign.center),
        ))),

        // Actions : icône pièce jointe + menu
        SizedBox(width: 56, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          // Bouton pièce jointe — toujours visible, grisé si pas de fichier
          Tooltip(
            message: hasPj ? 'Ouvrir la pièce jointe' : 'Aucune pièce jointe',
            child: GestureDetector(
              onTap: hasPj
                  ? () async {
                      final raw = f.urlPdf!;
                      // Fichier local : on ne peut pas l'ouvrir depuis web/desktop directement
                      if (raw.startsWith('fichier:')) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Fichier local : ${raw.replaceFirst('fichier:', '')}'),
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.all(12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          duration: const Duration(seconds: 3),
                        ));
                      } else {
                        final uri = Uri.tryParse(raw);
                        if (uri != null) try { await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (_) {}
                      }
                    }
                  : null,
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: hasPj ? const Color(0xFFEFF6FF) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  LucideIcons.paperclip,
                  size: 13,
                  color: hasPj ? const Color(0xFF3B82F6) : const Color(0xFFD1D5DB),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            onSelected: (v) { if (v == 'edit') onEdit(); if (v == 'delete') onDelete(); },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit',   child: Row(children: [Icon(LucideIcons.pencil, size: 13, color: kAccent),  SizedBox(width: 8), Text('Modifier')])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(LucideIcons.trash2, size: 13, color: kRed),    SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: kRed))])),
            ],
            padding: EdgeInsets.zero,
            child: const Padding(padding: EdgeInsets.all(4), child: Icon(LucideIcons.moreVertical, size: 14, color: kTextSub)),
          ),
        ])),
      ]),
    );
  }
}

// ── Card Devis Initial (haut de page) ─────────────────────────────────────────
class _DevisCard extends StatelessWidget {
  final Facture facture;
  final String Function(double) fmt;
  final VoidCallback onDelete;
  const _DevisCard({required this.facture, required this.fmt, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final f = facture;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
        boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(LucideIcons.fileCheck, size: 20, color: Color(0xFF8B5CF6))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f.numero.isNotEmpty ? f.numero : 'Devis initial', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextMain)),
            const SizedBox(height: 3),
            Text('Premier devis estimatif du projet', style: const TextStyle(fontSize: 11, color: kTextSub)),
          ])),
          // Montant mis en avant
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(fmt(f.montant), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF8B5CF6))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: _factureColor(f.statut).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(_factureLabel(f.statut), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _factureColor(f.statut))),
            ),
          ]),
        ]),
        const SizedBox(height: 14),
        const Divider(height: 1, color: Color(0xFFF3F4F6)),
        const SizedBox(height: 12),
        Row(children: [
          if (f.fournisseur.isNotEmpty) ...[_DevisPill(icon: LucideIcons.building2, label: f.fournisseur), const SizedBox(width: 8)],
          if (f.dateEcheance?.isNotEmpty == true) ...[_DevisPill(icon: LucideIcons.calendar, label: f.dateEcheance!), const SizedBox(width: 8)],
          if (f.chefProjet.isNotEmpty) _DevisPill(icon: LucideIcons.user, label: f.chefProjet),
          const Spacer(),
          if (f.urlPdf != null && f.urlPdf!.isNotEmpty)
            GestureDetector(
              onTap: () async { final uri = Uri.tryParse(f.urlPdf!); if (uri != null) try { await launchUrl(uri); } catch (_) {} },
              child: Row(children: [const Icon(LucideIcons.paperclip, size: 12, color: Color(0xFF3B82F6)), const SizedBox(width: 4), const Text('Pièce jointe', style: TextStyle(fontSize: 11, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600))]),
            ),
          const SizedBox(width: 8),
          GestureDetector(onTap: onDelete, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(7)), child: const Icon(LucideIcons.trash2, size: 13, color: kRed))),
        ]),
      ]),
    );
  }
}

class _DevisPill extends StatelessWidget {
  final IconData icon; final String label;
  const _DevisPill({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(6)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: kTextSub), const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 11, color: kTextSub, fontWeight: FontWeight.w500)),
    ]),
  );
}

// ── Empty Devis ───────────────────────────────────────────────────────────────
class _EmptyDevis extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyDevis({required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.2)),
      ),
      child: Column(children: [
        Icon(LucideIcons.filePlus, size: 28, color: const Color(0xFF8B5CF6).withOpacity(0.5)),
        const SizedBox(height: 8),
        const Text('Aucun devis initial', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF8B5CF6))),
        const SizedBox(height: 3),
        const Text('Créez le premier devis estimatif pour ce projet', style: TextStyle(fontSize: 11, color: kTextSub), textAlign: TextAlign.center),
      ]),
    ),
  );
}

// ── Barre légende ─────────────────────────────────────────────────────────────
class _BarLegend extends StatelessWidget {
  final Color color; final String label, value; final bool dark;
  const _BarLegend({required this.color, required this.label, required this.value, this.dark = false});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3), border: dark ? Border.all(color: const Color(0xFFD1D5DB)) : null)),
    const SizedBox(width: 5),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 9, color: kTextSub, fontWeight: FontWeight.w500)),
      Text(value,  style: TextStyle(fontSize: 11, color: dark ? kTextSub : kTextMain, fontWeight: FontWeight.w700)),
    ]),
  ]);
}

// ── Bouton action finances ────────────────────────────────────────────────────
class _FinBtn extends StatelessWidget {
  final String label; final IconData icon; final Color color; final VoidCallback onTap;
  const _FinBtn({required this.label, required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.09), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ]),
    ),
  );
}

// ── Dialog Facture ─────────────────────────────────────────────────────────────
class _FactureDialog extends StatefulWidget {
  final Project project;
  final bool isInitiale;
  final Facture? existing;
  final void Function(String msg) onSaved;
  const _FactureDialog({required this.project, required this.isInitiale, this.existing, required this.onSaved});
  @override State<_FactureDialog> createState() => _FactureDialogState();
}

class _FactureDialogState extends State<_FactureDialog> {
  final _numCtrl      = TextEditingController();
  final _montantCtrl  = TextEditingController();
  final _echeanceCtrl = TextEditingController();
  final _fournCtrl    = TextEditingController();

  String     _statut           = 'en_attente';
  String?    _pieceJointeNom;
  String?    _pieceJointeUrl;
  List<int>? _pieceJointeBytes;



  Color get _accent => widget.isInitiale ? const Color(0xFF8B5CF6) : kAccent;

  @override
  void initState() {
    super.initState();
    final f = widget.existing;
    if (f != null) {
      _numCtrl.text      = f.numero;
      _montantCtrl.text  = f.montant > 0 ? f.montant.toStringAsFixed(2) : '';
      _echeanceCtrl.text = f.dateEcheance ?? '';
      _fournCtrl.text    = f.fournisseur;
      _statut            = f.statut;
      _pieceJointeUrl    = f.urlPdf;
      if (f.urlPdf?.startsWith('fichier:') == true) {
        _pieceJointeNom = f.urlPdf!.replaceFirst('fichier:', '');
      }
    }
  }

  @override
  void dispose() {
    _numCtrl.dispose();
    _montantCtrl.dispose();
    _echeanceCtrl.dispose();
    _fournCtrl.dispose();
    super.dispose();
  }

  // ── Pick fichier ─────────────────────────────────────────────────────────────
  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _pieceJointeNom   = file.name;
          _pieceJointeUrl   = 'fichier:${file.name}';
          _pieceJointeBytes = file.bytes;
        });

      }
    } catch (_) {
      _snack(context, 'Impossible d\'ouvrir le fichier', kRed);
    }
  }

  Future<void> _pickDate() async {
    DateTime init = DateTime.now();
    if (_echeanceCtrl.text.isNotEmpty) {
      final p = DateTime.tryParse(_echeanceCtrl.text);
      if (p != null) init = p;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('fr', 'FR'),
      builder: (ctx2, child) => Theme(
        data: Theme.of(ctx2).copyWith(
          colorScheme: ColorScheme.light(primary: _accent, onPrimary: Colors.white, surface: Colors.white, onSurface: kTextMain),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _echeanceCtrl.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _submit() async {
    final num = _numCtrl.text.trim();
    if (num.isEmpty) { _snack(context, 'Numéro / référence obligatoire', kRed); return; }
    if (_montantCtrl.text.trim().isEmpty) { _snack(context, 'Montant obligatoire', kRed); return; }
    final m = double.tryParse(_montantCtrl.text.replaceAll(' ', '').replaceAll(',', '.'));
    if (m == null || m <= 0) { _snack(context, 'Montant invalide', kRed); return; }

    final facture = Facture(
      id:            widget.existing?.id ?? '',
      projetId:      widget.project.id,
      phaseId:       null,
      numero:        num,
      montant:       m,
      statut:        _statut,
      dateEcheance:  _echeanceCtrl.text.trim().isEmpty ? null : _echeanceCtrl.text.trim(),
      urlPdf:        _pieceJointeUrl,
      fournisseur:   _fournCtrl.text.trim(),
      tacheAssociee: '',
      chefProjet:    widget.project.chef,
      createdAt:     widget.existing?.createdAt ?? DateTime.now().toIso8601String(),
      factureType:   widget.isInitiale ? 'initiale' : 'extra',
    );

    if (widget.existing != null) {
      await FactureService.updateFacture(facture);
    } else {
      await FactureService.addFacture(facture);
    }
    await ProjetService.syncBudgetDepense(widget.project.id);
    if (mounted) Navigator.pop(context);
    widget.onSaved(widget.existing != null ? 'Facture modifiée' : 'Facture ajoutée');
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [

          // ── Header ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.07),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: _accent.withOpacity(0.15))),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: _accent.withOpacity(0.13), borderRadius: BorderRadius.circular(12)),
                child: Icon(widget.isInitiale ? LucideIcons.fileText : LucideIcons.receipt, color: _accent, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  isEdit ? 'Modifier la facture' : (widget.isInitiale ? 'Devis initial' : 'Nouvelle facture'),
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _accent),
                ),
                Text(
                  widget.isInitiale ? 'Premier devis estimatif du projet' : 'Avenant · Architecte · Entreprise',
                  style: const TextStyle(color: kTextSub, fontSize: 12),
                ),
              ])),
            ]),
          ),

          Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── PIÈCE JOINTE EN HAUT ─────────────────────────────────────
            const Text('PIÈCE JOINTE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSub, letterSpacing: 0.5)),
            const SizedBox(height: 7),
            GestureDetector(
              onTap: _pickFile,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                decoration: BoxDecoration(
                  color: _pieceJointeNom != null ? const Color(0xFFEFFAF4) : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _pieceJointeNom != null
                        ? const Color(0xFF10B981).withOpacity(0.5)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
                child: _pieceJointeNom == null
                    ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: _accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: Icon(LucideIcons.paperclip, size: 20, color: _accent),
                        ),
                        const SizedBox(width: 14),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Joindre une pièce jointe (facultatif)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _accent)),
                          const SizedBox(height: 3),
                          const Text('PDF, PNG, JPG acceptés', style: TextStyle(fontSize: 11, color: kTextSub)),
                        ]),
                      ])
                    : Row(children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(LucideIcons.fileCheck, size: 18, color: Color(0xFF10B981)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_pieceJointeNom!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextMain), overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 3),
                          const Text('Fichier joint ✓', style: TextStyle(fontSize: 11, color: Color(0xFF10B981))),
                        ])),
                        GestureDetector(
                          onTap: () => setState(() {
                            _pieceJointeNom   = null;
                            _pieceJointeUrl   = null;
                            _pieceJointeBytes = null;
                          }),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(6)),
                            child: const Icon(LucideIcons.x, size: 14, color: kTextSub),
                          ),
                        ),
                      ]),
              ),
            ),

            const SizedBox(height: 18),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 16),

            // ── Numéro + Montant ─────────────────────────────────────────
            Row(children: [
              Expanded(child: _DField(
                icon: LucideIcons.hash,
                label: 'NUMÉRO / RÉFÉRENCE *',
                hint: widget.isInitiale ? 'DEV-2025-001' : 'FAC-2025-001',
                controller: _numCtrl,
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildMontantField()),
            ]),
            const SizedBox(height: 12),

            // ── Fournisseur + Date ───────────────────────────────────────
            Row(children: [
              Expanded(child: _DField(
                icon: LucideIcons.building2,
                label: widget.isInitiale ? 'ÉTABLI PAR' : 'FOURNISSEUR',
                hint: 'Cabinet / Entreprise',
                controller: _fournCtrl,
              )),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: _pickDate,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("DATE D'ÉCHÉANCE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSub, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE5E7EB))),
                    child: Row(children: [
                      const Icon(LucideIcons.calendar, size: 14, color: kTextSub),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        _echeanceCtrl.text.isEmpty ? 'Sélectionner' : _echeanceCtrl.text,
                        style: TextStyle(fontSize: 13, color: _echeanceCtrl.text.isEmpty ? kTextSub : kTextMain),
                      )),
                    ]),
                  ),
                ]),
              )),
            ]),
            const SizedBox(height: 14),

            // ── Statut ───────────────────────────────────────────────────
            const Text('STATUT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSub, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Row(children: [
              for (final s in ['en_attente', 'payee', 'en_retard'])
                Expanded(child: Padding(
                  padding: EdgeInsets.only(right: s == 'en_retard' ? 0 : 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _statut = s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _statut == s ? _factureColor(s).withOpacity(0.1) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _statut == s ? _factureColor(s) : const Color(0xFFE5E7EB), width: _statut == s ? 2 : 1),
                      ),
                      child: Text(_factureLabel(s), textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: _statut == s ? FontWeight.w700 : FontWeight.w500, color: _statut == s ? _factureColor(s) : kTextSub)),
                    ),
                  ),
                )),
            ]),
          ])),

          // ── Footer ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
            child: Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13), side: const BorderSide(color: Color(0xFFD1D5DB)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('Annuler', style: TextStyle(color: kTextSub, fontWeight: FontWeight.w600)),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(backgroundColor: _accent, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: Text(isEdit ? 'Enregistrer' : 'Ajouter', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              )),
            ]),
          ),
        ])),
      ),
    );
  }

  // ── Champ montant avec badge "auto" ──────────────────────────────────────────
  Widget _buildMontantField() {
    return _DField(
      icon: LucideIcons.banknote,
      label: 'MONTANT TOTAL (DT) *',
      hint: '0.00',
      controller: _montantCtrl,
      keyboardType: TextInputType.number,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  GANTT
// ══════════════════════════════════════════════════════════════════════════════
class _GanttView extends StatelessWidget {
  final List<Tache> taches; final List<Phase> phases;
  const _GanttView({required this.taches, required this.phases});
  static const _monthNames = ['Jan','Fév','Mar','Avr','Mai','Jun','Jul','Aoû','Sep','Oct','Nov','Déc'];
  static const double _labelW = 180.0;

  @override
  Widget build(BuildContext context) {
    final withDates    = taches.where((t) => t.dateDebut != null && t.dateFin != null).toList()..sort((a, b) => a.dateDebut!.compareTo(b.dateDebut!));
    final withoutDates = taches.where((t) => t.dateDebut == null || t.dateFin == null).toList();
    if (withDates.isEmpty) return Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))), child: Column(children: [const Icon(LucideIcons.calendarOff, size: 36, color: kTextSub), const SizedBox(height: 12), const Text('Aucune tâche avec des dates', style: TextStyle(color: kTextSub, fontSize: 14)), const SizedBox(height: 6), const Text('Ajoutez des dates à vos tâches pour afficher le Gantt', style: TextStyle(color: kTextSub, fontSize: 12), textAlign: TextAlign.center)]));
    DateTime minDate = withDates.map((t) => DateTime.parse(t.dateDebut!)).reduce((a, b) => a.isBefore(b) ? a : b);
    DateTime maxDate = withDates.map((t) => DateTime.parse(t.dateFin!)).reduce((a, b) => a.isAfter(b) ? a : b);
    minDate = DateTime(minDate.year, minDate.month, 1); maxDate = DateTime(maxDate.year, maxDate.month + 1, 1);
    final totalDays = maxDate.difference(minDate).inDays;
    final months = <DateTime>[]; var cur = DateTime(minDate.year, minDate.month, 1);
    while (cur.isBefore(maxDate)) { months.add(cur); cur = DateTime(cur.year, cur.month + 1, 1); }
    return Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]), clipBehavior: Clip.hardEdge, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 10), child: Row(children: [const Icon(LucideIcons.barChart2, size: 16, color: kTextSub), const SizedBox(width: 8), const Text('Diagramme de Gantt', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: kTextMain))])),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: LayoutBuilder(builder: (ctx, _) {
        final chartW = (months.length * 80.0).clamp(400.0, 1200.0); final totalW = _labelW + chartW;
        return SizedBox(width: totalW, child: Column(children: [
          Container(color: const Color(0xFF1F2937), child: Row(children: [
            Container(width: _labelW, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xFF374151)))), child: const Text('Tâche', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
            Expanded(child: Column(children: [const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Timeline', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600))), SizedBox(height: 28, child: LayoutBuilder(builder: (ctx2, cs2) { final W = cs2.maxWidth; return Stack(children: months.map((m) { final s = m.difference(minDate).inDays / totalDays; final e = DateTime(m.year, m.month + 1, 1).difference(minDate).inDays / totalDays; return Positioned(left: (s * W).clamp(0.0, W), width: ((e - s) * W).clamp(0.0, W), top: 0, bottom: 0, child: Container(decoration: const BoxDecoration(border: Border(left: BorderSide(color: Color(0xFF374151), width: 0.5))), alignment: Alignment.center, child: Text('${_monthNames[m.month - 1]} ${m.year}', style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w500)))); }).toList()); }))]))
          ])),
          ..._buildGanttRows(withDates, phases, minDate, totalDays, months),
          if (withoutDates.isNotEmpty) ...[Container(height: 1, color: const Color(0xFFE5E7EB)), Padding(padding: const EdgeInsets.all(12), child: Row(children: [const Icon(LucideIcons.alertCircle, size: 12, color: kTextSub), const SizedBox(width: 6), Text('${withoutDates.length} tâche(s) sans dates', style: const TextStyle(color: kTextSub, fontSize: 12)), const SizedBox(width: 8), Wrap(spacing: 6, children: withoutDates.map((t) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)), child: Text(t.titre, style: const TextStyle(fontSize: 11, color: kTextSub)))).toList())]))],
        ]));
      })),
    ]));
  }

  List<Widget> _buildGanttRows(List<Tache> withDates, List<Phase> phases, DateTime minDate, int totalDays, List<DateTime> months) {
    final rows = <Widget>[]; final today = DateTime.now();
    void addTacheRow(Tache t, int i) {
      final debut = DateTime.parse(t.dateDebut!); final fin = DateTime.parse(t.dateFin!);
      final pct = t.statut == 'termine' ? 100 : t.statut == 'en_cours' ? 65 : 0; final color = _tacheColor(t.statut);
      rows.add(Container(height: 48, color: i % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA), child: Row(children: [
        Container(width: _labelW, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xFFE5E7EB)))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(t.titre, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextMain), overflow: TextOverflow.ellipsis), if (t.description.isNotEmpty) Text(t.description, style: const TextStyle(fontSize: 10, color: kTextSub), overflow: TextOverflow.ellipsis)])),
        Expanded(child: LayoutBuilder(builder: (ctx, cs) {
          final W = cs.maxWidth;
          final barL = ((debut.difference(minDate).inDays / totalDays) * W).clamp(0.0, W);
          final barW = (((fin.difference(debut).inDays + 1) / totalDays) * W).clamp(8.0, W - barL);
          final todayX = ((today.difference(minDate).inDays / totalDays) * W).clamp(0.0, W);
          return Stack(children: [
            ...months.map((m) { final mx = (m.difference(minDate).inDays / totalDays * W).clamp(0.0, W); return Positioned(left: mx, top: 0, bottom: 0, width: 0.5, child: Container(color: const Color(0xFFE5E7EB))); }),
            if (todayX > 0 && todayX < W) Positioned(left: todayX, top: 0, bottom: 0, width: 1.5, child: Container(color: kRed.withOpacity(0.3))),
            Positioned(left: barL, top: 12, bottom: 12, width: barW, child: Container(decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(4)))),
            Positioned(left: barL, top: 12, bottom: 12, width: (barW * pct / 100).clamp(0.0, barW), child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)))),
            Positioned(left: barL, top: 0, bottom: 0, width: barW, child: Center(child: Text('$pct%', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700, shadows: [Shadow(color: Colors.black26, blurRadius: 2)])))),
          ]);
        })),
      ])));
    }
    void addPhaseHeader(String nom, Color color) {
      rows.add(Container(color: const Color(0xFFF3F4F6), child: Row(children: [Container(width: _labelW, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xFFE5E7EB)))), child: Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))), const SizedBox(width: 8), Expanded(child: Text(nom, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextMain), overflow: TextOverflow.ellipsis))])), const Expanded(child: SizedBox(height: 30))])));
    }
    for (final ph in phases) {
      final phTaches = withDates.where((t) => t.phaseId == ph.id).toList(); if (phTaches.isEmpty) continue;
      final prog = phTaches.where((t) => t.statut == 'termine').length / phTaches.length;
      final color = prog == 1.0 ? const Color(0xFF10B981) : prog > 0 ? kAccent : const Color(0xFF9CA3AF);
      addPhaseHeader(ph.nom, color);
      for (int i = 0; i < phTaches.length; i++) addTacheRow(phTaches[i], i);
    }
    final sansPh = withDates.where((t) => t.phaseId == null || t.phaseId!.isEmpty).toList();
    if (sansPh.isNotEmpty) { addPhaseHeader('Sans phase', const Color(0xFF9CA3AF)); for (int i = 0; i < sansPh.length; i++) addTacheRow(sansPh[i], i); }
    return rows;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ONGLET DOCUMENTS — NOUVEAU DESIGN
// ══════════════════════════════════════════════════════════════════════════════
class _DocumentsTab extends StatefulWidget {
  final Project project;
  const _DocumentsTab({required this.project});
  @override State<_DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends State<_DocumentsTab> {
  List<Document> _documents   = [];
  List<_DocUI>   _documentsUI = [];
  bool   _loading     = true;
  String _filterPhase = 'Toutes les phases';

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data = await DocumentService.getDocuments(widget.project.id);
      setState(() {
        _documents   = data;
        _documentsUI = data.map((d) => _DocUI.fromDocument(d)).toList();
        _loading     = false;
      });
    } catch (e) { setState(() => _loading = false); }
  }

  List<_DocUI> get _filtered {
    if (_filterPhase == 'Toutes les phases') return _documentsUI;
    return _documentsUI.where((d) => d.phase == _filterPhase).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final pad      = isMobile ? 16.0 : 28.0;
    if (_loading) return const Center(child: CircularProgressIndicator(color: kAccent));

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Documents & Livrables', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kTextMain)),
            SizedBox(height: 4),
            Text('Gérez vos plans, permis et dossiers par phase architecturale.', style: TextStyle(color: kTextSub, fontSize: 12)),
          ])),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => _showAddLivrableDialog(context),
            icon: const Icon(LucideIcons.upload, size: 14, color: Colors.white),
            label: Text(isMobile ? 'Livrable' : 'Nouveau livrable', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
            style: ElevatedButton.styleFrom(backgroundColor: kAccent, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          ),
        ]),
        const SizedBox(height: 20),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: kDocPhases.map((phase) {
            final isSelected = _filterPhase == phase;
            final color      = phase == 'Toutes les phases' ? kAccent : _phaseColor(phase);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _filterPhase = phase),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? color : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? color : const Color(0xFFE5E7EB), width: isSelected ? 2 : 1),
                    boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2))] : null,
                  ),
                  child: Text(phase, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? Colors.white : kTextSub)),
                ),
              ),
            );
          }).toList()),
        ),
        const SizedBox(height: 20),
        _buildGrid(),
      ]),
    );
  }

  Widget _buildGrid() {
    final filtered = _filtered;
    if (filtered.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
        child: Column(children: [
          Container(width: 64, height: 64, decoration: BoxDecoration(color: kAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(16)), child: Icon(LucideIcons.folderOpen, size: 28, color: kAccent.withOpacity(0.6))),
          const SizedBox(height: 16),
          Text(_filterPhase == 'Toutes les phases' ? 'Aucun document pour ce projet' : 'Aucun document pour la phase $_filterPhase', style: const TextStyle(color: kTextMain, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Ajoutez vos plans, devis et livrables', style: TextStyle(color: kTextSub, fontSize: 12)),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => _showAddLivrableDialog(context),
            icon: const Icon(LucideIcons.plus, size: 14, color: kAccent),
            label: const Text('Ajouter un livrable', style: TextStyle(color: kAccent, fontWeight: FontWeight.w600, fontSize: 13)),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), side: const BorderSide(color: kAccent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          ),
        ]),
      );
    }
    return LayoutBuilder(builder: (ctx, constraints) {
      final cols = constraints.maxWidth > 600 ? 2 : 1; final rows = <Widget>[];
      for (int i = 0; i < filtered.length; i += cols) {
        final rowItems = filtered.skip(i).take(cols).toList();
        rows.add(IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (int j = 0; j < rowItems.length; j++) ...[
            if (j > 0) const SizedBox(width: 14),
            Expanded(child: _DocumentCard(docUI: rowItems[j], onDelete: () async { await DocumentService.deleteDocument(rowItems[j].doc.id); _snack(context, 'Document supprimé', kRed); _load(); })),
          ],
          if (rowItems.length < cols) ...[const SizedBox(width: 14), const Expanded(child: SizedBox())],
        ])));
        if (i + cols < filtered.length) rows.add(const SizedBox(height: 14));
      }
      return Column(children: rows);
    });
  }

  void _showAddLivrableDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => _AddLivrableDialog(projectId: widget.project.id, onSaved: () { _load(); _snack(context, 'Livrable ajouté avec succès', kAccent); }));
  }
}

class _DocumentCard extends StatelessWidget {
  final _DocUI docUI; final VoidCallback onDelete;
  const _DocumentCard({required this.docUI, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final color = _phaseColor(docUI.phase); final doc = docUI.doc;
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFEEEEEE)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      clipBehavior: Clip.hardEdge,
      child: IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(width: 4, color: color),
        Expanded(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.3))), child: Text(docUI.phase, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color))),
            const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF374151), borderRadius: BorderRadius.circular(6)), child: Text(docUI.typeLabel, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white))),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (v) async { if (v == 'delete') onDelete(); if (v == 'open') { final uri = Uri.tryParse(doc.url); if (uri != null) try { await launchUrl(uri); } catch (_) {} } },
              itemBuilder: (_) => [const PopupMenuItem(value: 'open', child: Row(children: [Icon(LucideIcons.externalLink, size: 14, color: Color(0xFF3B82F6)), SizedBox(width: 8), Text('Ouvrir')])), const PopupMenuItem(value: 'delete', child: Row(children: [Icon(LucideIcons.trash2, size: 14, color: Color(0xFFEF4444)), SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: Color(0xFFEF4444)))]))],
              padding: EdgeInsets.zero,
              child: const Icon(LucideIcons.moreVertical, size: 15, color: kTextSub),
            ),
          ]),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)), child: Icon(_docIconFromLabel(docUI.typeLabel), size: 16, color: color)),
            const SizedBox(width: 12),
            Expanded(child: Text(docUI.nomAffiche, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kTextMain), maxLines: 2, overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 10),
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(6)), child: Text('Version ${docUI.version}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kTextSub))),
            const Spacer(),
            if (docUI.dateDoc != null && docUI.dateDoc!.isNotEmpty) Row(children: [const Icon(LucideIcons.calendar, size: 11, color: kTextSub), const SizedBox(width: 4), Text(docUI.dateDoc!, style: const TextStyle(fontSize: 11, color: kTextSub))]),
          ]),
        ]))),
      ])),
    );
  }
}

class _AddLivrableDialog extends StatefulWidget {
  final String projectId; final VoidCallback onSaved;
  const _AddLivrableDialog({required this.projectId, required this.onSaved});
  @override State<_AddLivrableDialog> createState() => _AddLivrableDialogState();
}
class _AddLivrableDialogState extends State<_AddLivrableDialog> {
  final _nomCtrl     = TextEditingController();
  final _urlCtrl     = TextEditingController();
  final _versionCtrl = TextEditingController(text: '1');
  final _dateCtrl    = TextEditingController();
  String _phase = 'ESQ'; String _typeLabel = 'Plan'; String? _fileName;

  @override void dispose() { _nomCtrl.dispose(); _urlCtrl.dispose(); _versionCtrl.dispose(); _dateCtrl.dispose(); super.dispose(); }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'dwg', 'xlsx', 'doc', 'docx']);
      if (result != null && result.files.isNotEmpty) { final file = result.files.first; setState(() { _fileName = file.name; if (_nomCtrl.text.isEmpty) _nomCtrl.text = file.name.split('.').first; _urlCtrl.text = 'fichier:${file.name}'; }); }
    } catch (e) { _snack(context, 'Impossible d\'ouvrir le fichier', kRed); }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2035), locale: const Locale('fr', 'FR'), builder: (ctx2, child) => Theme(data: Theme.of(ctx2).copyWith(colorScheme: ColorScheme.light(primary: kAccent, onPrimary: Colors.white, surface: Colors.white, onSurface: kTextMain)), child: child!));
    if (picked != null) setState(() { _dateCtrl.text = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}'; });
  }

  Future<void> _submit() async {
    final nom = _nomCtrl.text.trim();
    if (nom.isEmpty)    { _snack(context, 'Nom du document obligatoire', kRed); return; }
    if (nom.length < 2) { _snack(context, 'Le nom doit contenir au moins 2 caractères', kRed); return; }
    final version = int.tryParse(_versionCtrl.text.trim()) ?? 1;
    final nomEncode = _DocUI.encodeNom(nomAffiche: nom, phase: _phase, typeLabel: _typeLabel, version: version, dateDoc: _dateCtrl.text.trim().isEmpty ? null : _dateCtrl.text.trim());
    final typeFichier = _fileTypeFromLabel(_typeLabel);
    final url = _urlCtrl.text.trim().isEmpty ? (_fileName != null ? 'fichier:$_fileName' : 'non_defini') : _urlCtrl.text.trim();
    await DocumentService.addDocument(Document(id: '', projetId: widget.projectId, nom: nomEncode, url: url, type: typeFichier));
    if (mounted) Navigator.pop(context);
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 500), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _DialogHeader(icon: LucideIcons.filePlus2, title: 'Nouveau livrable', subtitle: 'Ajoutez un document à une phase'),
        Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('PHASE *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSub, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: kDocPhases.where((p) => p != 'Toutes les phases').map((phase) {
            final isSelected = _phase == phase; final c = _phaseColor(phase);
            return Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(onTap: () => setState(() => _phase = phase), child: AnimatedContainer(duration: const Duration(milliseconds: 150), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: isSelected ? c.withOpacity(0.1) : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? c : const Color(0xFFE5E7EB), width: isSelected ? 2 : 1)), child: Text(phase, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? c : kTextSub)))));
          }).toList())),
          const SizedBox(height: 14),
          _DField(icon: LucideIcons.fileText, label: 'NOM DU DOCUMENT *', hint: 'Ex: Plan architectural V2', controller: _nomCtrl),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('TYPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSub, letterSpacing: 0.5)), const SizedBox(height: 6),
              Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE5E7EB))), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: _typeLabel, isExpanded: true, padding: const EdgeInsets.symmetric(horizontal: 12), style: const TextStyle(color: kTextMain, fontSize: 13), borderRadius: BorderRadius.circular(8), items: kDocTypes.map((t) => DropdownMenuItem<String>(value: t, child: Row(children: [Icon(_docIconFromLabel(t), size: 13, color: kTextSub), const SizedBox(width: 8), Text(t)]))).toList(), onChanged: (v) => setState(() => _typeLabel = v ?? _typeLabel)))),
            ])),
            const SizedBox(width: 12),
            Expanded(child: _DField(icon: LucideIcons.gitBranch, label: 'VERSION', hint: '1', controller: _versionCtrl, keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 12),
          const Text("DATE DU DOCUMENT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSub, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          GestureDetector(onTap: _pickDate, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE5E7EB))), child: Row(children: [const Icon(LucideIcons.calendar, size: 14, color: kTextSub), const SizedBox(width: 8), Expanded(child: Text(_dateCtrl.text.isEmpty ? 'Sélectionner une date' : _dateCtrl.text, style: TextStyle(fontSize: 13, color: _dateCtrl.text.isEmpty ? kTextSub : kTextMain))), if (_dateCtrl.text.isNotEmpty) GestureDetector(onTap: () => setState(() => _dateCtrl.clear()), child: const Icon(LucideIcons.x, size: 13, color: kTextSub))]))),
          const SizedBox(height: 14),
          const Text('FICHIER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSub, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          GestureDetector(onTap: _pickFile, child: AnimatedContainer(duration: const Duration(milliseconds: 150), width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16), decoration: BoxDecoration(color: _fileName != null ? const Color(0xFFEFF6FF) : const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(10), border: Border.all(color: _fileName != null ? const Color(0xFF3B82F6) : const Color(0xFFE5E7EB))), child: Row(children: [Container(width: 36, height: 36, decoration: BoxDecoration(color: _fileName != null ? const Color(0xFF3B82F6).withOpacity(0.1) : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)), child: Icon(_fileName != null ? LucideIcons.fileCheck : LucideIcons.upload, size: 16, color: _fileName != null ? const Color(0xFF3B82F6) : kTextSub)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_fileName ?? 'Cliquez pour joindre un fichier', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _fileName != null ? kTextMain : kTextSub), overflow: TextOverflow.ellipsis), Text(_fileName != null ? 'Fichier sélectionné ✓' : 'PDF, DWG, XLSX, PNG acceptés', style: TextStyle(fontSize: 11, color: _fileName != null ? const Color(0xFF10B981) : kTextSub))])), if (_fileName != null) GestureDetector(onTap: () => setState(() { _fileName = null; _urlCtrl.clear(); }), child: const Icon(LucideIcons.x, size: 16, color: kTextSub))]))),
          if (_fileName == null) ...[const SizedBox(height: 12), _DField(icon: LucideIcons.link, label: 'OU URL DU FICHIER', hint: 'https://...', controller: _urlCtrl)],
        ])),
        Container(padding: const EdgeInsets.fromLTRB(20, 12, 20, 20), decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))), child: Row(children: [Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13), side: const BorderSide(color: Color(0xFFD1D5DB)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Annuler', style: TextStyle(color: kTextSub, fontWeight: FontWeight.w600)))), const SizedBox(width: 10), Expanded(child: ElevatedButton(onPressed: _submit, style: ElevatedButton.styleFrom(backgroundColor: kAccent, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Ajouter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))))])),
      ]))),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ONGLET ÉQUIPE
// ══════════════════════════════════════════════════════════════════════════════
class _EquipeTab extends StatefulWidget { final Project project; const _EquipeTab({required this.project}); @override State<_EquipeTab> createState() => _EquipeTabState(); }
class _EquipeTabState extends State<_EquipeTab> {
  List<Membre> membres = []; bool loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { try { final data = await ProjectMemberService.getMembres(widget.project.id); setState(() { membres = data; loading = false; }); } catch (e) { setState(() => loading = false); } }
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800; final pad = isMobile ? 16.0 : 28.0;
    if (loading) return const Center(child: CircularProgressIndicator(color: kAccent));
    return SingleChildScrollView(padding: EdgeInsets.all(pad), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Équipe du projet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kTextMain)),
      const SizedBox(height: 4),
      Text('Chef de projet : ${widget.project.chef}', style: const TextStyle(color: kTextSub, fontSize: 13)),
      const SizedBox(height: 20),
      if (membres.isEmpty) _EmptyState(icon: LucideIcons.users, message: 'Aucun membre assigné à ce projet')
      else LayoutBuilder(builder: (ctx, constraints) {
        final cols = constraints.maxWidth > 700 ? 3 : constraints.maxWidth > 450 ? 2 : 1; final rows = <Widget>[];
        for (int i = 0; i < membres.length; i += cols) { final row = membres.skip(i).take(cols).toList(); rows.add(IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (int j = 0; j < row.length; j++) ...[if (j > 0) const SizedBox(width: 14), Expanded(child: _MembreCard(membre: row[j]))], if (row.length < cols) ...[const SizedBox(width: 14), const Expanded(child: SizedBox())]]))); if (i + cols < membres.length) rows.add(const SizedBox(height: 14)); }
        return Column(children: rows);
      }),
    ]));
  }
}

class _MembreCard extends StatelessWidget {
  final Membre membre; const _MembreCard({required this.membre});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(22)), child: const Icon(LucideIcons.user, color: Color(0xFF3B82F6), size: 22)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(membre.nom, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kTextMain), overflow: TextOverflow.ellipsis), const SizedBox(height: 4), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFF374151), borderRadius: BorderRadius.circular(20)), child: Text(membre.role, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)))]))]),
    const SizedBox(height: 12), const Divider(height: 1, color: Color(0xFFF3F4F6)), const SizedBox(height: 10),
    Row(children: [const Icon(LucideIcons.mail, size: 13, color: kTextSub), const SizedBox(width: 6), Expanded(child: Text(membre.email, style: const TextStyle(color: kTextSub, fontSize: 12), overflow: TextOverflow.ellipsis))]),
    const SizedBox(height: 6),
    Row(children: [const Icon(LucideIcons.phone, size: 13, color: kTextSub), const SizedBox(width: 6), Text(membre.telephone, style: const TextStyle(color: kTextSub, fontSize: 12))]),
  ]));
}

// ══════════════════════════════════════════════════════════════════════════════
//  ONGLET SUIVI & PHOTOS — 3 sous-onglets
// ══════════════════════════════════════════════════════════════════════════════
class _SuiviPhotosTab extends StatefulWidget {
  final Project project;
  const _SuiviPhotosTab({required this.project});
  @override State<_SuiviPhotosTab> createState() => _SuiviPhotosTabState();
}

class _SuiviPhotosTabState extends State<_SuiviPhotosTab> {
  int _subTab = 0;

  final List<Map<String, dynamic>> _photos   = [];
  final List<Map<String, dynamic>> _reserves = [
    {'titre': 'Passage gaine technique manquant', 'date': '07/04/2026', 'statut': 'a_faire', 'x': 0.42, 'y': 0.55},
    {'titre': 'Défaut de finition sur le mur porteur', 'date': '06/04/2026', 'statut': 'a_faire', 'x': 0.70, 'y': 0.30},
  ];
  final List<Map<String, dynamic>> _crcs = [
    {'titre': 'Rapport de visite - Semaine 14', 'date': '6 avril 2026', 'auteur': 'Ahmed Bennani', 'statut': 'conforme'},
    {'titre': 'Rapport de visite - Semaine 13', 'date': '30 mars 2026', 'auteur': 'Ahmed Bennani', 'statut': 'attention'},
  ];
  final List<Map<String, dynamic>> _actualites = [
    {'type': 'Progrès', 'date': '5 avr.', 'contenu': 'Les fondations sont terminées dans les délais. Béton de bonne qualité.', 'auteur': 'Ahmed Bennani'},
  ];

  Future<void> _pickPhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true, withData: true);
      if (result != null && result.files.isNotEmpty) {
        setState(() { for (final f in result.files) { _photos.add({'name': f.name, 'bytes': f.bytes, 'date': DateTime.now().toString().substring(0, 10)}); } });
        _snack(context, '${result.files.length} photo(s) ajoutée(s)', kAccent);
      }
    } catch (e) { _snack(context, 'Impossible d\'ouvrir les photos', kRed); }
  }

  void _showAddReserveDialog(double rx, double ry) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 380), child: Column(mainAxisSize: MainAxisSize.min, children: [
        _DialogHeader(icon: LucideIcons.mapPin, title: 'Nouvelle réserve', subtitle: 'Décrivez le problème à corriger'),
        Padding(padding: const EdgeInsets.all(20), child: _DField(icon: LucideIcons.alertTriangle, label: 'DESCRIPTION *', hint: 'Ex: Fissure sur le mur nord', controller: ctrl, maxLines: 2)),
        _DialogActions(onCancel: () => Navigator.pop(context), onConfirm: () {
          final t = ctrl.text.trim(); if (t.isEmpty) { _snack(context, 'Description obligatoire', kRed); return; }
          setState(() { _reserves.add({'titre': t, 'date': DateTime.now().toString().substring(0, 10), 'statut': 'a_faire', 'x': rx, 'y': ry}); });
          Navigator.pop(context); _snack(context, 'Réserve ajoutée', kAccent);
        }, label: 'Ajouter'),
      ])),
    ));
  }

  void _showAddCrcDialog() {
    final titreCtrl = TextEditingController(); String statut = 'conforme';
    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (ctx, sd) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Column(mainAxisSize: MainAxisSize.min, children: [
        _DialogHeader(icon: LucideIcons.clipboardList, title: 'Nouveau CRC', subtitle: 'Compte-Rendu de Chantier'),
        Padding(padding: const EdgeInsets.all(20), child: Column(children: [
          _DField(icon: LucideIcons.fileText, label: 'TITRE *', hint: 'Rapport de visite - Semaine 15', controller: titreCtrl),
          const SizedBox(height: 14),
          const Align(alignment: Alignment.centerLeft, child: Text('STATUT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSub, letterSpacing: 0.5))),
          const SizedBox(height: 8),
          Row(children: [for (final s in ['conforme', 'attention', 'critique']) Expanded(child: Padding(padding: EdgeInsets.only(right: s == 'critique' ? 0 : 8), child: GestureDetector(onTap: () => sd(() => statut = s), child: AnimatedContainer(duration: const Duration(milliseconds: 150), padding: const EdgeInsets.symmetric(vertical: 9), decoration: BoxDecoration(color: statut == s ? _crcColor(s).withOpacity(0.12) : Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: statut == s ? _crcColor(s) : const Color(0xFFE5E7EB), width: statut == s ? 2 : 1)), child: Text(_crcLabel(s), textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: statut == s ? FontWeight.w700 : FontWeight.w500, color: statut == s ? _crcColor(s) : kTextSub))))))],
          ),
        ])),
        _DialogActions(onCancel: () => Navigator.pop(ctx), onConfirm: () {
          final t = titreCtrl.text.trim(); if (t.isEmpty) { _snack(ctx, 'Titre obligatoire', kRed); return; }
          final now = DateTime.now();
          setState(() { _crcs.insert(0, {'titre': t, 'date': '${now.day} ${_monthFr(now.month)} ${now.year}', 'auteur': widget.project.chef, 'statut': statut}); });
          Navigator.pop(ctx); _snack(context, 'CRC ajouté', kAccent);
        }, label: 'Créer'),
      ])),
    )));
  }

  static Color _crcColor(String s) { switch (s) { case 'conforme': return const Color(0xFF10B981); case 'attention': return const Color(0xFFF59E0B); default: return kRed; } }
  static String _crcLabel(String s) { switch (s) { case 'conforme': return 'Conforme'; case 'attention': return 'Attention'; default: return 'Critique'; } }
  static String _monthFr(int m) { const months = ['jan','fév','mars','avr','mai','juin','juil','août','sept','oct','nov','déc']; return months[m - 1]; }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final pad = isMobile ? 16.0 : 28.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(color: kCardBg, padding: EdgeInsets.fromLTRB(pad, 20, pad, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Suivi de chantier & Visites', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kTextMain)),
            SizedBox(height: 3),
            Text('Remarques sur plan, photos et comptes-rendus d\'exécution', style: TextStyle(color: kTextSub, fontSize: 12)),
          ])),
          if (_subTab == 2) ...[OutlinedButton.icon(onPressed: _showAddCrcDialog, icon: const Icon(LucideIcons.filePlus, size: 13), label: const Text('Nouveau compte-rendu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)), style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFD1D5DB)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))), const SizedBox(width: 8)],
          ElevatedButton.icon(onPressed: _pickPhoto, icon: const Icon(LucideIcons.camera, size: 14, color: Colors.white), label: const Text('Ajouter des photos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)), style: ElevatedButton.styleFrom(backgroundColor: kAccent, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
        ]),
        const SizedBox(height: 16),
        Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)), child: Row(children: [
          for (int i = 0; i < 3; i++) Expanded(child: GestureDetector(onTap: () => setState(() => _subTab = i), child: AnimatedContainer(duration: const Duration(milliseconds: 180), padding: const EdgeInsets.symmetric(vertical: 9), decoration: BoxDecoration(color: _subTab == i ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(9), boxShadow: _subTab == i ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 1))] : null), child: Text(['Pointage sur plan (Réserves)', 'Galerie Photos', 'Comptes-Rendus (CRC)'][i], textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: _subTab == i ? FontWeight.w700 : FontWeight.w500, color: _subTab == i ? kTextMain : kTextSub))))),
        ])),
        const SizedBox(height: 12),
      ])),
      Expanded(child: _buildSubTab(pad)),
    ]);
  }

  Widget _buildSubTab(double pad) { switch (_subTab) { case 0: return _buildPointage(pad); case 1: return _buildGalerie(pad); default: return _buildCRC(pad); } }

  Widget _buildPointage(double pad) {
    return SingleChildScrollView(padding: EdgeInsets.fromLTRB(pad, 16, pad, pad + 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kRed.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(LucideIcons.mapPin, size: 16, color: kRed)), const SizedBox(width: 12), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Inspection visuelle des défauts', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kTextMain)), SizedBox(height: 2), Text('Cliquez sur le plan pour ajouter rapidement une remarque ou lever une réserve.', style: TextStyle(color: kTextSub, fontSize: 11))]))]),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (ctx, constraints) {
          final planW = constraints.maxWidth < 600 ? constraints.maxWidth : constraints.maxWidth * 0.55;
          final listW = constraints.maxWidth - planW - 16;
          final isWide = constraints.maxWidth >= 600;
          return isWide ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: planW, child: _buildPlanWidget(planW)), const SizedBox(width: 16), SizedBox(width: listW, child: _buildReservesList())]) : Column(children: [_buildPlanWidget(planW), const SizedBox(height: 16), _buildReservesList()]);
        }),
      ])),
    ]));
  }

  Widget _buildPlanWidget(double planW) {
    final planH = planW * 0.75;
    return GestureDetector(
      onTapDown: (details) { final rx = details.localPosition.dx / planW; final ry = details.localPosition.dy / planH; _showAddReserveDialog(rx.clamp(0.0, 1.0), ry.clamp(0.0, 1.0)); },
      child: Stack(children: [
        Container(width: planW, height: planH, decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE5E7EB))), child: ClipRRect(borderRadius: BorderRadius.circular(10), child: CustomPaint(painter: _FloorPlanPainter(), size: Size(planW, planH)))),
        ..._reserves.asMap().entries.map((e) { final i = e.key; final r = e.value; final x = (r['x'] as double) * planW; final y = (r['y'] as double) * planH; return Positioned(left: x - 14, top: y - 14, child: GestureDetector(onTap: () => _snack(context, r['titre'], kRed), child: Container(width: 28, height: 28, decoration: BoxDecoration(color: kRed, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: [BoxShadow(color: kRed.withOpacity(0.4), blurRadius: 6)]), child: Center(child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)))))); }),
        Positioned(bottom: 8, left: 0, right: 0, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(20)), child: const Text('Tap pour pointer une réserve', style: TextStyle(color: Colors.white, fontSize: 10))))),
      ]),
    );
  }

  Widget _buildReservesList() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('LISTE DES RÉSERVES (${_reserves.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSub, letterSpacing: 0.5)),
      const SizedBox(height: 10),
      if (_reserves.isEmpty) Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE5E7EB))), child: const Center(child: Text('Aucune réserve — cliquez sur le plan', style: TextStyle(color: kTextSub, fontSize: 12))))
      else ..._reserves.asMap().entries.map((e) {
        final i = e.key; final r = e.value; final estFait = r['statut'] == 'regle';
        return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: estFait ? const Color(0xFF10B981).withOpacity(0.3) : const Color(0xFFE5E7EB))), child: Row(children: [
          Container(width: 24, height: 24, decoration: BoxDecoration(color: estFait ? const Color(0xFF10B981) : kRed, shape: BoxShape.circle), child: Center(child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r['titre'], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: estFait ? kTextSub : kTextMain, decoration: estFait ? TextDecoration.lineThrough : null)), const SizedBox(height: 2), Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: estFait ? const Color(0xFF10B981).withOpacity(0.1) : kRed.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(estFait ? 'Réglé' : 'À faire', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: estFait ? const Color(0xFF10B981) : kRed))), const SizedBox(width: 6), Text(r['date'], style: const TextStyle(fontSize: 10, color: kTextSub))])])),
          GestureDetector(onTap: () => setState(() => _reserves[i]['statut'] = estFait ? 'a_faire' : 'regle'), child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(estFait ? LucideIcons.rotateCcw : LucideIcons.checkCircle, size: 11, color: const Color(0xFF10B981)), const SizedBox(width: 4), Text(estFait ? 'Annuler' : 'Marquer réglé', style: const TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.w600))]))),
        ]));
      }),
    ]);
  }

  Widget _buildGalerie(double pad) {
    return SingleChildScrollView(padding: EdgeInsets.fromLTRB(pad, 16, pad, pad + 20), child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Text('Galerie du chantier', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextMain)), const Spacer(), ElevatedButton.icon(onPressed: _pickPhoto, icon: const Icon(LucideIcons.camera, size: 13, color: Colors.white), label: const Text('Photos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)), style: ElevatedButton.styleFrom(backgroundColor: kAccent, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))))]),
      const SizedBox(height: 16),
      if (_photos.isEmpty) Container(padding: const EdgeInsets.symmetric(vertical: 50), child: Column(children: [Container(width: 60, height: 60, decoration: BoxDecoration(color: kAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(14)), child: Icon(LucideIcons.image, size: 26, color: kAccent.withOpacity(0.5))), const SizedBox(height: 14), const Text('Aucune photo', style: TextStyle(color: kTextMain, fontSize: 13, fontWeight: FontWeight.w600)), const SizedBox(height: 4), const Text('Cliquez sur "Photos" pour ajouter des images du chantier', style: TextStyle(color: kTextSub, fontSize: 12))]))
      else LayoutBuilder(builder: (ctx, cs) {
        final cols = cs.maxWidth > 600 ? 3 : 2; final rows = <Widget>[];
        for (int i = 0; i < _photos.length; i += cols) { final rowItems = _photos.skip(i).take(cols).toList(); rows.add(Row(children: [for (int j = 0; j < rowItems.length; j++) ...[if (j > 0) const SizedBox(width: 10), Expanded(child: _PhotoCard(photo: rowItems[j], onDelete: () => setState(() => _photos.removeAt(i + j))))], if (rowItems.length < cols) ...[const SizedBox(width: 10), const Expanded(child: SizedBox())]])); if (i + cols < _photos.length) rows.add(const SizedBox(height: 10)); }
        return Column(children: rows);
      }),
    ])));
  }

  Widget _buildCRC(double pad) {
    return SingleChildScrollView(padding: EdgeInsets.fromLTRB(pad, 16, pad, pad + 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Text('Comptes-Rendus de Chantier (CRC)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextMain)), const Spacer(), OutlinedButton.icon(onPressed: _showAddCrcDialog, icon: const Icon(LucideIcons.filePlus, size: 13), label: const Text('Nouveau CRC', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)), style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFD1D5DB)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))))]),
        const SizedBox(height: 16),
        if (_crcs.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('Aucun compte-rendu', style: TextStyle(color: kTextSub, fontSize: 13))))
        else ..._crcs.map((crc) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))), child: Row(children: [Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)), child: const Icon(LucideIcons.fileText, size: 16, color: Color(0xFF3B82F6))), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(crc['titre'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextMain)), const SizedBox(height: 3), Text('${crc['date']}  •  Par ${crc['auteur']}', style: const TextStyle(fontSize: 11, color: kTextSub))])), const SizedBox(width: 10), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: _crcColor(crc['statut']), borderRadius: BorderRadius.circular(20)), child: Text(_crcLabel(crc['statut']), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)))]))),
      ])),
      const SizedBox(height: 20),
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Text("Fil d'actualité du chantier", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextMain)), const Spacer(), GestureDetector(onTap: () => _showAddActualiteDialog(), child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: kAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(LucideIcons.plus, size: 16, color: kAccent)))]),
        const SizedBox(height: 16),
        if (_actualites.isEmpty) const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('Aucune actualité', style: TextStyle(color: kTextSub, fontSize: 13))))
        else ..._actualites.asMap().entries.map((e) {
          final i = e.key; final a = e.value; final isLast = i == _actualites.length - 1;
          return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [Container(width: 12, height: 12, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)), if (!isLast) Expanded(child: Container(width: 2, color: const Color(0xFFE5E7EB)))]),
            const SizedBox(width: 14),
            Expanded(child: Padding(padding: EdgeInsets.only(bottom: isLast ? 0 : 16), child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE5E7EB))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: kAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(a['type'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kAccent))), const Spacer(), Text(a['date'], style: const TextStyle(fontSize: 11, color: kTextSub))]), const SizedBox(height: 8), Text(a['contenu'], style: const TextStyle(fontSize: 13, color: kTextMain, height: 1.4)), const SizedBox(height: 6), Text('Par ${a['auteur']}', style: const TextStyle(fontSize: 11, color: kAccent, fontWeight: FontWeight.w600))]))),
        )]));
        }),
      ])),
    ]));
  }

  void _showAddActualiteDialog() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (_) => Dialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 400), child: Column(mainAxisSize: MainAxisSize.min, children: [
      _DialogHeader(icon: LucideIcons.rss, title: 'Nouvelle actualité', subtitle: 'Ajoutez une note au fil de chantier'),
      Padding(padding: const EdgeInsets.all(20), child: _DField(icon: LucideIcons.messageSquare, label: 'CONTENU *', hint: 'Ex: Les fondations sont terminées...', controller: ctrl, maxLines: 3)),
      _DialogActions(onCancel: () => Navigator.pop(context), onConfirm: () {
        final t = ctrl.text.trim(); if (t.isEmpty) { _snack(context, 'Contenu obligatoire', kRed); return; }
        final now = DateTime.now();
        setState(() { _actualites.insert(0, {'type': 'Progrès', 'date': '${now.day} ${_monthFr(now.month)}.', 'contenu': t, 'auteur': widget.project.chef}); });
        Navigator.pop(context); _snack(context, 'Actualité ajoutée', kAccent);
      }, label: 'Publier'),
    ]))));
  }
}

class _FloorPlanPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF374151)..strokeWidth = 2..style = PaintingStyle.stroke;
    final fill  = Paint()..color = const Color(0xFFE5E7EB)..style = PaintingStyle.fill;
    final w = size.width; final h = size.height;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFFF9FAFB));
    final outer = RRect.fromRectAndRadius(Rect.fromLTRB(w * 0.08, h * 0.08, w * 0.92, h * 0.92), const Radius.circular(4));
    canvas.drawRRect(outer, fill); canvas.drawRRect(outer, paint);
    canvas.drawRect(Rect.fromLTRB(w * 0.10, h * 0.10, w * 0.55, h * 0.90), paint);
    canvas.drawRect(Rect.fromLTRB(w * 0.55, h * 0.10, w * 0.90, h * 0.55), paint);
    canvas.drawRect(Rect.fromLTRB(w * 0.55, h * 0.55, w * 0.90, h * 0.90), paint);
    final doorPaint = Paint()..color = const Color(0xFF6B7280)..strokeWidth = 1.5..style = PaintingStyle.stroke;
    canvas.drawArc(Rect.fromCircle(center: Offset(w * 0.55, h * 0.38), radius: h * 0.12), -1.57, 1.57, false, doorPaint);
    canvas.drawLine(Offset(w * 0.55, h * 0.38), Offset(w * 0.55, h * 0.38 - h * 0.12), doorPaint);
    final winPaint = Paint()..color = const Color(0xFF93C5FD)..strokeWidth = 3..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w * 0.65, h * 0.10), Offset(w * 0.80, h * 0.10), winPaint);
    final sanPaint = Paint()..color = const Color(0xFF9CA3AF)..strokeWidth = 1..style = PaintingStyle.stroke;
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.73, h * 0.78), width: w * 0.10, height: h * 0.15), sanPaint);
  }
  @override bool shouldRepaint(_) => false;
}

class _PhotoCard extends StatelessWidget {
  final Map<String, dynamic> photo; final VoidCallback onDelete;
  const _PhotoCard({required this.photo, required this.onDelete});
  @override
  Widget build(BuildContext context) => Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]), clipBehavior: Clip.hardEdge, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    AspectRatio(aspectRatio: 4 / 3, child: photo['bytes'] != null ? Image.memory(photo['bytes'], fit: BoxFit.cover) : Container(color: const Color(0xFFF3F4F6), child: const Icon(LucideIcons.image, size: 32, color: kTextSub))),
    Padding(padding: const EdgeInsets.all(10), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(photo['name'] ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kTextMain), overflow: TextOverflow.ellipsis), const SizedBox(height: 2), Text(photo['date'] ?? '', style: const TextStyle(fontSize: 10, color: kTextSub))])), GestureDetector(onTap: onDelete, child: Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(6)), child: const Icon(LucideIcons.trash2, size: 12, color: kRed)))])),
  ]));
}

// ══════════════════════════════════════════════════════════════════════════════
//  ONGLET MODÈLE 3D
// ══════════════════════════════════════════════════════════════════════════════
class _Modele3DTab extends StatefulWidget {
  final Project project;
  const _Modele3DTab({required this.project});
  @override State<_Modele3DTab> createState() => _Modele3DTabState();
}
class _Modele3DTabState extends State<_Modele3DTab> {
  final _urlCtrl = TextEditingController();
  String? _savedUrl; bool _showForm = false;
  @override void dispose() { _urlCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800; final pad = isMobile ? 16.0 : 28.0;
    return SingleChildScrollView(padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Modèle 3D', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kTextMain)), SizedBox(height: 4), Text('Intégrez un lien vers votre maquette numérique BIM.', style: TextStyle(color: kTextSub, fontSize: 12))])), if (!_showForm) ElevatedButton.icon(onPressed: () => setState(() => _showForm = true), icon: const Icon(LucideIcons.link, size: 14, color: Colors.white), label: Text(isMobile ? 'Lien' : 'Ajouter un lien', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)), style: ElevatedButton.styleFrom(backgroundColor: kAccent, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))))]),
      const SizedBox(height: 24),
      if (_showForm) ...[
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('LIEN DU MODÈLE 3D', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSub, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          const Text('Formats supportés : Sketchfab, Autodesk Viewer, BIM 360, Speckle, ou tout lien iframe.', style: TextStyle(color: kTextSub, fontSize: 12)),
          const SizedBox(height: 12),
          TextField(controller: _urlCtrl, decoration: InputDecoration(hintText: 'https://sketchfab.com/models/...', prefixIcon: const Icon(LucideIcons.link, size: 14, color: kTextSub), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kAccent, width: 2)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12))),
          const SizedBox(height: 12),
          Row(children: [Expanded(child: OutlinedButton(onPressed: () => setState(() { _showForm = false; _urlCtrl.clear(); }), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), side: const BorderSide(color: Color(0xFFD1D5DB)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('Annuler', style: TextStyle(color: kTextSub)))), const SizedBox(width: 10), Expanded(child: ElevatedButton(onPressed: () { final url = _urlCtrl.text.trim(); if (url.isEmpty) { _snack(context, 'URL obligatoire', kRed); return; } setState(() { _savedUrl = url; _showForm = false; }); _snack(context, 'Lien enregistré', kAccent); }, style: ElevatedButton.styleFrom(backgroundColor: kAccent, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('Enregistrer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))))]),
        ])),
        const SizedBox(height: 20),
      ],
      if (_savedUrl != null)
        Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]), child: Column(children: [
          Container(padding: const EdgeInsets.fromLTRB(16, 14, 16, 14), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))), child: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(LucideIcons.box, size: 16, color: kAccent)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Maquette numérique', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kTextMain)), Text(_savedUrl!, style: const TextStyle(color: kTextSub, fontSize: 11), overflow: TextOverflow.ellipsis)])), Row(children: [GestureDetector(onTap: () async { final uri = Uri.tryParse(_savedUrl!); if (uri != null) try { await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (_) {} }, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)), child: const Icon(LucideIcons.externalLink, size: 16, color: Color(0xFF3B82F6)))), const SizedBox(width: 8), GestureDetector(onTap: () => setState(() { _savedUrl = null; _urlCtrl.clear(); }), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)), child: const Icon(LucideIcons.trash2, size: 16, color: kRed)))])])),
          Container(height: 280, width: double.infinity, decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16))), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(LucideIcons.box, size: 40, color: Colors.white70)), const SizedBox(height: 16), const Text('Cliquez sur "Ouvrir" pour visualiser le modèle', style: TextStyle(color: Colors.white70, fontSize: 14)), const SizedBox(height: 8), const Text('Le viewer 3D s\'ouvrira dans votre navigateur', style: TextStyle(color: Colors.white38, fontSize: 12)), const SizedBox(height: 20), OutlinedButton.icon(onPressed: () async { final uri = Uri.tryParse(_savedUrl!); if (uri != null) try { await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (_) {} }, icon: const Icon(LucideIcons.externalLink, size: 14, color: Colors.white), label: const Text('Ouvrir le modèle 3D', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white38), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))))])),
        ]))
      else if (!_showForm)
        Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))), child: Column(children: [Container(width: 64, height: 64, decoration: BoxDecoration(color: kAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(16)), child: Icon(LucideIcons.box, size: 28, color: kAccent.withOpacity(0.6))), const SizedBox(height: 16), const Text('Aucun modèle 3D pour ce projet', style: TextStyle(color: kTextMain, fontSize: 14, fontWeight: FontWeight.w600)), const SizedBox(height: 6), const Text('Ajoutez un lien vers votre maquette BIM ou modèle Sketchfab', style: TextStyle(color: kTextSub, fontSize: 12), textAlign: TextAlign.center), const SizedBox(height: 20), OutlinedButton.icon(onPressed: () => setState(() => _showForm = true), icon: const Icon(LucideIcons.link, size: 14, color: kAccent), label: const Text('Ajouter un lien 3D', style: TextStyle(color: kAccent, fontWeight: FontWeight.w600, fontSize: 13)), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), side: const BorderSide(color: kAccent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))))]),
          ),  const SizedBox(height: 20),
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Formats & Plateformes supportés', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: kTextMain)), const SizedBox(height: 12), Wrap(spacing: 8, runSpacing: 8, children: [for (final p in ['Sketchfab', 'Autodesk BIM 360', 'Speckle', 'Trimble Connect', 'Archicad BIMx', 'Autre lien iframe']) Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5E7EB))), child: Text(p, style: const TextStyle(fontSize: 12, color: kTextSub)))])])),
    ]));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ONGLET COMMENTAIRES
// ══════════════════════════════════════════════════════════════════════════════
class _CommentairesTab extends StatefulWidget {
  final Project project;
  final void Function(int count) onCountChanged;
  const _CommentairesTab({required this.project, required this.onCountChanged});
  @override State<_CommentairesTab> createState() => _CommentairesTabState();
}
class _CommentairesTabState extends State<_CommentairesTab> {
  List<Commentaire> commentaires = []; bool loading = true;
  final _ctrl = TextEditingController(); final _scroll = ScrollController();
  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _ctrl.dispose(); _scroll.dispose(); super.dispose(); }
  Future<void> _load() async {
    try {
      final data = await CommentaireService.getCommentaires(widget.project.id);
      setState(() { commentaires = data; loading = false; });
      widget.onCountChanged(data.length);
      Future.delayed(const Duration(milliseconds: 100), () { if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent); });
    } catch (e) { setState(() => loading = false); }
  }
  Future<void> _send() async {
    final text = _ctrl.text.trim(); if (text.isEmpty) { _snack(context, 'Message vide', kRed); return; }
    _ctrl.clear();
    await CommentaireService.addCommentaire(Commentaire(id: '', projetId: widget.project.id, auteur: widget.project.chef.isEmpty ? 'Architecte' : widget.project.chef, role: 'architecte', contenu: text, createdAt: DateTime.now().toIso8601String()));
    _load();
  }
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800; final pad = isMobile ? 16.0 : 28.0;
    if (loading) return const Center(child: CircularProgressIndicator(color: kAccent));
    return Padding(padding: EdgeInsets.all(pad), child: Column(children: [
      Expanded(child: Container(decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]), child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 10), child: Row(children: [const Icon(LucideIcons.messageSquare, size: 16, color: kTextSub), const SizedBox(width: 8), const Text('Fil de discussion', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: kTextMain)), const Spacer(), Text('${commentaires.length} message(s)', style: const TextStyle(color: kTextSub, fontSize: 12))])),
        const Divider(height: 1, color: Color(0xFFF3F4F6)),
        Expanded(child: commentaires.isEmpty ? _EmptyState(icon: LucideIcons.messageCircle, message: 'Aucun message') : ListView.builder(controller: _scroll, padding: const EdgeInsets.all(16), itemCount: commentaires.length, itemBuilder: (_, i) => _BubbleRow(commentaire: commentaires[i]))),
      ]))),
      const SizedBox(height: 12),
      Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))), child: Row(children: [Expanded(child: TextField(controller: _ctrl, onSubmitted: (_) => _send(), style: const TextStyle(fontSize: 13, color: kTextMain), decoration: const InputDecoration(hintText: 'Écrire un commentaire...', hintStyle: TextStyle(color: kTextSub), border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero))), GestureDetector(onTap: _send, child: Container(width: 36, height: 36, decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.send_rounded, color: Colors.white, size: 16)))])),
    ]));
  }
}

class _BubbleRow extends StatelessWidget {
  final Commentaire commentaire; const _BubbleRow({required this.commentaire});
  @override
  Widget build(BuildContext context) {
    final isArchi = commentaire.role == 'architecte';
    return Padding(padding: const EdgeInsets.only(bottom: 14), child: Column(crossAxisAlignment: isArchi ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: isArchi ? MainAxisAlignment.end : MainAxisAlignment.start, children: [Text(commentaire.auteur, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: kTextMain)), const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(4)), child: Text(isArchi ? 'ARCHITECTE' : 'CLIENT', style: const TextStyle(color: kTextSub, fontSize: 9, fontWeight: FontWeight.w700))), const SizedBox(width: 6), Text(commentaire.createdAt.length > 10 ? commentaire.createdAt.substring(0, 10) : commentaire.createdAt, style: const TextStyle(color: kTextSub, fontSize: 10))]),
      const SizedBox(height: 5),
      Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: isArchi ? kAccent : const Color(0xFFF3F4F6), borderRadius: BorderRadius.only(topLeft: const Radius.circular(14), topRight: const Radius.circular(14), bottomLeft: Radius.circular(isArchi ? 14 : 0), bottomRight: Radius.circular(isArchi ? 0 : 14))), child: Text(commentaire.contenu, style: TextStyle(color: isArchi ? Colors.white : kTextMain, fontSize: 13, height: 1.4))),
    ]));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  WIDGETS COMMUNS
// ══════════════════════════════════════════════════════════════════════════════
class _StatusBadge extends StatelessWidget {
  final String label; final Color color;
  const _StatusBadge({required this.label, required this.color});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)), child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)));
}
class _AccessToggle extends StatefulWidget { @override State<_AccessToggle> createState() => _AccessToggleState(); }
class _AccessToggleState extends State<_AccessToggle> {
  bool _value = true;
  @override Widget build(BuildContext context) => Material(color: Colors.transparent, child: Row(mainAxisSize: MainAxisSize.min, children: [Transform.scale(scale: 0.85, child: Switch(value: _value, onChanged: (v) => setState(() => _value = v), activeColor: kAccent)), const Text('Portail client', style: TextStyle(color: kTextSub, fontSize: 12))]));
}
class _KpiCard extends StatelessWidget {
  final String label, value; final Color color; final IconData icon;
  const _KpiCard({required this.label, required this.value, required this.color, required this.icon});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 16)), const SizedBox(height: 8), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: kTextMain))), const SizedBox(height: 2), Text(label, style: const TextStyle(color: kTextSub, fontSize: 11), overflow: TextOverflow.ellipsis)]));
}
class _EmptyState extends StatelessWidget {
  final IconData icon; final String message;
  const _EmptyState({required this.icon, required this.message});
  @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 30), child: Column(children: [Icon(icon, size: 40, color: kTextSub.withOpacity(0.4)), const SizedBox(height: 12), Text(message, style: TextStyle(color: kTextSub.withOpacity(0.7), fontSize: 14))])));
}
class _ViewInfoTile extends StatelessWidget {
  final IconData icon; final String label, value;
  const _ViewInfoTile({required this.icon, required this.label, required this.value});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE5E7EB))), child: Row(children: [Icon(icon, size: 14, color: kTextSub), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 10, color: kTextSub)), const SizedBox(height: 2), Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextMain))]))]));
}
class _ViewToggleBtn extends StatelessWidget {
  final String label; final IconData icon; final bool active; final VoidCallback onTap;
  const _ViewToggleBtn({required this.label, required this.icon, required this.active, required this.onTap});
  @override Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: AnimatedContainer(duration: const Duration(milliseconds: 150), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: active ? kAccent : Colors.transparent, borderRadius: BorderRadius.circular(6)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: active ? Colors.white : kTextSub), const SizedBox(width: 5), Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? Colors.white : kTextSub))])));
}
class _ProgressionCard extends StatelessWidget {
  final int total, terminees, enCours, enAttente; final double progression;
  const _ProgressionCard({required this.total, required this.terminees, required this.enCours, required this.enAttente, required this.progression});
  @override
  Widget build(BuildContext context) {
    final pct = (progression * 100).round(); Color barColor = kAccent;
    if (pct == 100) barColor = const Color(0xFF10B981); else if (pct >= 70) barColor = const Color(0xFF3B82F6);
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: LinearGradient(colors: [barColor.withOpacity(0.08), barColor.withOpacity(0.03)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(14), border: Border.all(color: barColor.withOpacity(0.2))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: barColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Icon(LucideIcons.target, color: barColor, size: 18)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Progression des tâches', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kTextMain)), Text(total == 0 ? 'Aucune tâche' : '$terminees tâche(s) terminée(s) sur $total', style: const TextStyle(color: kTextSub, fontSize: 12))])), Text('$pct%', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: barColor))]), const SizedBox(height: 14), ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: progression, minHeight: 10, backgroundColor: barColor.withOpacity(0.15), valueColor: AlwaysStoppedAnimation<Color>(barColor))), const SizedBox(height: 12), Row(children: [_LegDot(color: const Color(0xFF10B981), label: 'Terminées ($terminees)'), const SizedBox(width: 16), _LegDot(color: const Color(0xFF3B82F6), label: 'En cours ($enCours)'), const SizedBox(width: 16), _LegDot(color: const Color(0xFF9CA3AF), label: 'Planifiées ($enAttente)')])]));
  }
}
class _LegDot extends StatelessWidget {
  final Color color; final String label; const _LegDot({required this.color, required this.label});
  @override Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 5), Text(label, style: const TextStyle(fontSize: 11, color: kTextSub))]);
}
class _DialogHeader extends StatelessWidget {
  final IconData icon; final String title, subtitle;
  const _DialogHeader({required this.icon, required this.title, required this.subtitle});
  @override Widget build(BuildContext context) => Container(decoration: BoxDecoration(color: kAccent.withOpacity(0.08), borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), border: Border(bottom: BorderSide(color: kAccent.withOpacity(0.15)))), padding: const EdgeInsets.fromLTRB(20, 18, 20, 16), child: Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: kAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: kAccent, size: 20)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kAccent)), const SizedBox(height: 2), Text(subtitle, style: const TextStyle(color: kTextSub, fontSize: 12))]))]));
}
class _DialogActions extends StatelessWidget {
  final VoidCallback onCancel, onConfirm; final String label;
  const _DialogActions({required this.onCancel, required this.onConfirm, required this.label});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.fromLTRB(20, 14, 20, 20), decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))), child: Row(children: [Expanded(child: OutlinedButton(onPressed: onCancel, style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13), side: const BorderSide(color: Color(0xFFD1D5DB)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Annuler', style: TextStyle(color: kTextSub, fontWeight: FontWeight.w600)))), const SizedBox(width: 10), Expanded(child: ElevatedButton(onPressed: onConfirm, style: ElevatedButton.styleFrom(backgroundColor: kAccent, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))))]));
}
class _DField extends StatelessWidget {
  final IconData icon; final String label, hint; final TextEditingController controller; final TextInputType keyboardType; final int maxLines;
  const _DField({required this.icon, required this.label, required this.hint, required this.controller, this.keyboardType = TextInputType.text, this.maxLines = 1});
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSub, letterSpacing: 0.5)), const SizedBox(height: 6), TextField(controller: controller, keyboardType: keyboardType, maxLines: maxLines, style: const TextStyle(fontSize: 13, color: kTextMain), decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: kTextSub), prefixIcon: maxLines == 1 ? Icon(icon, size: 14, color: kTextSub) : null, isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: maxLines > 1 ? 14 : 10, vertical: maxLines > 1 ? 12 : 11), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kAccent, width: 2))))]);
}