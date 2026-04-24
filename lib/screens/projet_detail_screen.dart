import 'dart:async';
import 'dart:convert';
import 'package:archi_manager/models/notification.dart';
import 'package:file_picker/file_picker.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
import '../service/membre_service.dart';
import '../service/auth_service.dart';
import '../service/model3d_service.dart';
import '../models/model3d.dart';
import '../utils/glb_parser.dart';
import '../widgets/sidebar_widget.dart';


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
    final _docSep = d.nom.contains('||META||') ? '||META||' : '\x00';
    if (d.nom.contains('||META||') || d.nom.contains('\x00')) {
      final parts = d.nom.split(_docSep);
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
      '$nomAffiche||META||$phase||META||$typeLabel||META||$version||META||${dateDoc ?? ''}';
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
  late Project _project;
  bool _updatingStatut = false;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _tabController = TabController(length: _tabCount, vsync: this);
    _loadCommentCount();
  }

  Color get _statusColor {
    switch (_project.statut) {
      case 'en_cours': return kAccent;
      case 'termine':  return const Color(0xFF10B981);
      case 'annule':   return kRed;
      default:         return const Color(0xFF9CA3AF);
    }
  }

  Future<void> _terminerProjet() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(LucideIcons.checkCircle, color: Color(0xFF10B981), size: 20),
          SizedBox(width: 10),
          Text('Terminer le projet ?'),
        ]),
        content: Text('Le projet "${_project.titre}" sera marqué comme terminé.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Terminer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _updatingStatut = true);
    try {
      await ProjetService.updateStatutProjet(_project.id, 'termine');
      setState(() { _project = Project(id: _project.id, clientId: _project.clientId, titre: _project.titre, description: _project.description, statut: 'termine', avancement: 100, dateDebut: _project.dateDebut, dateFin: _project.dateFin, budgetTotal: _project.budgetTotal, budgetDepense: _project.budgetDepense, client: _project.client, localisation: _project.localisation, chef: _project.chef, taches: _project.taches, membres: _project.membres, docs: _project.docs, portailClient: _project.portailClient); });
      _snack(context, '✓ Projet marqué comme terminé', const Color(0xFF10B981));
    } catch (e) {
      _snack(context, 'Erreur : $e', kRed);
    } finally {
      if (mounted) setState(() => _updatingStatut = false);
    }
  }

  Future<void> _annulerProjet() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(LucideIcons.xCircle, color: kRed, size: 20),
          SizedBox(width: 10),
          Text('Annuler le projet ?'),
        ]),
        content: Text('Le projet "${_project.titre}" sera marqué comme annulé. Cette action est réversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Retour')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kRed, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Annuler le projet', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _updatingStatut = true);
    try {
      await ProjetService.updateStatutProjet(_project.id, 'annule');
      setState(() { _project = Project(id: _project.id, clientId: _project.clientId, titre: _project.titre, description: _project.description, statut: 'annule', avancement: _project.avancement, dateDebut: _project.dateDebut, dateFin: _project.dateFin, budgetTotal: _project.budgetTotal, budgetDepense: _project.budgetDepense, client: _project.client, localisation: _project.localisation, chef: _project.chef, taches: _project.taches, membres: _project.membres, docs: _project.docs, portailClient: _project.portailClient); });
      _snack(context, 'Projet annulé', kRed);
    } catch (e) {
      _snack(context, 'Erreur : $e', kRed);
    } finally {
      if (mounted) setState(() => _updatingStatut = false);
    }
  }

  Future<void> _togglePortailClient(bool value) async {
    setState(() { _project = Project(id: _project.id, clientId: _project.clientId, titre: _project.titre, description: _project.description, statut: _project.statut, avancement: _project.avancement, dateDebut: _project.dateDebut, dateFin: _project.dateFin, budgetTotal: _project.budgetTotal, budgetDepense: _project.budgetDepense, client: _project.client, localisation: _project.localisation, chef: _project.chef, taches: _project.taches, membres: _project.membres, docs: _project.docs, portailClient: value); });
    try {
      await ProjetService.updatePortailClient(_project.id, value);
      _snack(context, value ? '✓ Portail client activé' : 'Portail client désactivé', value ? const Color(0xFF10B981) : kTextSub);
    } catch (e) {
      setState(() { _project = Project(id: _project.id, clientId: _project.clientId, titre: _project.titre, description: _project.description, statut: _project.statut, avancement: _project.avancement, dateDebut: _project.dateDebut, dateFin: _project.dateFin, budgetTotal: _project.budgetTotal, budgetDepense: _project.budgetDepense, client: _project.client, localisation: _project.localisation, chef: _project.chef, taches: _project.taches, membres: _project.membres, docs: _project.docs, portailClient: !value); });
      _snack(context, 'Erreur : $e', kRed);
    }
  }

  String _fmt(double v) {
    if (v == 0) return '0 DT';
    final s = v.toInt().toString(); final buf = StringBuffer(); int c = 0;
    for (int i = s.length - 1; i >= 0; i--) { if (c > 0 && c % 3 == 0) buf.write('.'); buf.write(s[i]); c++; }
    return '${buf.toString().split('').reversed.join()} DT';
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

    final content = Scaffold(
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

    if (isMobile) return content;

    return Scaffold(
      backgroundColor: kBg,
      body: Row(children: [
        SidebarWidget(
          selectedIndex: 1,
          onSelect: (_) => Navigator.of(context).pop(),
          notifCount: 0,
          architecteNom: AuthService.currentUser?.fullName ?? 'Architecte',
          onLogout: () async {
            await AuthService.logout();
            if (!mounted) return;
            Navigator.pushReplacementNamed(context, '/login');
          },
        ),
        Expanded(child: content),
      ]),
    );
  }

  Widget _buildDesktopHeader(Project p) => Row(children: [
    Expanded(child: Row(children: [
      Flexible(child: Text(p.titre, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kTextMain))),
      const SizedBox(width: 10),
      _StatusBadge(label: p.status, color: _statusColor),
    ])),
    Material(color: Colors.transparent, child: Row(children: [
      _AccessToggle(
        value: _project.portailClient,
        onChanged: _updatingStatut ? null : _togglePortailClient,
      ),
      const SizedBox(width: 10),
      if (_project.statut != 'termine') ...[
        _updatingStatut
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)))
          : OutlinedButton.icon(
              onPressed: _terminerProjet,
              icon: const Icon(LucideIcons.checkCircle, size: 13, color: Color(0xFF10B981)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF10B981)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              label: const Text('Terminer', style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w600)),
            ),
        const SizedBox(width: 8),
      ],
      if (_project.statut != 'annule')
        OutlinedButton.icon(
          onPressed: _updatingStatut ? null : _annulerProjet,
          icon: const Icon(LucideIcons.xCircle, size: 13, color: kRed),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: kRed), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          label: const Text('Annuler', style: TextStyle(color: kRed, fontSize: 12)),
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
    _AccessToggle(
      value: _project.portailClient,
      onChanged: _updatingStatut ? null : _togglePortailClient,
    ),
    PopupMenuButton<String>(
      icon: const Icon(LucideIcons.moreVertical, size: 18, color: kTextSub),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) { if (v == 'terminer') _terminerProjet(); else if (v == 'annuler') _annulerProjet(); },
      itemBuilder: (_) => [
        if (_project.statut != 'termine') const PopupMenuItem(value: 'terminer', child: Row(children: [Icon(LucideIcons.checkCircle, size: 14, color: Color(0xFF10B981)), SizedBox(width: 8), Text('Terminer', style: TextStyle(color: Color(0xFF10B981)))])),
        if (_project.statut != 'annule')  const PopupMenuItem(value: 'annuler',  child: Row(children: [Icon(LucideIcons.xCircle,    size: 14, color: kRed),               SizedBox(width: 8), Text('Annuler',  style: TextStyle(color: kRed))])),
      ],
    ),
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
  Model3D? _model3D;
  bool loading    = true;
  bool _showGantt = false;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        TacheService.getTaches(widget.project.id),
        PhaseService.getPhases(widget.project.id),
        Model3DService.getModel(widget.project.id).catchError((_) => null),
      ]);
      setState(() {
        taches  = results[0] as List<Tache>;
        phases  = results[1] as List<Phase>;
        _model3D = results[2] as Model3D?;
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
    String  statut      = existing?.statut ?? 'en_attente';
    String? phaseId     = existing?.phaseId ?? preselectedPhaseId;
    final isEdit        = existing != null;
    final hasMesh       = _model3D != null && _model3D!.meshNames.isNotEmpty;

    // Mesh selection state
    final selectedMeshes = Set<String>.from(existing?.meshNames ?? []);

    // Mini 3D viewer controller (only if model available)
    WebViewController? viewerCtrl;
    Timer? _pollTimer;

    if (hasMesh) {
      viewerCtrl = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..addJavaScriptChannel('FlutterChannel', onMessageReceived: (_) {})
        ..loadHtmlString(_buildViewerHtml(_model3D!.url));
    }

    void highlightSelected(void Function(void Function()) sd) {
      if (viewerCtrl == null) return;
      final namesJson = jsonEncode(selectedMeshes.toList());
      viewerCtrl!.runJavaScript('highlightMeshes($namesJson);');
    }

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
      // Poll viewer for mesh clicks (works on web where JS channels are limited)
      _pollTimer ??= Timer.periodic(const Duration(milliseconds: 600), (_) async {
        if (viewerCtrl == null) return;
        try {
          final res = await viewerCtrl!.runJavaScriptReturningResult(
            'JSON.stringify(window._pendingClicks||[])',
          );
          final raw = res is String ? res : res.toString();
          final clicks = jsonDecode(raw.replaceAll('"', '"').replaceAll('"', '"')) as List;
          if (clicks.isNotEmpty) {
            await viewerCtrl!.runJavaScript('window._pendingClicks=[];');
            for (final name in clicks) {
              final meshName = name.toString();
              sd(() {
                if (selectedMeshes.contains(meshName)) selectedMeshes.remove(meshName);
                else selectedMeshes.add(meshName);
              });
              highlightSelected(sd);
              // Confirmation popup
              if (ctx.mounted) {
                showDialog(context: ctx, builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  title: Row(children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(LucideIcons.box, size: 16, color: kAccent)),
                    const SizedBox(width: 12),
                    const Text('Partie sélectionnée', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextMain)),
                  ]),
                  content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3))), child: Row(children: [
                      const Icon(LucideIcons.checkCircle, size: 14, color: Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(meshName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: kTextMain))),
                    ])),
                    const SizedBox(height: 8),
                    Text(selectedMeshes.contains(meshName) ? '✓ Associée à cette tâche' : 'Désassociée de cette tâche', style: TextStyle(fontSize: 12, color: selectedMeshes.contains(meshName) ? const Color(0xFF10B981) : kTextSub)),
                  ]),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK', style: TextStyle(color: kAccent, fontWeight: FontWeight.w700)))],
                ));
              }
            }
          }
        } catch (_) {}
      });

      final formColumn = Column(children: [
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
      ]);

      // Mesh panel (right side when 3D model available)
      final meshPanel = hasMesh ? Container(
        width: 340,
        decoration: const BoxDecoration(color: Color(0xFFF9FAFB), border: Border(left: BorderSide(color: Color(0xFFE5E7EB)))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Mini 3D viewer
          Container(
            height: 220,
            color: const Color(0xFF1F2937),
            child: ClipRRect(child: WebViewWidget(controller: viewerCtrl!)),
          ),
          // Mesh list header
          Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 8), child: Row(children: [
            const Icon(LucideIcons.box, size: 13, color: kAccent),
            const SizedBox(width: 6),
            const Text('PARTIES DU BÂTIMENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kTextSub, letterSpacing: 0.5)),
            const Spacer(),
            if (selectedMeshes.isNotEmpty)
              Text('${selectedMeshes.length} sél.', style: const TextStyle(fontSize: 10, color: kAccent, fontWeight: FontWeight.w600)),
          ])),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: Text('Cliquez sur le modèle ou sur un chip pour associer une partie à cette tâche.', style: TextStyle(fontSize: 10, color: kTextSub))),
          const SizedBox(height: 10),
          // Mesh chips
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final name in _model3D!.meshNames)
                GestureDetector(
                  onTap: () {
                    sd(() {
                      if (selectedMeshes.contains(name)) selectedMeshes.remove(name);
                      else selectedMeshes.add(name);
                    });
                    highlightSelected(sd);
                    if (selectedMeshes.contains(name)) {
                      viewerCtrl!.runJavaScript('zoomToMesh(${jsonEncode(name)});');
                    }
                    // Popup de confirmation
                    showDialog(context: ctx, builder: (_) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      title: Row(children: [
                        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(LucideIcons.box, size: 16, color: kAccent)),
                        const SizedBox(width: 12),
                        const Text('Partie sélectionnée', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextMain)),
                      ]),
                      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3))), child: Row(children: [
                          const Icon(LucideIcons.checkCircle, size: 14, color: Color(0xFF10B981)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: kTextMain))),
                        ])),
                        const SizedBox(height: 8),
                        Text(selectedMeshes.contains(name) ? '✓ Associée à cette tâche' : 'Désassociée de cette tâche', style: TextStyle(fontSize: 12, color: selectedMeshes.contains(name) ? const Color(0xFF10B981) : kTextSub)),
                      ]),
                      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK', style: TextStyle(color: kAccent, fontWeight: FontWeight.w700)))],
                    ));
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: selectedMeshes.contains(name) ? kAccent : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selectedMeshes.contains(name) ? kAccent : const Color(0xFFE5E7EB)),
                    ),
                    child: Text(name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: selectedMeshes.contains(name) ? Colors.white : kTextSub)),
                  ),
                ),
            ]),
          )),
        ]),
      ) : null;

      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: hasMesh ? 860 : 500),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _DialogHeader(icon: isEdit ? LucideIcons.pencil : LucideIcons.listPlus, title: isEdit ? 'Modifier la tâche' : 'Nouvelle tâche', subtitle: isEdit ? 'Mettez à jour les informations' : 'Ajoutez une tâche au projet'),
            Flexible(child: hasMesh
              ? IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: formColumn)),
                  meshPanel!,
                ]))
              : SingleChildScrollView(padding: const EdgeInsets.all(20), child: formColumn),
            ),
            _DialogActions(
              onCancel: () { _pollTimer?.cancel(); Navigator.pop(ctx); },
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
                final t = Tache(
                  id: isEdit ? existing!.id : '',
                  projetId: widget.project.id,
                  phaseId: phaseId,
                  titre: titreCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  statut: statut,
                  dateDebut: debutCtrl.text.trim().isEmpty ? null : debutCtrl.text.trim(),
                  dateFin: finCtrl.text.trim().isEmpty ? null : finCtrl.text.trim(),
                  budgetEstime: double.tryParse(budgetCtrl.text.replaceAll(' ', '')) ?? 0,
                  remarques: remarquesCtrl.text.trim(),
                  meshNames: selectedMeshes.toList(),
                  createdAt: isEdit ? existing!.createdAt : '',
                );
                if (isEdit) {
                  if (statut != existing!.statut) await TacheService.updateStatut(t.id, statut, projetId: widget.project.id, ancienStatut: existing.statut, budgetEstime: t.budgetEstime);
                  await TacheService.updateTache(t);
                  _snack(context, 'Tâche modifiée', kAccent);
                } else {
                  await TacheService.addTache(t);
                  _snack(context, 'Tâche ajoutée', kAccent);
                }
                _pollTimer?.cancel();
                Navigator.pop(ctx);
                _load();
              },
              label: isEdit ? 'Enregistrer' : 'Ajouter',
            ),
          ]),
        ),
      );
    }));
  }

  // HTML Three.js viewer template
  String _buildViewerHtml(String modelUrl) => '''
<!DOCTYPE html><html><head><meta charset="utf-8">
<style>*{margin:0;padding:0;box-sizing:border-box}body{background:#1F2937;overflow:hidden}
#load{position:fixed;top:50%;left:50%;transform:translate(-50%,-50%);color:#9CA3AF;font-family:Arial;font-size:12px}
</style></head><body>
<div id="load">Chargement...</div>
<script type="importmap">{"imports":{"three":"https://cdn.jsdelivr.net/npm/three@0.158.0/build/three.module.js","three/addons/":"https://cdn.jsdelivr.net/npm/three@0.158.0/examples/jsm/"}}</script>
<script type="module">
import * as THREE from 'three';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
window._pendingClicks=[];
const scene=new THREE.Scene();scene.background=new THREE.Color(0x1F2937);
const W=window.innerWidth,H=window.innerHeight;
const camera=new THREE.PerspectiveCamera(45,W/H,0.01,1000);
const renderer=new THREE.WebGLRenderer({antialias:true});
renderer.setPixelRatio(window.devicePixelRatio);renderer.setSize(W,H);
document.body.appendChild(renderer.domElement);
const controls=new OrbitControls(camera,renderer.domElement);
controls.enableDamping=true;controls.dampingFactor=0.05;
scene.add(new THREE.AmbientLight(0xffffff,0.8));
const d=new THREE.DirectionalLight(0xffffff,0.9);d.position.set(10,10,5);scene.add(d);
const meshMap={},origMat={};
new GLTFLoader().load('${modelUrl.replaceAll("'", "\\'")}', gltf=>{
  document.getElementById('load').style.display='none';
  scene.add(gltf.scene);
  const box=new THREE.Box3().setFromObject(gltf.scene);
  const center=box.getCenter(new THREE.Vector3());
  const size=box.getSize(new THREE.Vector3());
  const maxD=Math.max(size.x,size.y,size.z)||1;
  gltf.scene.position.sub(center);
  camera.position.set(maxD*1.5,maxD,maxD*1.5);controls.target.set(0,0,0);controls.update();
  gltf.scene.traverse(obj=>{
    if(obj.isMesh){const n=obj.name||'Mesh_'+Object.keys(meshMap).length;obj.name=n;meshMap[n]=obj;
    origMat[n]=Array.isArray(obj.material)?obj.material.map(m=>m.clone()):obj.material?obj.material.clone():new THREE.MeshStandardMaterial();}
  });
},undefined,e=>document.getElementById('load').textContent='Erreur: '+e.message);
window.highlightMeshes=names=>{
  const ns=new Set(names);
  Object.entries(meshMap).forEach(([n,m])=>{const o=origMat[n];m.material=Array.isArray(o)?o.map(x=>x.clone()):o?o.clone():new THREE.MeshStandardMaterial();});
  ns.forEach(n=>{if(meshMap[n])meshMap[n].material=new THREE.MeshStandardMaterial({color:0x3B82F6,emissive:0x1d4ed8,emissiveIntensity:0.4,transparent:true,opacity:0.9});});
};
window.zoomToMesh=n=>{const m=meshMap[n];if(!m)return;const b=new THREE.Box3().setFromObject(m);const c=b.getCenter(new THREE.Vector3());const s=b.getSize(new THREE.Vector3());const mx=Math.max(s.x,s.y,s.z)||1;controls.target.copy(c);camera.position.set(c.x+mx*2,c.y+mx,c.z+mx*2);controls.update();};
const ray=new THREE.Raycaster(),mouse=new THREE.Vector2();
renderer.domElement.addEventListener('click',e=>{
  const r=renderer.domElement.getBoundingClientRect();
  mouse.x=((e.clientX-r.left)/r.width)*2-1;mouse.y=-((e.clientY-r.top)/r.height)*2+1;
  ray.setFromCamera(mouse,camera);
  const hits=ray.intersectObjects(Object.values(meshMap),false);
  if(hits.length>0)window._pendingClicks.push(hits[0].object.name);
});
window.addEventListener('resize',()=>{camera.aspect=window.innerWidth/window.innerHeight;camera.updateProjectionMatrix();renderer.setSize(window.innerWidth,window.innerHeight);});
(function animate(){requestAnimationFrame(animate);controls.update();renderer.render(scene,camera);}());
</script></body></html>
''';

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
            Expanded(flex: 3, child: Text('N° / TÂCHE',        style: _hStyle)),
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

        // N° / désignation + phase + tâche
        Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(f.numero.isNotEmpty ? f.numero : '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextMain), overflow: TextOverflow.ellipsis),
          if (f.tacheAssociee.isNotEmpty || f.phaseId != null) ...[
            const SizedBox(height: 3),
            Row(children: [
              if (f.tacheAssociee.isNotEmpty) ...[
                const Icon(LucideIcons.checkSquare, size: 10, color: kAccent),
                const SizedBox(width: 3),
                Flexible(child: Text(f.tacheAssociee, style: const TextStyle(fontSize: 10, color: kAccent, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              ],
            ]),
          ],
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
                      if (raw.startsWith('fichier:')) {
                        // Fichier non uploadé — informer l'utilisateur
                        _snack(context, 'Fichier local non accessible. Modifiez la facture pour ré-uploader.', const Color(0xFFF59E0B));
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

  // Phase & tâche (pour factures supplémentaires)
  List<Phase>  _phases        = [];
  List<Tache>  _taches        = [];
  String?      _selectedPhaseId;
  String?      _selectedTacheId;
  bool         _loadingPhases = false;

  Color get _accent => widget.isInitiale ? const Color(0xFF8B5CF6) : kAccent;

  @override
  void initState() {
    super.initState();
    final f = widget.existing;
    if (f != null) {
      _numCtrl.text       = f.numero;
      _montantCtrl.text   = f.montant > 0 ? f.montant.toStringAsFixed(2) : '';
      _echeanceCtrl.text  = f.dateEcheance ?? '';
      _fournCtrl.text     = f.fournisseur;
      _statut             = f.statut;
      _pieceJointeUrl     = f.urlPdf;
      _selectedPhaseId    = f.phaseId;
      if (f.urlPdf?.startsWith('fichier:') == true) {
        _pieceJointeNom = f.urlPdf!.replaceFirst('fichier:', '');
      }
    }
    if (!widget.isInitiale) _loadPhasesEtTaches();
  }

  Future<void> _loadPhasesEtTaches() async {
    setState(() => _loadingPhases = true);
    try {
      final results = await Future.wait([
        PhaseService.getPhases(widget.project.id),
        TacheService.getTaches(widget.project.id),
      ]);
      final phases = results[0] as List<Phase>;
      final taches = results[1] as List<Tache>;
      // Restaurer la tâche sélectionnée si édition
      String? selectedTacheId;
      if (widget.existing != null && widget.existing!.tacheAssociee.isNotEmpty) {
        final match = taches.where((t) => t.titre == widget.existing!.tacheAssociee).firstOrNull;
        selectedTacheId = match?.id;
      }
      setState(() {
        _phases           = phases;
        _taches           = taches;
        _selectedTacheId  = selectedTacheId;
        _loadingPhases    = false;
      });
    } catch (_) {
      setState(() => _loadingPhases = false);
    }
  }

  List<Tache> get _tachesDeLaPhase {
    if (_selectedPhaseId == null) return _taches;
    return _taches.where((t) => t.phaseId == _selectedPhaseId).toList();
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
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;

      // Afficher un indicateur d'upload
      setState(() {
        _pieceJointeNom   = file.name;
        _pieceJointeUrl   = null;
        _pieceJointeBytes = file.bytes;
      });

      _snack(context, 'Upload en cours...', kAccent);

      // Upload vers Supabase Storage (bucket "factures")
      try {
        final ext       = file.name.split('.').last.toLowerCase();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final path      = 'factures/${widget.project.id}/${timestamp}_${file.name}';
        final mime      = ext == 'pdf' ? 'application/pdf' : 'image/$ext';

        await Supabase.instance.client.storage
            .from('factures')
            .uploadBinary(path, file.bytes!, fileOptions: FileOptions(contentType: mime, upsert: true));

        final publicUrl = Supabase.instance.client.storage
            .from('factures')
            .getPublicUrl(path);

        setState(() => _pieceJointeUrl = publicUrl);
        _snack(context, 'Fichier uploadé ✓', const Color(0xFF10B981));
      } catch (e) {
        // Upload échoué → on garde le fichier en local avec son nom
        setState(() => _pieceJointeUrl = 'fichier:${file.name}');
        _snack(context, 'Upload impossible — fichier enregistré localement', const Color(0xFFF59E0B));
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

    // Récupérer le titre de la tâche sélectionnée
    final tache = _selectedTacheId != null
        ? _taches.where((t) => t.id == _selectedTacheId).firstOrNull
        : null;

    final facture = Facture(
      id:            widget.existing?.id ?? '',
      projetId:      widget.project.id,
      phaseId:       _selectedPhaseId,
      numero:        num,
      montant:       m,
      statut:        _statut,
      dateEcheance:  _echeanceCtrl.text.trim().isEmpty ? null : _echeanceCtrl.text.trim(),
      urlPdf:        _pieceJointeUrl,
      fournisseur:   _fournCtrl.text.trim(),
      tacheAssociee: tache?.titre ?? '',
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

            // ── Phase & Tâche (factures supplémentaires uniquement) ──────
            if (!widget.isInitiale) ...[
              const SizedBox(height: 12),
              if (_loadingPhases)
                const Center(child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: kAccent)),
                ))
              else if (_phases.isNotEmpty) ...[
                // Sélecteur de phase
                const Text('PHASE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSub, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE5E7EB))),
                  child: DropdownButtonHideUnderline(child: DropdownButton<String?>(
                    value: _selectedPhaseId,
                    isExpanded: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    hint: const Text('Aucune phase', style: TextStyle(color: kTextSub, fontSize: 13)),
                    style: const TextStyle(color: kTextMain, fontSize: 13),
                    borderRadius: BorderRadius.circular(8),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('— Aucune phase —', style: TextStyle(color: kTextSub, fontSize: 13))),
                      ..._phases.map((ph) => DropdownMenuItem<String?>(
                        value: ph.id,
                        child: Row(children: [
                          const Icon(LucideIcons.layers, size: 13, color: Color(0xFF8B5CF6)),
                          const SizedBox(width: 8),
                          Text(ph.nom, style: const TextStyle(fontSize: 13)),
                        ]),
                      )),
                    ],
                    onChanged: (v) => setState(() {
                      _selectedPhaseId  = v;
                      _selectedTacheId  = null; // reset tâche quand phase change
                    }),
                  )),
                ),
                const SizedBox(height: 10),
                // Sélecteur de tâche (filtrée par phase)
                const Text('TÂCHE ASSOCIÉE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSub, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE5E7EB))),
                  child: DropdownButtonHideUnderline(child: DropdownButton<String?>(
                    value: _selectedTacheId,
                    isExpanded: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    hint: Text(
                      _tachesDeLaPhase.isEmpty ? 'Aucune tâche dans cette phase' : 'Sélectionner une tâche',
                      style: const TextStyle(color: kTextSub, fontSize: 13),
                    ),
                    style: const TextStyle(color: kTextMain, fontSize: 13),
                    borderRadius: BorderRadius.circular(8),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('— Aucune tâche —', style: TextStyle(color: kTextSub, fontSize: 13))),
                      ..._tachesDeLaPhase.map((t) => DropdownMenuItem<String?>(
                        value: t.id,
                        child: Row(children: [
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(color: _tacheColor(t.statut), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(t.titre, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                        ]),
                      )),
                    ],
                    onChanged: _tachesDeLaPhase.isEmpty ? null : (v) => setState(() => _selectedTacheId = v),
                  )),
                ),
              ],
            ],

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

  bool _uploading = false;

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'dwg', 'xlsx', 'doc', 'docx'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      setState(() { _fileName = file.name; if (_nomCtrl.text.isEmpty) _nomCtrl.text = file.name.split('.').first; });

      // Upload vers Supabase Storage si bytes disponibles
      if (file.bytes != null) {
        setState(() => _uploading = true);
        try {
          final ext  = file.name.split('.').last.toLowerCase();
          final ts   = DateTime.now().millisecondsSinceEpoch;
          final path = 'documents/${widget.projectId}/${ts}_${file.name}';
          final mime = ext == 'pdf' ? 'application/pdf'
              : (ext == 'png' || ext == 'jpg' || ext == 'jpeg') ? 'image/$ext'
              : 'application/octet-stream';

          await Supabase.instance.client.storage
              .from('documents')
              .uploadBinary(path, file.bytes!, fileOptions: FileOptions(contentType: mime, upsert: true));

          final url = Supabase.instance.client.storage.from('documents').getPublicUrl(path);
          setState(() { _urlCtrl.text = url; _uploading = false; });
          _snack(context, 'Fichier uploadé ✓', const Color(0xFF10B981));
        } catch (_) {
          setState(() { _urlCtrl.text = 'fichier:${file.name}'; _uploading = false; });
          _snack(context, 'Upload échoué — lien local conservé', const Color(0xFFF59E0B));
        }
      } else {
        _urlCtrl.text = 'fichier:${file.name}';
      }
    } catch (e) { _snack(context, 'Impossible d\'ouvrir le fichier', kRed); }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2035), locale: const Locale('fr', 'FR'), builder: (ctx2, child) => Theme(data: Theme.of(ctx2).copyWith(colorScheme: ColorScheme.light(primary: kAccent, onPrimary: Colors.white, surface: Colors.white, onSurface: kTextMain)), child: child!));
    if (picked != null) setState(() { _dateCtrl.text = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}'; });
  }

  Future<void> _submit() async {
    // Validation
    final nom = _nomCtrl.text.trim();
    if (nom.isEmpty) {
      _snack(context, 'Nom du document obligatoire', kRed);
      return;
    }

    // Attendre fin d'upload si en cours
    if (_uploading) {
      _snack(context, 'Upload en cours, patientez...', kAccent);
      return;
    }

    setState(() => _uploading = true);

    try {
      final version    = int.tryParse(_versionCtrl.text.trim()) ?? 1;
      // Encoder le nom avec séparateur null char
      final nomEncode  = '$nom||META||$_phase||META||$_typeLabel||META||$version||META||${_dateCtrl.text.trim()}';
      final typeFichier = _fileTypeFromLabel(_typeLabel);
      final url = _urlCtrl.text.trim().isNotEmpty
          ? _urlCtrl.text.trim()
          : (_fileName != null ? 'fichier:$_fileName' : 'non_defini');

      await DocumentService.addDocument(Document(
        id:       '',
        projetId: widget.projectId,
        nom:      nomEncode,
        url:      url,
        type:     typeFichier,
      ));

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        _snack(context, 'Erreur : $e', kRed);
      }
    }
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
          GestureDetector(
            onTap: _uploading ? null : _pickFile,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: _uploading ? kAccent.withOpacity(0.05) : _fileName != null ? const Color(0xFFEFF6FF) : const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _uploading ? kAccent.withOpacity(0.4) : _fileName != null ? const Color(0xFF3B82F6) : const Color(0xFFE5E7EB)),
              ),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _uploading ? kAccent.withOpacity(0.1) : _fileName != null ? const Color(0xFF3B82F6).withOpacity(0.1) : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _uploading
                      ? const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2, color: kAccent))
                      : Icon(_fileName != null ? LucideIcons.fileCheck : LucideIcons.upload, size: 16, color: _fileName != null ? const Color(0xFF3B82F6) : kTextSub),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    _uploading ? 'Upload en cours...' : (_fileName ?? 'Cliquez pour joindre un fichier'),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _uploading ? kAccent : _fileName != null ? kTextMain : kTextSub),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _uploading ? 'Envoi vers Supabase Storage...'
                        : _fileName != null
                            ? (_urlCtrl.text.startsWith('http') ? 'Uploadé ✓ — accessible en ligne' : 'Fichier local (pas de réseau)')
                            : 'PDF, DWG, XLSX, PNG, JPG acceptés',
                    style: TextStyle(fontSize: 11, color: _uploading ? kAccent : _fileName != null && _urlCtrl.text.startsWith('http') ? const Color(0xFF10B981) : kTextSub),
                  ),
                ])),
                if (_fileName != null && !_uploading)
                  GestureDetector(
                    onTap: () => setState(() { _fileName = null; _urlCtrl.clear(); }),
                    child: const Icon(LucideIcons.x, size: 16, color: kTextSub),
                  ),
              ]),
            ),
          ),
          if (_fileName == null) ...[const SizedBox(height: 12), _DField(icon: LucideIcons.link, label: 'OU URL DU FICHIER', hint: 'https://...', controller: _urlCtrl)],
        ])),
        Container(padding: const EdgeInsets.fromLTRB(20, 12, 20, 20), decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))), child: Row(children: [Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13), side: const BorderSide(color: Color(0xFFD1D5DB)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Annuler', style: TextStyle(color: kTextSub, fontWeight: FontWeight.w600)))), const SizedBox(width: 10), Expanded(child: ElevatedButton(onPressed: _uploading ? null : _submit, style: ElevatedButton.styleFrom(backgroundColor: kAccent, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: _uploading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Ajouter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))))])),
      ]))),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ONGLET ÉQUIPE
// ══════════════════════════════════════════════════════════════════════════════
class _EquipeTab extends StatefulWidget {
  final Project project;
  const _EquipeTab({required this.project});
  @override State<_EquipeTab> createState() => _EquipeTabState();
}

class _EquipeTabState extends State<_EquipeTab> {
  List<Membre> membres = [];
  bool loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      // Approche 1 : table de jointure project_members
      final viaJoin = await ProjectMemberService.getMembres(widget.project.id);

      // Approche 2 : champ projets_assignes sur le membre lui-même
      final viaTitre = await MembreService.getMembresByProject(widget.project.titre);

      // Fusion sans doublons (priorité à viaJoin pour les données complètes)
      final ids = <String>{};
      final merged = <Membre>[];
      for (final m in [...viaJoin, ...viaTitre]) {
        if (ids.add(m.id)) merged.add(m);
      }

      setState(() { membres = merged; loading = false; });
    } catch (e) { setState(() => loading = false); }
  }

  Color _avatarColor(String nom) {
    const colors = [
      Color(0xFF3B82F6), Color(0xFF8B5CF6), Color(0xFF10B981),
      Color(0xFFEC4899), Color(0xFFF59E0B), Color(0xFF06B6D4),
      Color(0xFF6366F1), Color(0xFFEF4444),
    ];
    if (nom.isEmpty) return colors[0];
    return colors[nom.codeUnitAt(0) % colors.length];
  }

  String _initiales(String nom) {
    final parts = nom.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final pad = isMobile ? 16.0 : 28.0;
    if (loading) return const Center(child: CircularProgressIndicator(color: kAccent));

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header ──────────────────────────────────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Équipe du projet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kTextMain)),
            const SizedBox(height: 4),
            Text(
              membres.isEmpty
                  ? 'Aucun membre assigné'
                  : '${membres.length} membre${membres.length > 1 ? "s" : ""} assigné${membres.length > 1 ? "s" : ""}',
              style: const TextStyle(color: kTextSub, fontSize: 13),
            ),
          ])),
          if (widget.project.chef.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: kAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kAccent.withOpacity(0.2)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(LucideIcons.crown, size: 12, color: kAccent),
                const SizedBox(width: 6),
                Text(widget.project.chef, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kAccent)),
              ]),
            ),
        ]),
        const SizedBox(height: 20),

        // ── KPIs ─────────────────────────────────────────────────────────
        if (membres.isNotEmpty) ...[
          IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _EquipeKpi(icon: LucideIcons.users,       label: 'Membres',        value: '${membres.length}',                                              color: kAccent),
            const SizedBox(width: 10),
            _EquipeKpi(icon: LucideIcons.checkCircle, label: 'Disponibles',    value: '${membres.where((m) => m.disponible).length}',                   color: const Color(0xFF10B981)),
            const SizedBox(width: 10),
            _EquipeKpi(icon: LucideIcons.briefcase,   label: 'Rôles distincts',value: '${membres.map((m) => m.role).where((r) => r.isNotEmpty).toSet().length}', color: const Color(0xFF8B5CF6)),
          ])),
          const SizedBox(height: 20),
        ],

        // ── Grille membres ───────────────────────────────────────────────
        if (membres.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
            child: Column(children: [
              Container(width: 64, height: 64, decoration: BoxDecoration(color: kAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(16)), child: Icon(LucideIcons.users, size: 28, color: kAccent.withOpacity(0.5))),
              const SizedBox(height: 16),
              const Text('Aucun membre assigné à ce projet', style: TextStyle(color: kTextMain, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text('Assignez des membres depuis la gestion des membres', style: TextStyle(color: kTextSub, fontSize: 12)),
            ]),
          )
        else
          LayoutBuilder(builder: (ctx, cs) {
            final cols = cs.maxWidth > 700 ? 3 : cs.maxWidth > 450 ? 2 : 1;
            final rows = <Widget>[];
            for (int i = 0; i < membres.length; i += cols) {
              final row = membres.skip(i).take(cols).toList();
              rows.add(IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (int j = 0; j < row.length; j++) ...[
                  if (j > 0) const SizedBox(width: 14),
                  Expanded(child: _MembreCard(
                    membre: row[j],
                    avatarColor: _avatarColor(row[j].nom),
                    initiales: _initiales(row[j].nom),
                    isChef: widget.project.chef.isNotEmpty &&
                        row[j].nom.toLowerCase().contains(widget.project.chef.toLowerCase()),
                  )),
                ],
                if (row.length < cols) ...[const SizedBox(width: 14), const Expanded(child: SizedBox())],
              ])));
              if (i + cols < membres.length) rows.add(const SizedBox(height: 14));
            }
            return Column(children: rows);
          }),
      ]),
    );
  }
}

// ── KPI Équipe ────────────────────────────────────────────────────────────────
class _EquipeKpi extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _EquipeKpi({required this.icon, required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))]),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 15, color: color)),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: kTextSub, fontWeight: FontWeight.w500)),
      ]),
    ]),
  ));
}

// ── Carte Membre ──────────────────────────────────────────────────────────────
class _MembreCard extends StatelessWidget {
  final Membre membre;
  final Color avatarColor;
  final String initiales;
  final bool isChef;
  const _MembreCard({required this.membre, required this.avatarColor, required this.initiales, this.isChef = false});

  @override
  Widget build(BuildContext context) {
    final m = membre;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isChef ? kAccent.withOpacity(0.35) : const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Bande colorée
        Container(height: 5, decoration: BoxDecoration(color: avatarColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(14)))),
        Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Avatar + nom + rôle
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: avatarColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: avatarColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]),
              child: Center(child: Text(initiales, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(m.nom, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kTextMain), overflow: TextOverflow.ellipsis)),
                if (isChef) ...[const SizedBox(width: 4), const Icon(LucideIcons.crown, size: 13, color: kAccent)],
              ]),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: avatarColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: avatarColor.withOpacity(0.2))),
                child: Text(m.role.isNotEmpty ? m.role : 'Membre', style: TextStyle(color: avatarColor, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ])),
          ]),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 12),
          // Contact
          if (m.email.isNotEmpty) ...[
            Row(children: [const Icon(LucideIcons.mail, size: 13, color: kTextSub), const SizedBox(width: 8), Expanded(child: Text(m.email, style: const TextStyle(color: kTextSub, fontSize: 12), overflow: TextOverflow.ellipsis))]),
            const SizedBox(height: 7),
          ],
          if (m.telephone.isNotEmpty) ...[
            Row(children: [const Icon(LucideIcons.phone, size: 13, color: kTextSub), const SizedBox(width: 8), Text(m.telephone, style: const TextStyle(color: kTextSub, fontSize: 12))]),
            const SizedBox(height: 7),
          ],
          if (m.specialite != null && m.specialite!.isNotEmpty) ...[
            Row(children: [const Icon(LucideIcons.award, size: 13, color: kTextSub), const SizedBox(width: 8), Expanded(child: Text(m.specialite!, style: const TextStyle(color: kTextSub, fontSize: 12), overflow: TextOverflow.ellipsis))]),
            const SizedBox(height: 7),
          ],
          const SizedBox(height: 4),
          // Disponibilité + projets
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: m.disponible ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(6)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: m.disponible ? const Color(0xFF10B981) : kRed, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(m.disponible ? 'Disponible' : 'Indisponible', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: m.disponible ? const Color(0xFF10B981) : kRed)),
              ]),
            ),
            const Spacer(),
            if (m.projetsAssignes.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(LucideIcons.briefcase, size: 10, color: kTextSub),
                  const SizedBox(width: 4),
                  Text('${m.projetsAssignes.length} projet${m.projetsAssignes.length > 1 ? "s" : ""}', style: const TextStyle(fontSize: 10, color: kTextSub, fontWeight: FontWeight.w600)),
                ]),
              ),
          ]),
        ])),
      ]),
    );
  }
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

  // ── Pointage ──────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _defauts   = [];
  List<Map<String, dynamic>> _documents = []; // plans disponibles
  Map<String, dynamic>?      _planActif;
  bool _loadingDefauts = true;

  // ── Galerie ───────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _photos = [];
  bool _loadingPhotos = true;
  bool _uploadingPhoto = false;

  // ── CRC & Actualités ─────────────────────────────────────────────────────
  List<Map<String, dynamic>> _crcs       = [];
  List<Map<String, dynamic>> _actualites = [];
  bool _loadingCRC = true;

  @override
  void initState() { super.initState(); _loadAll(); }

  Future<void> _loadAll() async {
    await Future.wait([_loadDefauts(), _loadDocuments(), _loadPhotos(), _loadCRC()]);
  }

  // ── Loaders ───────────────────────────────────────────────────────────────
  Future<void> _loadDefauts() async {
    try {
      final data = await Supabase.instance.client
          .from('defauts')
          .select()
          .eq('projet_id', widget.project.id)
          .order('created_at', ascending: false);
      if (mounted) setState(() { _defauts = List<Map<String,dynamic>>.from(data); _loadingDefauts = false; });
    } catch (_) { if (mounted) setState(() => _loadingDefauts = false); }
  }

  Future<void> _loadDocuments() async {
    try {
      final data = await Supabase.instance.client
          .from('documents')
          .select()
          .eq('projet_id', widget.project.id)
          .order('uploaded_at', ascending: false);
      if (mounted) setState(() => _documents = List<Map<String,dynamic>>.from(data));
    } catch (_) {}
  }

  Future<void> _loadPhotos() async {
    try {
      final data = await Supabase.instance.client
          .from('photos_chantier')
          .select()
          .eq('projet_id', widget.project.id)
          .order('uploaded_at', ascending: false); // plus récentes en premier
      if (mounted) setState(() { _photos = List<Map<String,dynamic>>.from(data); _loadingPhotos = false; });
    } catch (_) { if (mounted) setState(() => _loadingPhotos = false); }
  }

  Future<void> _loadCRC() async {
    try {
      final crcs = await Supabase.instance.client
          .from('comptes_rendus')
          .select()
          .eq('projet_id', widget.project.id)
          .order('created_at', ascending: false);
      final acts = await Supabase.instance.client
          .from('actualites_chantier')
          .select()
          .eq('projet_id', widget.project.id)
          .order('created_at', ascending: false);
      if (mounted) setState(() {
        _crcs       = List<Map<String,dynamic>>.from(crcs);
        _actualites = List<Map<String,dynamic>>.from(acts);
        _loadingCRC = false;
      });
    } catch (_) { if (mounted) setState(() => _loadingCRC = false); }
  }

  // ── Actions Photo ─────────────────────────────────────────────────────────
  Future<void> _ajouterPhotos() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image, allowMultiple: true, withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      setState(() => _uploadingPhoto = true);
      int ok = 0;
      for (final file in result.files) {
        if (file.bytes == null) continue;
        try {
          final ts   = DateTime.now().millisecondsSinceEpoch;
          final path = 'chantier/${widget.project.id}/${ts}_${file.name}';
          await Supabase.instance.client.storage
              .from('photos-chantier')
              .uploadBinary(path, file.bytes!, fileOptions: FileOptions(contentType: 'image/jpeg', upsert: true));
          final url = Supabase.instance.client.storage.from('photos-chantier').getPublicUrl(path);
          await Supabase.instance.client.from('photos_chantier').insert({
            'projet_id': widget.project.id,
            'nom':       file.name,
            'url':       url,
          });
          ok++;
        } catch (_) {}
      }
      if (ok > 0) _snack(context, '$ok photo(s) ajoutée(s) ✓', const Color(0xFF10B981));
      else        _snack(context, "Erreur lors de l'upload", kRed);
      await _loadPhotos();
    } catch (_) {
      _snack(context, "Impossible d'ouvrir les photos", kRed);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _supprimerPhoto(Map<String, dynamic> photo) async {
    try {
      await Supabase.instance.client.from('photos_chantier').delete().eq('id', photo['id']);
      await _loadPhotos();
      _snack(context, 'Photo supprimée', kRed);
    } catch (_) { _snack(context, 'Erreur suppression', kRed); }
  }

  // ── Actions Défaut ────────────────────────────────────────────────────────
  void _showAddDefautDialog(double rx, double ry, String docId, String docNom) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 380), child: Column(mainAxisSize: MainAxisSize.min, children: [
        _DialogHeader(icon: LucideIcons.mapPin, title: 'Nouveau pointage', subtitle: 'Décrivez le défaut ou la remarque'),
        Padding(padding: const EdgeInsets.all(20), child: _DField(icon: LucideIcons.alertTriangle, label: 'DESCRIPTION *', hint: 'Ex: Fissure sur le mur nord', controller: ctrl, maxLines: 2)),
        _DialogActions(onCancel: () => Navigator.pop(context), onConfirm: () async {
          final t = ctrl.text.trim();
          if (t.isEmpty) { _snack(context, 'Description obligatoire', kRed); return; }
          try {
            await Supabase.instance.client.from('defauts').insert({
              'projet_id':    widget.project.id,
              'document_id':  docId,
              'document_nom': docNom,
              'titre':        t,
              'statut':       'a_faire',
              'x':            rx,
              'y':            ry,
            });
            Navigator.pop(context);
            _snack(context, 'Pointage ajouté', kAccent);
            await _loadDefauts();
          } catch (_) { _snack(context, 'Erreur sauvegarde', kRed); }
        }, label: 'Ajouter'),
      ])),
    ));
  }

  Future<void> _toggleDefautStatut(Map<String, dynamic> d) async {
    final newStatut = d['statut'] == 'regle' ? 'a_faire' : 'regle';
    try {
      await Supabase.instance.client.from('defauts').update({'statut': newStatut}).eq('id', d['id']);
      await _loadDefauts();
    } catch (_) {}
  }

  Future<void> _supprimerDefaut(Map<String, dynamic> d) async {
    try {
      await Supabase.instance.client.from('defauts').delete().eq('id', d['id']);
      await _loadDefauts();
      _snack(context, 'Pointage supprimé', kRed);
    } catch (_) {}
  }

  // ── Actions CRC ───────────────────────────────────────────────────────────
  void _showAddCrcDialog() {
    final titreCtrl   = TextEditingController();
    final contenuCtrl = TextEditingController();
    String statut = 'conforme';
    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (ctx, sd) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.08), borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), border: Border(bottom: BorderSide(color: const Color(0xFF3B82F6).withOpacity(0.15)))),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Row(children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: const Icon(LucideIcons.clipboardList, color: Color(0xFF3B82F6), size: 20)),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Compte-Rendu de Chantier', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF3B82F6))),
              Text('Rapport officiel de visite ou de réunion', style: TextStyle(color: kTextSub, fontSize: 12)),
            ])),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _DField(icon: LucideIcons.fileText, label: 'TITRE DU RAPPORT *', hint: 'Ex: Rapport de visite — Semaine 15', controller: titreCtrl),
          const SizedBox(height: 12),
          _DField(icon: LucideIcons.alignLeft, label: 'CONTENU / OBSERVATIONS', hint: 'Décrivez les observations, décisions et actions à prendre...', controller: contenuCtrl, maxLines: 4),
          const SizedBox(height: 14),
          const Text('ÉTAT DU CHANTIER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSub, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Row(children: [
            for (final s in ['conforme', 'attention', 'critique'])
              Expanded(child: Padding(
                padding: EdgeInsets.only(right: s == 'critique' ? 0 : 8),
                child: GestureDetector(onTap: () => sd(() => statut = s), child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: statut == s ? _crcColor(s).withOpacity(0.12) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: statut == s ? _crcColor(s) : const Color(0xFFE5E7EB), width: statut == s ? 2 : 1),
                  ),
                  child: Column(children: [
                    Icon(s == 'conforme' ? LucideIcons.checkCircle : s == 'attention' ? LucideIcons.alertCircle : LucideIcons.xCircle, size: 16, color: statut == s ? _crcColor(s) : kTextSub),
                    const SizedBox(height: 4),
                    Text(_crcLabel(s), style: TextStyle(fontSize: 11, fontWeight: statut == s ? FontWeight.w700 : FontWeight.w500, color: statut == s ? _crcColor(s) : kTextSub)),
                  ]),
                )),
              )),
          ]),
        ])),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
          child: Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), side: const BorderSide(color: Color(0xFFD1D5DB)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Annuler', style: TextStyle(color: kTextSub)))),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                final titre = titreCtrl.text.trim();
                if (titre.isEmpty) { _snack(ctx, 'Titre obligatoire', kRed); return; }
                final now = DateTime.now();
                try {
                  await Supabase.instance.client.from('comptes_rendus').insert({
                    'projet_id': widget.project.id,
                    'titre':     titre,
                    'contenu':   contenuCtrl.text.trim(),
                    'statut':    statut,
                    'auteur':    widget.project.chef,
                  });
                  Navigator.pop(ctx);
                  _snack(context, 'CRC ajouté ✓', const Color(0xFF3B82F6));
                  await _loadCRC();
                } catch (_) { _snack(ctx, 'Erreur sauvegarde', kRed); }
              },
              child: const Text('Créer le rapport', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            )),
          ]),
        ),
      ]))),
    )));
  }

  void _showAddActualiteDialog() {
    final contenuCtrl = TextEditingController();
    String type = 'Progrès';
    const types = ['Progrès', 'Problème', 'Décision', 'Livraison', 'Sécurité', 'Note'];
    const typeIcons = {
      'Progrès':  LucideIcons.trendingUp,
      'Problème': LucideIcons.alertTriangle,
      'Décision': LucideIcons.checkSquare,
      'Livraison':LucideIcons.package,
      'Sécurité': LucideIcons.shieldAlert,
      'Note':     LucideIcons.stickyNote,
    };
    final typeColors = {
      'Progrès':  const Color(0xFF10B981),
      'Problème': kRed,
      'Décision': const Color(0xFF8B5CF6),
      'Livraison':const Color(0xFF3B82F6),
      'Sécurité': const Color(0xFFF59E0B),
      'Note':     const Color(0xFF6B7280),
    };
    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (ctx, sd) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.08), borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), border: Border(bottom: BorderSide(color: const Color(0xFF10B981).withOpacity(0.15)))),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Row(children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: const Icon(LucideIcons.rss, color: Color(0xFF10B981), size: 20)),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Fil d'actualité", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF10B981))),
              Text('Note rapide, info informelle ou observation terrain', style: TextStyle(color: kTextSub, fontSize: 12)),
            ])),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('TYPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSub, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: types.map((t) {
            final isSelected = type == t;
            final color = typeColors[t]!;
            final icon  = typeIcons[t]!;
            return GestureDetector(onTap: () => sd(() => type = t), child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: isSelected ? color.withOpacity(0.12) : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? color : const Color(0xFFE5E7EB), width: isSelected ? 2 : 1)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 12, color: isSelected ? color : kTextSub), const SizedBox(width: 5), Text(t, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? color : kTextSub))]),
            ));
          }).toList()),
          const SizedBox(height: 14),
          _DField(icon: LucideIcons.messageSquare, label: 'NOTE *', hint: 'Ex: Les fondations sont terminées, béton de bonne qualité...', controller: contenuCtrl, maxLines: 3),
        ])),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
          child: Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), side: const BorderSide(color: Color(0xFFD1D5DB)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Annuler', style: TextStyle(color: kTextSub)))),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                final c = contenuCtrl.text.trim();
                if (c.isEmpty) { _snack(ctx, 'Note obligatoire', kRed); return; }
                try {
                  await Supabase.instance.client.from('actualites_chantier').insert({
                    'projet_id': widget.project.id,
                    'type':      type,
                    'contenu':   c,
                    'auteur':    widget.project.chef,
                  });
                  Navigator.pop(ctx);
                  _snack(context, 'Actualité publiée ✓', const Color(0xFF10B981));
                  await _loadCRC();
                } catch (_) { _snack(ctx, 'Erreur sauvegarde', kRed); }
              },
              child: const Text('Publier', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            )),
          ]),
        ),
      ]))),
    )));
  }

  static Color _crcColor(String s) => s == 'conforme' ? const Color(0xFF10B981) : s == 'attention' ? const Color(0xFFF59E0B) : kRed;
  static String _crcLabel(String s) => s == 'conforme' ? 'Conforme' : s == 'attention' ? 'Attention' : 'Critique';
  static String _monthFr(int m) { const months = ['jan','fév','mars','avr','mai','juin','juil','août','sept','oct','nov','déc']; return months[m-1]; }
  static String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day} ${_monthFr(d.month)} ${d.year}';
    } catch (_) { return iso; }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final pad = isMobile ? 16.0 : 28.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header + sous-onglets
      Container(color: kCardBg, padding: EdgeInsets.fromLTRB(pad, 20, pad, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Suivi de chantier & Visites', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kTextMain)),
            SizedBox(height: 3),
            Text('Pointage sur plans, photos et comptes-rendus', style: TextStyle(color: kTextSub, fontSize: 12)),
          ])),
          // Bouton contextuel selon l'onglet actif
          if (_subTab == 0)
            const SizedBox.shrink()
          else if (_subTab == 1)
            ElevatedButton.icon(
              onPressed: _uploadingPhoto ? null : _ajouterPhotos,
              icon: _uploadingPhoto
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(LucideIcons.camera, size: 14, color: Colors.white),
              label: const Text('Ajouter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
              style: ElevatedButton.styleFrom(backgroundColor: kAccent, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            )
          else ...[
            OutlinedButton.icon(
              onPressed: _showAddActualiteDialog,
              icon: const Icon(LucideIcons.rss, size: 13, color: Color(0xFF10B981)),
              label: const Text('Actualité', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF10B981)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _showAddCrcDialog,
              icon: const Icon(LucideIcons.clipboardList, size: 13, color: Colors.white),
              label: const Text('Rapport CRC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            ),
          ],
        ]),
        const SizedBox(height: 16),
        // Sous-onglets
        Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)), child: Row(children: [
          for (int i = 0; i < 3; i++)
            Expanded(child: GestureDetector(onTap: () => setState(() => _subTab = i), child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(color: _subTab == i ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(9), boxShadow: _subTab == i ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 1))] : null),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon([LucideIcons.mapPin, LucideIcons.image, LucideIcons.clipboardList][i], size: 13, color: _subTab == i ? kTextMain : kTextSub),
                const SizedBox(width: 6),
                Text(['Pointage', 'Photos', 'Rapports & Actualités'][i], style: TextStyle(fontSize: 12, fontWeight: _subTab == i ? FontWeight.w700 : FontWeight.w500, color: _subTab == i ? kTextMain : kTextSub)),
              ]),
            ))),
        ])),
        const SizedBox(height: 12),
      ])),
      Expanded(child: _buildSubTab(pad)),
    ]);
  }

  Widget _buildSubTab(double pad) {
    switch (_subTab) {
      case 0: return _buildPointage(pad);
      case 1: return _buildGalerie(pad);
      default: return _buildCRC(pad);
    }
  }

  // ── POINTAGE ──────────────────────────────────────────────────────────────
  Widget _buildPointage(double pad) {
    // Plans disponibles = documents de type Plan
    final plans = _documents.where((d) {
      final nom = (d['nom'] as String? ?? '');
      final isEncoded = nom.contains('||META||') || nom.contains('');
      if (!isEncoded) return true;
      final parts = nom.contains('||META||') ? nom.split('||META||') : nom.split('');
      return parts.length > 2 && parts[2] == 'Plan';
    }).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(pad, 16, pad, pad + 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Liste des plans ───────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: kRed.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(LucideIcons.mapPin, size: 15, color: kRed)),
              const SizedBox(width: 10),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Plans & pointages', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextMain)),
                Text('Sélectionnez un plan puis cliquez pour ajouter un pointage', style: TextStyle(fontSize: 11, color: kTextSub)),
              ])),
            ]),
            const SizedBox(height: 14),
            if (plans.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE5E7EB))),
                child: Column(children: [
                  Icon(LucideIcons.fileX, size: 28, color: kTextSub.withOpacity(0.4)),
                  const SizedBox(height: 8),
                  const Text('Aucun plan disponible', style: TextStyle(color: kTextSub, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text("Ajoutez des plans dans l'onglet Documents", style: TextStyle(color: kTextSub, fontSize: 11)),
                ]),
              )
            else ...[
              // Sélecteur de plans — grille de cartes avec miniature
              LayoutBuilder(builder: (ctx2, cs2) {
                final cardW = (cs2.maxWidth / (cs2.maxWidth > 600 ? 3 : 2) - 8).clamp(120.0, 220.0);
                return Wrap(spacing: 10, runSpacing: 10, children: plans.map((doc) {
                  final nomRaw2 = (doc['nom'] as String? ?? '');
                  final nom     = nomRaw2.contains('||META||') ? nomRaw2.split('||META||')[0]
                                : nomRaw2.contains('')     ? nomRaw2.split('')[0]
                                : nomRaw2;
                  final url     = (doc['url'] as String? ?? '');
                  final hasImg  = url.startsWith('http') && (url.contains('.png') || url.contains('.jpg') || url.contains('.jpeg') || url.contains('.webp'));
                  final isActive = _planActif?['id'] == doc['id'];
                  final pinCount = _defauts.where((d) => d['document_id'] == doc['id']).length;

                  return GestureDetector(
                    onTap: () => setState(() => _planActif = isActive ? null : doc),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: cardW,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive ? kAccent : const Color(0xFFE5E7EB),
                          width: isActive ? 2 : 1,
                        ),
                        boxShadow: isActive ? [BoxShadow(color: kAccent.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))] : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // Miniature
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                          child: SizedBox(
                            height: cardW * 0.65,
                            width: cardW,
                            child: hasImg
                                ? Image.network(url, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _PlanPlaceholder(isActive: isActive))
                                : _PlanPlaceholder(isActive: isActive),
                          ),
                        ),
                        // Info
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(nom.isEmpty ? 'Plan sans nom' : nom,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                    color: isActive ? kAccent : kTextMain),
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Row(children: [
                              if (pinCount > 0) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: kRed.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(LucideIcons.mapPin, size: 9, color: kRed),
                                    const SizedBox(width: 3),
                                    Text('$pinCount', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kRed)),
                                  ]),
                                ),
                                const SizedBox(width: 6),
                              ],
                              const Spacer(),
                              if (url.startsWith('http'))
                                GestureDetector(
                                  onTap: () async {
                                    final uri = Uri.tryParse(url);
                                    if (uri != null) try { await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (_) {}
                                  },
                                  child: const Icon(LucideIcons.externalLink, size: 13, color: kTextSub),
                                ),
                            ]),
                          ]),
                        ),
                      ]),
                    ),
                  );
                }).toList());
              }),
              const SizedBox(height: 14),

              // Zone de pointage si un plan est sélectionné
              if (_planActif != null) _buildZonePointage(_planActif!),
            ],
          ]),
        ),

        const SizedBox(height: 16),

        // ── Liste des défauts ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('LISTE DES POINTAGES (${_defauts.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSub, letterSpacing: 0.5)),
              const Spacer(),
              if (_defauts.isNotEmpty) ...[
                _chip('${_defauts.where((d) => d["statut"] == "a_faire").length} à faire', kRed),
                const SizedBox(width: 8),
                _chip('${_defauts.where((d) => d["statut"] == "regle").length} réglés', const Color(0xFF10B981)),
              ],
            ]),
            const SizedBox(height: 12),
            if (_loadingDefauts)
              const Center(child: CircularProgressIndicator(color: kAccent))
            else if (_defauts.isEmpty)
              Container(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Column(children: [Icon(LucideIcons.mapPin, size: 28, color: kTextSub.withOpacity(0.3)), const SizedBox(height: 8), const Text('Aucun pointage', style: TextStyle(color: kTextSub, fontSize: 13))])))
            else
              ..._defauts.map((d) {
                final estFait = d['statut'] == 'regle';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: estFait ? const Color(0xFFF0FDF4) : Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: estFait ? const Color(0xFF10B981).withOpacity(0.3) : const Color(0xFFE5E7EB))),
                  child: Row(children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(color: estFait ? const Color(0xFF10B981) : kRed, borderRadius: BorderRadius.circular(8)),
                      child: Icon(estFait ? LucideIcons.checkCircle : LucideIcons.alertCircle, size: 16, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d['titre'] ?? '', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: estFait ? kTextSub : kTextMain, decoration: estFait ? TextDecoration.lineThrough : null)),
                      const SizedBox(height: 2),
                      Row(children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(4)), child: Text(d['document_nom'] ?? '', style: const TextStyle(fontSize: 9, color: kTextSub, fontWeight: FontWeight.w600))),
                        const SizedBox(width: 6),
                        Text(_formatDate(d['created_at'] ?? ''), style: const TextStyle(fontSize: 10, color: kTextSub)),
                      ]),
                    ])),
                    PopupMenuButton<String>(
                      onSelected: (v) { if (v == 'toggle') _toggleDefautStatut(d); if (v == 'delete') _supprimerDefaut(d); },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'toggle', child: Row(children: [Icon(estFait ? LucideIcons.rotateCcw : LucideIcons.checkCircle, size: 13, color: const Color(0xFF10B981)), const SizedBox(width: 8), Text(estFait ? 'Marquer à faire' : 'Marquer réglé')])),
                        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(LucideIcons.trash2, size: 13, color: kRed), SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: kRed))])),
                      ],
                      child: const Padding(padding: EdgeInsets.all(4), child: Icon(LucideIcons.moreVertical, size: 15, color: kTextSub)),
                    ),
                  ]),
                );
              }),
          ]),
        ),
      ]),
    );
  }

  Widget _buildZonePointage(Map<String, dynamic> doc) {
    final nomRaw = (doc['nom'] as String? ?? '');
    final nom    = nomRaw.contains('||META||') ? nomRaw.split('||META||')[0]
                 : nomRaw.contains('')     ? nomRaw.split('')[0]
                 : nomRaw;
    final defautsDuDoc = _defauts.where((d) => d['document_id'] == doc['id']).toList();

    return LayoutBuilder(builder: (ctx, cs) {
      final W = cs.maxWidth;
      final H = W * 0.6;
      return Container(
        width: W, height: H,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kAccent.withOpacity(0.3)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(children: [
            // Fond : image réelle si disponible, sinon plan générique
            if ((doc['url'] as String? ?? '').startsWith('http'))
              Positioned.fill(child: Image.network(
                doc['url'] as String,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => CustomPaint(painter: _FloorPlanPainter(), size: Size(W, H)),
              ))
            else
              CustomPaint(painter: _FloorPlanPainter(), size: Size(W, H)),
            // Indicateur
            Positioned(bottom: 8, left: 0, right: 0, child: Center(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(20)),
              child: Text('Tap sur le plan pour ajouter un pointage — $nom', style: const TextStyle(color: Colors.white, fontSize: 10)),
            ))),
            // Zone de clic
            Positioned.fill(child: GestureDetector(onTapDown: (d) {
              final rx = (d.localPosition.dx / W).clamp(0.0, 1.0);
              final ry = (d.localPosition.dy / H).clamp(0.0, 1.0);
              _showAddDefautDialog(rx, ry, doc['id'], nom);
            })),
            // Pins existants
            ...defautsDuDoc.asMap().entries.map((e) {
              final i = e.key; final def = e.value;
              final x = ((def['x'] as num? ?? 0).toDouble() * W) - 14;
              final y = ((def['y'] as num? ?? 0).toDouble() * H) - 14;
              final estFait = def['statut'] == 'regle';
              return Positioned(left: x, top: y, child: GestureDetector(
                onTap: () => _snack(context, def['titre'] ?? '', estFait ? const Color(0xFF10B981) : kRed),
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: estFait ? const Color(0xFF10B981) : kRed,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: (estFait ? const Color(0xFF10B981) : kRed).withOpacity(0.4), blurRadius: 6)],
                  ),
                  child: Center(child: Text('${i+1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))),
                ),
              ));
            }),
          ]),
        ),
      );
    });
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
  );

  // ── GALERIE ───────────────────────────────────────────────────────────────
  Widget _buildGalerie(double pad) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(pad, 16, pad, pad + 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Galerie du chantier', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextMain)),
            const Spacer(),
            if (_photos.isNotEmpty) Text('${_photos.length} photo(s)', style: const TextStyle(color: kTextSub, fontSize: 12)),
          ]),
          const SizedBox(height: 4),
          const Text('Photos classées de la plus récente à la plus ancienne', style: TextStyle(color: kTextSub, fontSize: 11)),
          const SizedBox(height: 16),
          if (_loadingPhotos)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: kAccent)))
          else if (_photos.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 50),
              child: Column(children: [
                Container(width: 64, height: 64, decoration: BoxDecoration(color: kAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(16)), child: Icon(LucideIcons.image, size: 28, color: kAccent.withOpacity(0.5))),
                const SizedBox(height: 14),
                const Text('Aucune photo', style: TextStyle(color: kTextMain, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('Cliquez sur "Ajouter" pour uploader des photos', style: TextStyle(color: kTextSub, fontSize: 12)),
              ]),
            )
          else
            LayoutBuilder(builder: (ctx, cs) {
              final cols = cs.maxWidth > 600 ? 3 : 2;
              final rows = <Widget>[];
              for (int i = 0; i < _photos.length; i += cols) {
                final rowItems = _photos.skip(i).take(cols).toList();
                rows.add(Row(children: [
                  for (int j = 0; j < rowItems.length; j++) ...[
                    if (j > 0) const SizedBox(width: 10),
                    Expanded(child: _PhotoCard(photo: rowItems[j], onDelete: () => _supprimerPhoto(rowItems[j]))),
                  ],
                  if (rowItems.length < cols) ...[const SizedBox(width: 10), const Expanded(child: SizedBox())],
                ]));
                if (i + cols < _photos.length) rows.add(const SizedBox(height: 10));
              }
              return Column(children: rows);
            }),
        ]),
      ),
    );
  }

  // ── CRC & ACTUALITÉS ─────────────────────────────────────────────────────
  Widget _buildCRC(double pad) {
    final typeColors = {
      'Progrès':  const Color(0xFF10B981),
      'Problème': kRed,
      'Décision': const Color(0xFF8B5CF6),
      'Livraison':const Color(0xFF3B82F6),
      'Sécurité': const Color(0xFFF59E0B),
      'Note':     const Color(0xFF6B7280),
    };

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(pad, 16, pad, pad + 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── DIFFÉRENCE CRC vs ACTUALITÉ ──────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle)), const SizedBox(width: 6), const Text('Rapport CRC', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF3B82F6)))]),
              const SizedBox(height: 4),
              const Text('Document officiel avec statut du chantier. Partagé avec le client.', style: TextStyle(fontSize: 11, color: kTextSub)),
            ])),
            Container(width: 1, height: 40, color: const Color(0xFFE5E7EB), margin: const EdgeInsets.symmetric(horizontal: 16)),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)), const SizedBox(width: 6), const Text("Fil d'actualité", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF10B981)))]),
              const SizedBox(height: 4),
              const Text("Note rapide informelle. Observation terrain, info d'avancement.", style: TextStyle(fontSize: 11, color: kTextSub)),
            ])),
          ]),
        ),

        const SizedBox(height: 16),

        // ── RAPPORTS CRC ─────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle)),
              const SizedBox(width: 8),
              const Text('Comptes-Rendus de Chantier (CRC)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextMain)),
              const Spacer(),
              Text('${_crcs.length} rapport(s)', style: const TextStyle(color: kTextSub, fontSize: 12)),
            ]),
            const SizedBox(height: 14),
            if (_loadingCRC)
              const Center(child: CircularProgressIndicator(color: kAccent))
            else if (_crcs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10)),
                child: Column(children: [Icon(LucideIcons.clipboardList, size: 28, color: kTextSub.withOpacity(0.3)), const SizedBox(height: 8), const Text('Aucun rapport CRC', style: TextStyle(color: kTextSub, fontSize: 13))]),
              )
            else
              ..._crcs.map((crc) {
                final statColor = _crcColor(crc['statut'] ?? 'conforme');
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(LucideIcons.fileText, size: 16, color: Color(0xFF3B82F6))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(crc['titre'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextMain)),
                        Text('${_formatDate(crc['created_at'] ?? '')}  •  Par ${crc['auteur'] ?? ''}', style: const TextStyle(fontSize: 11, color: kTextSub)),
                      ])),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: statColor, borderRadius: BorderRadius.circular(20)), child: Text(_crcLabel(crc['statut'] ?? 'conforme'), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                    ]),
                    if ((crc['contenu'] as String? ?? '').isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Divider(height: 1, color: Color(0xFFE5E7EB)),
                      const SizedBox(height: 10),
                      Text(crc['contenu'] ?? '', style: const TextStyle(fontSize: 12, color: kTextSub, height: 1.5)),
                    ],
                  ]),
                );
              }),
          ]),
        ),

        const SizedBox(height: 16),

        // ── FIL D'ACTUALITÉ ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
              const SizedBox(width: 8),
              const Text("Fil d'actualité du chantier", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextMain)),
              const Spacer(),
              Text('${_actualites.length} note(s)', style: const TextStyle(color: kTextSub, fontSize: 12)),
            ]),
            const SizedBox(height: 14),
            if (_loadingCRC)
              const Center(child: CircularProgressIndicator(color: kAccent))
            else if (_actualites.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10)),
                child: Column(children: [Icon(LucideIcons.rss, size: 28, color: kTextSub.withOpacity(0.3)), const SizedBox(height: 8), const Text('Aucune actualité publiée', style: TextStyle(color: kTextSub, fontSize: 13))]),
              )
            else
              ...(_actualites.asMap().entries.map((e) {
                final i = e.key; final a = e.value;
                final isLast = i == _actualites.length - 1;
                final color = typeColors[a['type'] ?? 'Note'] ?? const Color(0xFF6B7280);
                return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Column(children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    if (!isLast) Expanded(child: Container(width: 2, color: const Color(0xFFE5E7EB))),
                  ]),
                  const SizedBox(width: 14),
                  Expanded(child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE5E7EB))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.3))), child: Text(a['type'] ?? 'Note', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color))),
                          const Spacer(),
                          Text(_formatDate(a['created_at'] ?? ''), style: const TextStyle(fontSize: 11, color: kTextSub)),
                        ]),
                        const SizedBox(height: 8),
                        Text(a['contenu'] ?? '', style: const TextStyle(fontSize: 13, color: kTextMain, height: 1.4)),
                        const SizedBox(height: 6),
                        Text('Par ${a['auteur'] ?? ''}', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  )),
                ]));
              })),
          ]),
        ),
      ]),
    );
  }
}

// ── Painters & Cards ─────────────────────────────────────────────────────────
class _PlanPlaceholder extends StatelessWidget {
  final bool isActive;
  const _PlanPlaceholder({this.isActive = false});
  @override
  Widget build(BuildContext context) => Container(
    color: isActive ? kAccent.withOpacity(0.08) : const Color(0xFFF3F4F6),
    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(LucideIcons.penTool, size: 24, color: isActive ? kAccent.withOpacity(0.5) : kTextSub.withOpacity(0.3)),
      const SizedBox(height: 6),
      Text('Plan', style: TextStyle(fontSize: 10, color: isActive ? kAccent.withOpacity(0.6) : kTextSub.withOpacity(0.4), fontWeight: FontWeight.w600)),
    ])),
  );
}

class _FloorPlanPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF374151)..strokeWidth = 2..style = PaintingStyle.stroke;
    final fill  = Paint()..color = const Color(0xFFE5E7EB)..style = PaintingStyle.fill;
    final w = size.width; final h = size.height;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFFF9FAFB));
    final outer = RRect.fromRectAndRadius(Rect.fromLTRB(w*0.05, h*0.05, w*0.95, h*0.95), const Radius.circular(4));
    canvas.drawRRect(outer, fill); canvas.drawRRect(outer, paint);
    canvas.drawRect(Rect.fromLTRB(w*0.07, h*0.07, w*0.52, h*0.93), paint);
    canvas.drawRect(Rect.fromLTRB(w*0.52, h*0.07, w*0.93, h*0.52), paint);
    canvas.drawRect(Rect.fromLTRB(w*0.52, h*0.52, w*0.93, h*0.93), paint);
    final dp = Paint()..color = const Color(0xFF6B7280)..strokeWidth = 1.5..style = PaintingStyle.stroke;
    canvas.drawArc(Rect.fromCircle(center: Offset(w*0.52, h*0.36), radius: h*0.11), -1.57, 1.57, false, dp);
    canvas.drawLine(Offset(w*0.52, h*0.36), Offset(w*0.52, h*0.36-h*0.11), dp);
    final wp = Paint()..color = const Color(0xFF93C5FD)..strokeWidth = 3..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w*0.63, h*0.07), Offset(w*0.78, h*0.07), wp);
    final sp = Paint()..color = const Color(0xFF9CA3AF)..strokeWidth = 1..style = PaintingStyle.stroke;
    canvas.drawOval(Rect.fromCenter(center: Offset(w*0.72, h*0.76), width: w*0.10, height: h*0.14), sp);
  }
  @override bool shouldRepaint(_) => false;
}

class _PhotoCard extends StatelessWidget {
  final Map<String, dynamic> photo;
  final VoidCallback onDelete;
  const _PhotoCard({required this.photo, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final url  = photo['url']  as String? ?? '';
    final nom  = photo['nom']  as String? ?? '';
    final date = photo['uploaded_at'] as String? ?? '';
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
      clipBehavior: Clip.hardEdge,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(
          aspectRatio: 4/3,
          child: url.isNotEmpty && !url.startsWith('fichier:')
              ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: const Color(0xFFF3F4F6), child: const Icon(LucideIcons.image, size: 32, color: kTextSub)))
              : Container(color: const Color(0xFFF3F4F6), child: const Icon(LucideIcons.image, size: 32, color: kTextSub)),
        ),
        Padding(padding: const EdgeInsets.all(10), child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nom, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kTextMain), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(_formatDate(date), style: const TextStyle(fontSize: 10, color: kTextSub)),
          ])),
          GestureDetector(onTap: onDelete, child: Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(6)), child: const Icon(LucideIcons.trash2, size: 12, color: kRed))),
        ])),
      ]),
    );
  }

  static String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      const m = ['jan','fév','mars','avr','mai','juin','juil','août','sept','oct','nov','déc'];
      return '${d.day} ${m[d.month-1]} ${d.year}';
    } catch (_) { return iso.length > 10 ? iso.substring(0, 10) : iso; }
  }
}


class _Modele3DTab extends StatefulWidget {
  final Project project;
  const _Modele3DTab({required this.project});
  @override State<_Modele3DTab> createState() => _Modele3DTabState();
}
class _Modele3DTabState extends State<_Modele3DTab> {
  Model3D? _model;
  bool _loading = true;
  bool _uploading = false;
  WebViewController? _viewerCtrl;
  final Set<String> _highlighted = {};

  @override
  void initState() { super.initState(); _loadModel(); }

  Future<void> _loadModel() async {
    try {
      final m = await Model3DService.getModel(widget.project.id);
      setState(() { _model = m; _loading = false; });
      if (m != null) _initViewer(m.url);
    } catch (_) { setState(() => _loading = false); }
  }

  void _initViewer(String url) {
    final ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('FlutterChannel', onMessageReceived: (msg) {
        try {
          final data = jsonDecode(msg.message) as Map<String, dynamic>;
          if (data['type'] == 'meshClicked') _onMeshClicked(data['name'] as String);
        } catch (_) {}
      })
      ..loadHtmlString(_buildFullViewerHtml(url));
    setState(() { _viewerCtrl = ctrl; _highlighted.clear(); });
  }

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['glb'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || result.files.first.bytes == null) return;
    final file = result.files.first;
    setState(() => _uploading = true);
    try {
      final url = await Model3DService.uploadGlb(widget.project.id, file.bytes!, file.name);
      final meshNames = GlbParser.extractMeshNames(file.bytes!);
      final model = await Model3DService.saveModel(widget.project.id, url, meshNames);
      setState(() { _model = model; _uploading = false; });
      _initViewer(url);
      if (mounted) _snack(context, '✓ Modèle chargé — ${meshNames.length} mesh(es) détectés', kAccent);
    } catch (e) {
      setState(() => _uploading = false);
      if (mounted) _snack(context, 'Erreur upload: $e', kRed);
    }
  }

  Future<void> _deleteModel() async {
    await Model3DService.deleteModel(widget.project.id);
    setState(() { _model = null; _viewerCtrl = null; _highlighted.clear(); });
  }

  void _toggleHighlight(String name) {
    setState(() {
      if (_highlighted.contains(name)) _highlighted.remove(name);
      else _highlighted.add(name);
    });
    _viewerCtrl?.runJavaScript('highlightMeshes(${jsonEncode(_highlighted.toList())});');
    if (_highlighted.contains(name)) {
      _viewerCtrl?.runJavaScript('zoomToMesh(${jsonEncode(name)});');
    }
  }

  void _onMeshClicked(String name) {
    _toggleHighlight(name);
    if (!mounted) return;
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(LucideIcons.box, size: 16, color: kAccent)),
        const SizedBox(width: 12),
        const Text('Partie sélectionnée', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextMain)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3))),
          child: Row(children: [const Icon(LucideIcons.checkCircle, size: 14, color: Color(0xFF10B981)), const SizedBox(width: 8), Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: kTextMain)))])),
        const SizedBox(height: 8),
        Text(_highlighted.contains(name) ? '✓ Surbrillance activée' : 'Surbrillance désactivée', style: TextStyle(fontSize: 12, color: _highlighted.contains(name) ? const Color(0xFF10B981) : kTextSub)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK', style: TextStyle(color: kAccent, fontWeight: FontWeight.w700)))],
    ));
  }

  String _buildFullViewerHtml(String url) {
    final safeUrl = url.replaceAll("'", "\\'");
    return '''<!DOCTYPE html><html><head><meta charset="utf-8">
<style>*{margin:0;padding:0;box-sizing:border-box}body{background:#1F2937;overflow:hidden}
#load{position:fixed;top:50%;left:50%;transform:translate(-50%,-50%);color:#9CA3AF;font-family:Arial;font-size:13px;text-align:center}
#hint{position:fixed;bottom:12px;left:50%;transform:translateX(-50%);color:rgba(255,255,255,0.5);font-family:Arial;font-size:11px;pointer-events:none}
</style></head><body>
<div id="load">⏳ Chargement du modèle 3D...</div>
<div id="hint">Cliquez sur une partie pour la sélectionner · Faites glisser pour pivoter</div>
<script type="importmap">{"imports":{"three":"https://cdn.jsdelivr.net/npm/three@0.158.0/build/three.module.js","three/addons/":"https://cdn.jsdelivr.net/npm/three@0.158.0/examples/jsm/"}}</script>
<script type="module">
import * as THREE from 'three';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
window._pendingClicks=[];
const scene=new THREE.Scene();scene.background=new THREE.Color(0x1F2937);
const camera=new THREE.PerspectiveCamera(45,innerWidth/innerHeight,0.01,1000);
const renderer=new THREE.WebGLRenderer({antialias:true});
renderer.setPixelRatio(devicePixelRatio);renderer.setSize(innerWidth,innerHeight);
document.body.appendChild(renderer.domElement);
const ctrl=new OrbitControls(camera,renderer.domElement);ctrl.enableDamping=true;
scene.add(new THREE.AmbientLight(0xffffff,0.8));
const dl=new THREE.DirectionalLight(0xffffff,0.9);dl.position.set(10,10,5);scene.add(dl);
const meshMap={},origMat={};
new GLTFLoader().load('$safeUrl',gltf=>{
  document.getElementById('load').style.display='none';
  scene.add(gltf.scene);
  const box=new THREE.Box3().setFromObject(gltf.scene);
  const ctr=box.getCenter(new THREE.Vector3()),sz=box.getSize(new THREE.Vector3());
  const mx=Math.max(sz.x,sz.y,sz.z)||1;
  gltf.scene.position.sub(ctr);camera.position.set(mx*1.5,mx,mx*1.5);ctrl.target.set(0,0,0);ctrl.update();
  gltf.scene.traverse(o=>{if(o.isMesh){const n=o.name||'Mesh_'+Object.keys(meshMap).length;o.name=n;meshMap[n]=o;origMat[n]=Array.isArray(o.material)?o.material.map(m=>m.clone()):o.material?o.material.clone():new THREE.MeshStandardMaterial();}});
  const names=Object.keys(meshMap);
  if(window.FlutterChannel)window.FlutterChannel.postMessage(JSON.stringify({type:'meshList',names}));
  window.parent&&window.parent.postMessage(JSON.stringify({type:'meshList',names}),'*');
},undefined,e=>document.getElementById('load').textContent='Erreur: '+e.message);
window.highlightMeshes=ns=>{
  const s=new Set(ns);
  Object.entries(meshMap).forEach(([n,m])=>{const o=origMat[n];m.material=Array.isArray(o)?o.map(x=>x.clone()):o?o.clone():new THREE.MeshStandardMaterial();});
  s.forEach(n=>{if(meshMap[n])meshMap[n].material=new THREE.MeshStandardMaterial({color:0x3B82F6,emissive:0x1d4ed8,emissiveIntensity:0.4,transparent:true,opacity:0.9});});
};
window.zoomToMesh=n=>{const m=meshMap[n];if(!m)return;const b=new THREE.Box3().setFromObject(m);const c=b.getCenter(new THREE.Vector3());const s=b.getSize(new THREE.Vector3());const mx=Math.max(s.x,s.y,s.z)||1;ctrl.target.copy(c);camera.position.set(c.x+mx*2,c.y+mx,c.z+mx*2);ctrl.update();};
const ray=new THREE.Raycaster(),mouse=new THREE.Vector2();
renderer.domElement.addEventListener('click',e=>{
  const r=renderer.domElement.getBoundingClientRect();
  mouse.x=((e.clientX-r.left)/r.width)*2-1;mouse.y=-((e.clientY-r.top)/r.height)*2+1;
  ray.setFromCamera(mouse,camera);
  const hits=ray.intersectObjects(Object.values(meshMap),false);
  if(hits.length){const name=hits[0].object.name;window._pendingClicks.push(name);
  if(window.FlutterChannel)window.FlutterChannel.postMessage(JSON.stringify({type:'meshClicked',name}));
  window.parent&&window.parent.postMessage(JSON.stringify({type:'meshClicked',name}),'*');}
});
window.addEventListener('resize',()=>{camera.aspect=innerWidth/innerHeight;camera.updateProjectionMatrix();renderer.setSize(innerWidth,innerHeight);});
(function animate(){requestAnimationFrame(animate);ctrl.update();renderer.render(scene,camera);}());
</script></body></html>''';
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final pad = isMobile ? 16.0 : 28.0;

    if (_loading) return const Center(child: CircularProgressIndicator(color: kAccent));

    // ── Viewer + mesh panel layout ────────────────────────────────────────
    if (_model != null && _viewerCtrl != null) {
      return Column(children: [
        // Toolbar
        Container(
          padding: EdgeInsets.symmetric(horizontal: pad, vertical: 12),
          color: kCardBg,
          child: Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(LucideIcons.box, size: 16, color: kAccent)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Maquette numérique 3D', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kTextMain)),
              Text('${_model!.meshNames.length} mesh(es) · cliquez pour sélectionner', style: const TextStyle(color: kTextSub, fontSize: 11)),
            ])),
            if (_highlighted.isNotEmpty)
              Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: kAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text('${_highlighted.length} sél.', style: const TextStyle(color: kAccent, fontSize: 11, fontWeight: FontWeight.w700))),
            if (_highlighted.isNotEmpty)
              IconButton(icon: const Icon(LucideIcons.x, size: 14, color: kTextSub), tooltip: 'Tout désélectionner', onPressed: () { setState(() => _highlighted.clear()); _viewerCtrl?.runJavaScript('highlightMeshes([]);'); }),
            const SizedBox(width: 4),
            ElevatedButton.icon(
              onPressed: _uploading ? null : _upload,
              icon: _uploading ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(LucideIcons.upload, size: 13, color: Colors.white),
              label: const Text('Remplacer', style: TextStyle(color: Colors.white, fontSize: 12)),
              style: ElevatedButton.styleFrom(backgroundColor: kAccent, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            ),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(LucideIcons.trash2, size: 16, color: kRed), tooltip: 'Supprimer le modèle', onPressed: () async {
              final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
                title: const Text('Supprimer le modèle ?'),
                content: const Text('Cette action est irréversible.'),
                actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer', style: TextStyle(color: kRed)))],
              ));
              if (ok == true) _deleteModel();
            }),
          ]),
        ),
        // Main area: 3D viewer + mesh list panel
        Expanded(child: isMobile
          ? Column(children: [
              Expanded(child: WebViewWidget(controller: _viewerCtrl!)),
              _buildMeshPanel(),
            ])
          : Row(children: [
              Expanded(child: WebViewWidget(controller: _viewerCtrl!)),
              _buildMeshPanel(),
            ]),
        ),
      ]);
    }

    // ── Empty state: upload prompt ────────────────────────────────────────
    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const SizedBox(height: 40),
          Container(width: 80, height: 80, decoration: BoxDecoration(color: kAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(20)), child: Icon(LucideIcons.box, size: 36, color: kAccent.withOpacity(0.6))),
          const SizedBox(height: 20),
          const Text('Aucun modèle 3D', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kTextMain)),
          const SizedBox(height: 8),
          const Text('Uploadez un fichier .glb avec des meshes nommés (ex: Wall_Salon, Door_Main, Roof) pour activer la sélection par parties.', style: TextStyle(color: kTextSub, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _uploading ? null : _upload,
            icon: _uploading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(LucideIcons.upload, size: 16, color: Colors.white),
            label: Text(_uploading ? 'Upload en cours...' : 'Uploader un modèle .glb', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            style: ElevatedButton.styleFrom(backgroundColor: kAccent, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          ),
          const SizedBox(height: 28),
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Convention de nommage recommandée', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: kTextMain)),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final n in ['Wall_Salon', 'Wall_Chambre', 'Door_Main', 'Door_Garage', 'Roof', 'Floor_RDC', 'Floor_R1', 'Window_Sud', 'Stairs', 'Facade_Nord'])
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5E7EB))), child: Text(n, style: const TextStyle(fontSize: 11, color: kTextSub, fontFamily: 'monospace'))),
            ]),
          ])),
        ]),
      )),
    );
  }

  Widget _buildMeshPanel() {
    final meshNames = _model?.meshNames ?? [];
    return Container(
      width: 240,
      decoration: const BoxDecoration(color: Color(0xFFF9FAFB), border: Border(left: BorderSide(color: Color(0xFFE5E7EB)))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('PARTIES DU BÂTIMENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kTextSub, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          const Text('Cliquez sur le modèle ou sur un chip pour surligner.', style: TextStyle(fontSize: 10, color: kTextSub)),
        ])),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        Expanded(child: meshNames.isEmpty
          ? const Center(child: Text('Aucun mesh nommé\ndétecté', style: TextStyle(color: kTextSub, fontSize: 12), textAlign: TextAlign.center))
          : ListView(padding: const EdgeInsets.all(12), children: [
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final name in meshNames)
                  GestureDetector(
                    onTap: () => _toggleHighlight(name),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _highlighted.contains(name) ? kAccent : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _highlighted.contains(name) ? kAccent : const Color(0xFFE5E7EB)),
                      ),
                      child: Text(name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _highlighted.contains(name) ? Colors.white : kTextSub)),
                    ),
                  ),
              ]),
            ]),
        ),
      ]),
    );
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
  List<Commentaire> commentaires = [];
  bool loading = true;
  Commentaire? _replyingTo;
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();

  @override void initState() { super.initState(); _load(); }
  @override void dispose()   { _ctrl.dispose(); _scroll.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final data = await CommentaireService.getCommentaires(widget.project.id);
      setState(() { commentaires = data; loading = false; });
      widget.onCountChanged(data.length);
      Future.delayed(const Duration(milliseconds: 120), () {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    } catch (_) { setState(() => loading = false); }
  }

  Future<void> _send() async {
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) { _snack(context, 'Message vide', kRed); return; }
    final contenu = _replyingTo != null
        ? '↩ En réponse à "${_replyingTo!.auteur}" :\n« ${_replyingTo!.contenu.length > 80 ? '${_replyingTo!.contenu.substring(0, 80)}…' : _replyingTo!.contenu} »\n\n$raw'
        : raw;
    _ctrl.clear();
    setState(() => _replyingTo = null);
    final nom = AuthService.currentUser?.fullName;
    final auteur = (nom != null && nom.isNotEmpty) ? nom : (widget.project.chef.isNotEmpty ? widget.project.chef : 'Architecte');
    await CommentaireService.addCommentaire(Commentaire(
      id: '', projetId: widget.project.id,
      auteur: auteur, role: 'architecte',
      contenu: contenu, createdAt: DateTime.now().toIso8601String(),
    ));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final pad = isMobile ? 16.0 : 28.0;
    if (loading) return const Center(child: CircularProgressIndicator(color: kAccent));

    final clientCount = commentaires.where((c) => c.role == 'client').length;
    final archiCount  = commentaires.where((c) => c.role == 'architecte').length;

    return Padding(padding: EdgeInsets.all(pad), child: Column(children: [
      // ── Stats header ────────────────────────────────────────────────────
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
        child: Row(children: [
          const Icon(LucideIcons.messageSquare, size: 15, color: kTextSub),
          const SizedBox(width: 8),
          const Text('Fil de discussion', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kTextMain)),
          const Spacer(),
          _ConvBadge(label: 'Client', count: clientCount, color: const Color(0xFF8B5CF6)),
          const SizedBox(width: 8),
          _ConvBadge(label: 'Architecte', count: archiCount, color: kAccent),
        ]),
      ),

      // ── Message list ────────────────────────────────────────────────────
      Expanded(child: Container(
        decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
        child: commentaires.isEmpty
          ? _EmptyState(icon: LucideIcons.messageCircle, message: 'Aucun message pour ce projet')
          : ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: commentaires.length,
              itemBuilder: (_, i) => _BubbleRow(
                commentaire: commentaires[i],
                onReply: (c) => setState(() {
                  _replyingTo = c;
                  Future.delayed(const Duration(milliseconds: 50), () => FocusScope.of(context).unfocus());
                }),
              ),
            ),
      )),

      // ── Reply banner ────────────────────────────────────────────────────
      if (_replyingTo != null)
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F3FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
          ),
          child: Row(children: [
            const Icon(LucideIcons.cornerDownRight, size: 13, color: Color(0xFF8B5CF6)),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Réponse à ${_replyingTo!.auteur} : «${_replyingTo!.contenu.length > 60 ? '${_replyingTo!.contenu.substring(0, 60)}…' : _replyingTo!.contenu}»',
              style: const TextStyle(fontSize: 11, color: Color(0xFF8B5CF6), fontStyle: FontStyle.italic),
              overflow: TextOverflow.ellipsis,
            )),
            GestureDetector(
              onTap: () => setState(() => _replyingTo = null),
              child: const Icon(LucideIcons.x, size: 13, color: Color(0xFF8B5CF6)),
            ),
          ]),
        ),

      // ── Text input ──────────────────────────────────────────────────────
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
        child: Row(children: [
          Container(width: 30, height: 30, decoration: BoxDecoration(color: kAccent.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(LucideIcons.user, size: 13, color: kAccent)),
          const SizedBox(width: 10),
          Expanded(child: TextField(
            controller: _ctrl,
            onSubmitted: (_) => _send(),
            style: const TextStyle(fontSize: 13, color: kTextMain),
            decoration: InputDecoration(
              hintText: _replyingTo != null ? 'Votre réponse...' : 'Répondre au client...',
              hintStyle: const TextStyle(color: kTextSub),
              border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
            ),
          )),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
            ),
          ),
        ]),
      ),
    ]));
  }
}

class _ConvBadge extends StatelessWidget {
  final String label; final int count; final Color color;
  const _ConvBadge({required this.label, required this.count, required this.color});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 5),
    Text('$label ($count)', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  ]);
}

class _BubbleRow extends StatelessWidget {
  final Commentaire commentaire;
  final void Function(Commentaire) onReply;
  const _BubbleRow({required this.commentaire, required this.onReply});

  @override
  Widget build(BuildContext context) {
    final isArchi = commentaire.role == 'architecte';
    final isReply = commentaire.contenu.startsWith('↩ En réponse à');

    // Split quoted part from actual reply
    String? quotePart;
    String mainContent = commentaire.contenu;
    if (isArchi && isReply) {
      final parts = commentaire.contenu.split('\n\n');
      if (parts.length >= 2) {
        quotePart = parts.sublist(0, parts.length - 1).join('\n\n');
        mainContent = parts.last;
      }
    }

    final bubbleColor    = isArchi ? kAccent : const Color(0xFF8B5CF6);
    final bgColor        = isArchi ? kAccent : const Color(0xFFF5F3FF);
    final textColor      = isArchi ? Colors.white : const Color(0xFF1F2937);
    final badgeLabel     = isArchi ? 'ARCHITECTE' : 'CLIENT';
    final badgeColor     = isArchi ? kAccent.withOpacity(0.1) : const Color(0xFF8B5CF6).withOpacity(0.1);
    final badgeTextColor = isArchi ? kAccent : const Color(0xFF8B5CF6);

    final dateStr = commentaire.createdAt.length >= 10
        ? commentaire.createdAt.substring(0, 10)
        : commentaire.createdAt;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: isArchi ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
        // Author row
        Row(
          mainAxisAlignment: isArchi ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isArchi) ...[
              Container(width: 28, height: 28, decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.12), shape: BoxShape.circle), child: const Icon(LucideIcons.user, size: 13, color: Color(0xFF8B5CF6))),
              const SizedBox(width: 8),
            ],
            Text(commentaire.auteur, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: kTextMain)),
            const SizedBox(width: 6),
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(4)), child: Text(badgeLabel, style: TextStyle(color: badgeTextColor, fontSize: 9, fontWeight: FontWeight.w800))),
            const SizedBox(width: 6),
            Text(dateStr, style: const TextStyle(color: kTextSub, fontSize: 10)),
            if (isArchi) ...[
              const SizedBox(width: 8),
              Container(width: 28, height: 28, decoration: BoxDecoration(color: kAccent.withOpacity(0.12), shape: BoxShape.circle), child: const Icon(LucideIcons.hardHat, size: 13, color: kAccent)),
            ],
          ],
        ),
        const SizedBox(height: 6),
        // Bubble
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.only(
                topLeft:     const Radius.circular(14),
                topRight:    const Radius.circular(14),
                bottomLeft:  Radius.circular(isArchi ? 14 : 0),
                bottomRight: Radius.circular(isArchi ? 0 : 14),
              ),
              boxShadow: [BoxShadow(color: bubbleColor.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Quote block (for architect replies)
              if (quotePart != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: const Border(left: BorderSide(color: Colors.white54, width: 3)),
                  ),
                  child: Text(quotePart, style: const TextStyle(fontSize: 11, color: Colors.white70, fontStyle: FontStyle.italic, height: 1.3)),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Text(mainContent, style: TextStyle(color: textColor, fontSize: 13, height: 1.4)),
              ),
            ]),
          ),
        ),
        // Reply button (only on client messages)
        if (!isArchi) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => onReply(commentaire),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(LucideIcons.cornerDownRight, size: 12, color: kTextSub),
              const SizedBox(width: 4),
              const Text('Répondre', style: TextStyle(fontSize: 11, color: kTextSub, fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      ]),
    );
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
class _AccessToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const _AccessToggle({required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Transform.scale(scale: 0.85, child: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: kAccent,
      )),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        const Text('Portail client', style: TextStyle(color: kTextSub, fontSize: 12, fontWeight: FontWeight.w600)),
        Text(value ? 'Activé' : 'Désactivé', style: TextStyle(color: value ? const Color(0xFF10B981) : kTextSub, fontSize: 10)),
      ]),
    ]),
  );
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