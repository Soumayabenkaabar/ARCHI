import 'package:archi_manager/service/membre_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../constants/colors.dart';
import '../models/conge.dart';
import '../models/membre.dart';
import '../models/project.dart';
import '../service/conge_service.dart';
import '../service/projet_service.dart';
import '../widgets/membre_card.dart';

// ── Listes métier ──────────────────────────────────────────────────────────
const List<String> kRolesArchitecture = [
  "Architecte",
  "Architecte d'intérieur",
  "Ingénieur structure",
  "Ingénieur électrique",
  "Ingénieur climatisation / CVC",
  "Ingénieur plomberie",
  "Ingénieur VRD",
  "Dessinateur / Projeteur",
  "Chef de chantier",
  "Conducteur de travaux",
  "Économiste de la construction",
  "Géomètre-topographe",
  "Bureau de contrôle",
  "Coordinateur BIM",
  "Autre",
];

class EquipeScreen extends StatefulWidget {
  const EquipeScreen({super.key});
  @override
  State<EquipeScreen> createState() => _EquipeScreenState();
}

class _EquipeScreenState extends State<EquipeScreen> {
  final TextEditingController searchController = TextEditingController();
  List<Membre> membres = [];
  Set<String> _membresEnConge = {};
  Map<String, List<Map<String, dynamic>>> _tachesParMembre = {};
  List<Conge>   _tousLesConges  = [];
  List<Project> _tousLesProjets = [];
  bool isLoading = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadMembres();
  }

  Future<void> loadMembres() async {
    try {
      // Sync projets_assignes depuis membre_taches (source de vérité)
      // avant de charger les données affichées
      await MembreService.syncAllProjetsAssignes();

      final results = await Future.wait([
        MembreService.getMembres(),
        CongeService.getActiveConges(),
        MembreService.getAllMembresTachesForGantt(),
        CongeService.getAllConges(),
        ProjetService.getProjets(),
      ]);
      setState(() {
        membres          = results[0] as List<Membre>;
        _membresEnConge  = (results[1] as List<Conge>).map((c) => c.membreId).toSet();
        _tachesParMembre = results[2] as Map<String, List<Map<String, dynamic>>>;
        _tousLesConges   = results[3] as List<Conge>;
        _tousLesProjets  = results[4] as List<Project>;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur membres: $e');
    }
  }

  Future<void> showAddMembreDialog() async {
    final nomCtrl   = TextEditingController();
    final emailCtrl = TextEditingController();
    final telCtrl   = TextEditingController();
    String? selectedRole;
    bool disponible = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, sd) => _MembreDialog(
          title: 'Nouveau membre',
          subtitle: 'Ajoutez un intervenant à votre équipe',
          icon: LucideIcons.userPlus,
          nomCtrl: nomCtrl,
          emailCtrl: emailCtrl,
          telCtrl: telCtrl,
          selectedRole: selectedRole,
          onRoleChanged: (v) => sd(() => selectedRole = v),
          btnLabel: 'Ajouter le membre',
          btnIcon: LucideIcons.userPlus,
          onSubmit: () async {
            await MembreService.addMembre(Membre(
              id: '',
              nom: nomCtrl.text.trim(),
              role: selectedRole ?? '',
              email: emailCtrl.text.trim(),
              telephone: telCtrl.text.trim(),
              disponible: true,
              projetsAssignes: [],
            ));
            Navigator.pop(context);
            loadMembres();
            _showSnack(context, 'Membre ajouté avec succès', kAccent);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final pad = isMobile ? 16.0 : 28.0;
    if (isLoading)
      return const Center(child: CircularProgressIndicator(color: kAccent));

    final filtered    = membres.where((m) => m.nom.toLowerCase().contains(searchQuery.toLowerCase())).toList();

    return Container(
      color: kBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Titre + bouton ajouter ─────────────────────────────────────
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Gestion de l\'équipe',
                      style: TextStyle(fontSize: isMobile ? 22 : 28, fontWeight: FontWeight.w800, color: kTextMain)),
                  const SizedBox(height: 4),
                  Text('Gérez votre équipe et leurs assignations',
                      style: TextStyle(color: kTextSub, fontSize: isMobile ? 12 : 14)),
                ]),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: showAddMembreDialog,
                icon: const Icon(LucideIcons.userPlus, size: 15, color: Colors.white),
                label: Text(isMobile ? 'Ajouter' : 'Ajouter un membre',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccent, elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 18, vertical: isMobile ? 10 : 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ]),

            const SizedBox(height: 20),

            // ── Recherche ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: kCardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: TextField(
                controller: searchController,
                onChanged: (v) => setState(() => searchQuery = v),
                decoration: const InputDecoration(
                  icon: Icon(LucideIcons.search, size: 18, color: kTextSub),
                  hintText: 'Rechercher un membre...',
                  hintStyle: TextStyle(color: kTextSub),
                  border: InputBorder.none,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── KPI cards ─────────────────────────────────────────────────
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: _StatCard(title: 'Total',       value: '${filtered.length}',       icon: LucideIcons.users,       color: kAccent)),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(title: 'Membres',     value: '${filtered.length}',         icon: LucideIcons.users,       color: const Color(0xFFD97706))),
                const SizedBox(width: 10),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(title: 'En congé',    value: '${_membresEnConge.length}', icon: LucideIcons.umbrella,    color: const Color(0xFFF97316))),
              ]),
            ),

            const SizedBox(height: 24),

            // ── Tableau de synthèse ────────────────────────────────────────
            _SectionTitle(icon: LucideIcons.table2, color: kAccent, label: 'Tableau de synthèse'),
            const SizedBox(height: 14),
            _EquipeTable(membres: filtered, membresEnConge: _membresEnConge, tachesParMembre: _tachesParMembre, projets: _tousLesProjets),

            const SizedBox(height: 24),

            // ── Gantt ──────────────────────────────────────────────────────
            _SectionTitle(icon: LucideIcons.calendar, color: kAccent, label: 'Planning de l\'équipe'),
            const SizedBox(height: 14),
            _GanttView(membres: filtered, tachesParMembre: _tachesParMembre, tousLesConges: _tousLesConges, projets: _tousLesProjets),

            const SizedBox(height: 24),

            // ── Tous les membres ──────────────────────────────────────────
            if (filtered.isNotEmpty) ...[
              _SectionTitle(icon: LucideIcons.users,     color: kAccent, label: 'Membres de l\'équipe'),
              const SizedBox(height: 14),
              ...filtered.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MembreActifRow(
                  membre: m,
                  isEnConge: _membresEnConge.contains(m.id),
                  onView:   () => showViewDialog(context, m),
                  onEdit:   () => showEditDialog(context, m, loadMembres),
                  onConge:  () => showCongeDialog(context, m, loadMembres),
                  onDelete: () async {
                    if (m.id == null) return;
                    await MembreService.deleteMembre(m.id!);
                    _showSnack(context, 'Membre supprimé', kRed);
                    loadMembres();
                  },
                ),
              )),
            ],

            if (filtered.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(children: const [
                    Icon(LucideIcons.users, size: 40, color: kTextSub),
                    SizedBox(height: 12),
                    Text('Aucun membre trouvé',
                        style: TextStyle(color: kTextSub, fontSize: 15, fontWeight: FontWeight.w500)),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  POPUP MODIFIER
// ══════════════════════════════════════════════════════════════════════════════
Future<void> showEditDialog(BuildContext context, Membre membre, VoidCallback onRefresh) async {
  final nomCtrl   = TextEditingController(text: membre.nom);
  final emailCtrl = TextEditingController(text: membre.email);
  final telCtrl   = TextEditingController(text: membre.telephone);
  String? selectedRole       = kRolesArchitecture.contains(membre.role) ? membre.role : null;
  bool disponible = membre.disponible;

  showDialog(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, sd) => _MembreDialog(
        title: 'Modifier le membre',
        subtitle: 'Mettez à jour les informations',
        icon: LucideIcons.pencil,
        iconBg: kAccent.withOpacity(0.12),
        iconColor: kAccent,
        btnColor: kAccent,
        nomCtrl: nomCtrl,
        emailCtrl: emailCtrl,
        telCtrl: telCtrl,
        selectedRole: selectedRole,
        onRoleChanged: (v) => sd(() => selectedRole = v),
        btnLabel: 'Enregistrer',
        btnIcon: LucideIcons.save,
        onSubmit: () async {
          await MembreService.updateMembre(Membre(
            id: membre.id,
            nom: nomCtrl.text.trim(),
            role: selectedRole ?? membre.role,
            email: emailCtrl.text.trim(),
            telephone: telCtrl.text.trim(),
            disponible: membre.disponible,
            projetsAssignes: membre.projetsAssignes,
          ));
          Navigator.pop(context);
          onRefresh();
          _showSnack(context, 'Membre modifié avec succès', kAccent);
        },
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  POPUP VIEW
// ══════════════════════════════════════════════════════════════════════════════
void showViewDialog(BuildContext context, Membre membre) {
  showDialog(context: context, builder: (_) => _ViewDialog(membre: membre));
}

class _ViewDialog extends StatefulWidget {
  final Membre membre;
  const _ViewDialog({required this.membre});
  @override
  State<_ViewDialog> createState() => _ViewDialogState();
}

class _ViewDialogState extends State<_ViewDialog> {
  Map<String, List<Map<String, dynamic>>> _tachesParProjet = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await MembreService.getMembreTachesDetail(widget.membre.id);
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final projTitre = (row['projets'] as Map?)?['titre'] as String? ?? '—';
      grouped.putIfAbsent(projTitre, () => []).add({
        'titre':  (row['taches'] as Map?)?['titre']  as String? ?? '',
        'statut': (row['taches'] as Map?)?['statut'] as String? ?? '',
      });
    }
    if (mounted) setState(() { _tachesParProjet = grouped; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final membre = widget.membre;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 640),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            decoration: const BoxDecoration(
              color: kAccent,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Row(children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(25)),
                child: const Icon(LucideIcons.user, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(membre.nom,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Colors.white),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(membre.role, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
              ])),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(20)),
                child: Text(membre.disponible ? 'Disponible' : 'En activité',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _InfoTile(icon: LucideIcons.mail,      label: 'Email',       value: membre.email,       color: kAccent),
                _InfoTile(icon: LucideIcons.phone,     label: 'Téléphone',   value: membre.telephone,   color: kAccent),
                if (_loading)
                  const Center(child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ))
                else if (_tachesParProjet.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Row(children: [
                      Icon(LucideIcons.folderOpen, size: 14, color: kTextSub),
                      SizedBox(width: 8),
                      Text('Aucun projet ni tâche assigné', style: TextStyle(color: kTextSub, fontSize: 13)),
                    ]),
                  )
                else ...[
                  const SizedBox(height: 6),
                  ..._tachesParProjet.entries.map((e) => _ProjetTachesBlock(projetTitre: e.key, taches: e.value)),
                ],
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccent, elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Fermer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  BLOC PROJET + TÂCHES (popup view)
// ══════════════════════════════════════════════════════════════════════════════
class _ProjetTachesBlock extends StatelessWidget {
  final String projetTitre;
  final List<Map<String, dynamic>> taches;
  const _ProjetTachesBlock({required this.projetTitre, required this.taches});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAccent.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Row(children: [
            const Icon(LucideIcons.folderOpen, size: 14, color: kAccent),
            const SizedBox(width: 8),
            Expanded(child: Text(projetTitre,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kTextMain),
                overflow: TextOverflow.ellipsis)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: kAccent.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
              child: Text('${taches.length} tâche(s)',
                  style: const TextStyle(fontSize: 10, color: kAccent, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        ...taches.map((t) {
          final statut = t['statut'] as String? ?? '';
          final color  = statut == 'termine' ? const Color(0xFF10B981) : statut == 'en_cours' ? kAccent : kTextSub;
          final label  = statut == 'termine' ? 'Terminé' : statut == 'en_cours' ? 'En cours' : 'En attente';
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Row(children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 10),
              Expanded(child: Text(t['titre'] as String? ?? '',
                  style: const TextStyle(fontSize: 13, color: kTextMain), overflow: TextOverflow.ellipsis)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
              ),
            ]),
          );
        }),
        const SizedBox(height: 6),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  DIALOG MUTUALISÉ (Ajouter + Modifier)
// ══════════════════════════════════════════════════════════════════════════════
class _MembreDialog extends StatefulWidget {
  final String title, subtitle, btnLabel;
  final IconData icon, btnIcon;
  final Color? iconBg, iconColor, btnColor;
  final TextEditingController nomCtrl, emailCtrl, telCtrl;
  final String? selectedRole;
  final ValueChanged<String?> onRoleChanged;
  final Future<void> Function() onSubmit;

  const _MembreDialog({
    required this.title, required this.subtitle, required this.icon,
    required this.btnLabel, required this.btnIcon,
    this.iconBg, this.iconColor, this.btnColor,
    required this.nomCtrl, required this.emailCtrl, required this.telCtrl,
    required this.selectedRole,
    required this.onRoleChanged,
    required this.onSubmit,
  });

  @override
  State<_MembreDialog> createState() => _MembreDialogState();
}

class _MembreDialogState extends State<_MembreDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final color  = widget.iconColor ?? kAccent;
    final bColor = widget.btnColor  ?? kAccent;
    final bg     = widget.iconBg    ?? kAccent.withOpacity(0.12);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [

            // ── Header ──────────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: kAccent.withOpacity(0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: kAccent.withOpacity(0.2))),
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Row(children: [
                Container(width: 44, height: 44,
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
                    child: Icon(widget.icon, color: color, size: 20)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
                  const SizedBox(height: 3),
                  Text(widget.subtitle, style: const TextStyle(color: kTextSub, fontSize: 12), overflow: TextOverflow.ellipsis),
                ])),
              ]),
            ),

            // ── Champs ──────────────────────────────────────────────────────
            Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [

                  // Nom complet
                  _DialogField(
                    icon: LucideIcons.user, label: 'NOM COMPLET *', hint: 'Ahmed Ben Ali',
                    controller: widget.nomCtrl,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Nom obligatoire';
                      if (v.trim().length < 2) return 'Minimum 2 caractères';
                      if (v.trim().length > 100) return 'Maximum 100 caractères';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Rôle — liste déroulante
                  _DropdownField(
                    icon: LucideIcons.briefcase,
                    label: 'RÔLE *',
                    hint: 'Sélectionner un rôle',
                    value: widget.selectedRole,
                    items: kRolesArchitecture,
                    onChanged: widget.onRoleChanged,
                    validator: (v) => (v == null || v.isEmpty) ? 'Rôle obligatoire' : null,
                  ),
                  const SizedBox(height: 12),

                  // Email
                  _DialogField(
                    icon: LucideIcons.mail, label: 'EMAIL', hint: 'email@archi.tn',
                    controller: widget.emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final emailRegex = RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
                      if (!emailRegex.hasMatch(v.trim())) return 'Format email invalide';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Téléphone
                  _DialogField(
                    icon: LucideIcons.phone, label: 'TÉLÉPHONE', hint: '20000000',
                    controller: widget.telCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      if (v.length != 8) return 'Exactement 8 chiffres';
                      final n = int.tryParse(v);
                      if (n == null || n < 20000000) return 'Numéro invalide';
                      return null;
                    },
                  ),

                ]),
              ),
            ),

            // ── Footer ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Annuler', style: TextStyle(color: kTextSub, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : () async {
                      if (!_formKey.currentState!.validate()) return;
                      setState(() => _loading = true);
                      await widget.onSubmit();
                      if (mounted) setState(() => _loading = false);
                    },
                    icon: _loading
                        ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Icon(widget.btnIcon, size: 15, color: Colors.white),
                    label: Text(_loading ? 'En cours...' : widget.btnLabel,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _loading ? bColor.withOpacity(0.6) : bColor, elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
// ══════════════════════════════════════════════════════════════════════════════
//  HELPERS COMMUNS
// ══════════════════════════════════════════════════════════════════════════════
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _InfoTile({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFBEB),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: kAccent.withOpacity(0.2)),
    ),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 14, color: color)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: kTextSub, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, color: kTextMain, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
      ])),
    ]),
  );
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _SectionTitle({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: color, size: 18),
    const SizedBox(width: 8),
    Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: kTextMain)),
  ]);
}

class _StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: kCardBg,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 16)),
      const SizedBox(height: 8),
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: kTextMain))),
      const SizedBox(height: 2),
      Text(title, style: const TextStyle(color: kTextSub, fontSize: 11), overflow: TextOverflow.ellipsis),
    ]),
  );
}

class _DialogField extends StatelessWidget {
  final IconData icon;
  final String label, hint;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  const _DialogField({
    required this.icon, required this.label, required this.hint, required this.controller,
    this.keyboardType = TextInputType.text, this.validator, this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSub, letterSpacing: 0.5)),
    const SizedBox(height: 6),
    TextFormField(
      controller: controller, keyboardType: keyboardType,
      validator: validator, inputFormatters: inputFormatters,
      style: const TextStyle(fontSize: 13, color: kTextMain),
      decoration: InputDecoration(
        hintText: hint, hintStyle: const TextStyle(color: kTextSub),
        prefixIcon: Icon(icon, size: 14, color: kTextSub),
        isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        filled: true, fillColor: Colors.white,
        border:             OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder:      OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder:      OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: kAccent, width: 2)),
        errorBorder:        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kRed)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kRed, width: 2)),
        errorStyle: const TextStyle(fontSize: 11, color: kRed),
      ),
    ),
  ]);
}

class _DropdownField extends StatelessWidget {
  final IconData icon;
  final String label, hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;

  const _DropdownField({
    required this.icon, required this.label, required this.hint,
    required this.value, required this.items, required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSub, letterSpacing: 0.5)),
      const SizedBox(height: 6),
      DropdownButtonFormField<String>(
        value: value,
        validator: validator,
        isExpanded: true,
        hint: Text(hint, style: const TextStyle(color: kTextSub, fontSize: 13)),
        icon: const Icon(LucideIcons.chevronsUpDown, size: 15, color: kTextSub),
        dropdownColor: Colors.white,
        style: const TextStyle(fontSize: 13, color: kTextMain),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 14, color: kTextSub),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          filled: true, fillColor: Colors.white,
          border:             OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          enabledBorder:      OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          focusedBorder:      OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: kAccent, width: 2)),
          errorBorder:        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kRed)),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kRed, width: 2)),
          errorStyle: const TextStyle(fontSize: 11, color: kRed),
        ),
        items: items.map((item) => DropdownMenuItem(
          value: item,
          child: Text(item, overflow: TextOverflow.ellipsis),
        )).toList(),
        onChanged: onChanged,
      ),
    ]);
  }
}

void _showSnack(BuildContext context, String msg, Color color) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg), backgroundColor: color,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ));
}

// ══════════════════════════════════════════════════════════════════════════════
//  POPUP CONGÉS
// ══════════════════════════════════════════════════════════════════════════════
void showCongeDialog(BuildContext context, Membre membre, VoidCallback onRefresh) {
  showDialog(context: context, builder: (_) => _CongeDialog(membre: membre, onRefresh: onRefresh));
}

class _CongeDialog extends StatefulWidget {
  final Membre membre;
  final VoidCallback onRefresh;
  const _CongeDialog({required this.membre, required this.onRefresh});
  @override
  State<_CongeDialog> createState() => _CongeDialogState();
}

class _CongeDialogState extends State<_CongeDialog> {
  static const _kOrange = Color(0xFFF97316);
  List<Conge> _conges = [];
  bool _loading = true;
  DateTime? _dateDebut;
  DateTime? _dateFin;
  final _motifCtrl = TextEditingController();
  bool _decalerTaches = true;
  bool _submitting = false;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _motifCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final conges = await CongeService.getCongesForMembre(widget.membre.id);
    if (mounted) setState(() { _conges = conges; _loading = false; });
  }

  Future<void> _pickDate(bool isDebut) async {
    final now = DateTime.now();
    final initial = isDebut ? (_dateDebut ?? now) : (_dateFin ?? (_dateDebut ?? now));
    final first   = isDebut ? now.subtract(const Duration(days: 365)) : (_dateDebut ?? now);
    final picked  = await showDatePicker(
      context: context, initialDate: initial, firstDate: first,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isDebut) { _dateDebut = picked; if (_dateFin != null && _dateFin!.isBefore(picked)) _dateFin = null; }
        else { _dateFin = picked; }
      });
    }
  }

  Future<void> _submit() async {
    if (_dateDebut == null || _dateFin == null) { _snack('Sélectionnez les dates du congé', kRed); return; }
    setState(() => _submitting = true);
    try {
      await CongeService.addConge(membreId: widget.membre.id, dateDebut: _dateDebut!, dateFin: _dateFin!, motif: _motifCtrl.text.trim());
      int delayed = 0;
      if (_decalerTaches) delayed = await CongeService.applyTaskDelay(widget.membre, _dateDebut!, _dateFin!);
      widget.onRefresh();
      _snack(delayed > 0 ? 'Congé enregistré · $delayed tâche(s) décalée(s)' : 'Congé enregistré avec succès', const Color(0xFF10B981));
      _motifCtrl.clear();
      if (mounted) setState(() { _dateDebut = null; _dateFin = null; _submitting = false; });
      await _load();
    } catch (e) {
      if (mounted) setState(() => _submitting = false);
      _snack('Erreur : $e', kRed);
    }
  }

  Future<void> _deleteConge(Conge c) async {
    await CongeService.deleteConge(c.id);
    widget.onRefresh();
    await _load();
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
      backgroundColor: color, behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = !_submitting && _dateDebut != null && _dateFin != null;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            decoration: const BoxDecoration(color: _kOrange, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Row(children: [
              Container(width: 42, height: 42,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(LucideIcons.umbrella, color: Colors.white, size: 20)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Gestion des congés', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
                const SizedBox(height: 3),
                Text(widget.membre.nom, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13), overflow: TextOverflow.ellipsis),
              ])),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (_loading)
                  const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 24), child: CircularProgressIndicator()))
                else if (_conges.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(12), border: Border.all(color: _kOrange.withOpacity(0.25))),
                    child: const Row(children: [Icon(LucideIcons.calendar, color: _kOrange, size: 18), SizedBox(width: 12), Text('Aucun congé enregistré', style: TextStyle(color: kTextSub, fontSize: 13))]),
                  )
                else ...[
                  Row(children: [
                    const Icon(LucideIcons.calendarClock, color: _kOrange, size: 15), const SizedBox(width: 8),
                    Text('Congés (${_conges.length})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextMain)),
                  ]),
                  const SizedBox(height: 10),
                  ..._conges.map((c) => _CongeItem(conge: c, onDelete: () => _deleteConge(c))),
                ],
                const SizedBox(height: 20),
                const Divider(color: Color(0xFFE5E7EB)),
                const SizedBox(height: 16),
                const Row(children: [
                  Icon(LucideIcons.plus, color: _kOrange, size: 15), SizedBox(width: 8),
                  Text('Nouveau congé', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextMain)),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _DatePickerBtn(label: 'Début', date: _dateDebut, onTap: () => _pickDate(true))),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(LucideIcons.arrowRight, size: 15, color: kTextSub)),
                  Expanded(child: _DatePickerBtn(label: 'Fin', date: _dateFin, onTap: () => _pickDate(false), enabled: _dateDebut != null)),
                ]),
                if (_dateDebut != null && _dateFin != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: _kOrange.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                      child: Text('Durée : ${_dateFin!.difference(_dateDebut!).inDays + 1} jour(s)',
                          style: const TextStyle(color: _kOrange, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _motifCtrl, maxLines: 2,
                  style: const TextStyle(fontSize: 13, color: kTextMain),
                  decoration: InputDecoration(
                    hintText: 'Motif du congé (facultatif)', hintStyle: const TextStyle(color: kTextSub, fontSize: 13),
                    prefixIcon: const Icon(LucideIcons.fileText, size: 14, color: kTextSub),
                    isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                    filled: true, fillColor: Colors.white,
                    border:        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kOrange, width: 2)),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => setState(() => _decalerTaches = !_decalerTaches),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _decalerTaches ? const Color(0xFFFFF7ED) : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _decalerTaches ? _kOrange.withOpacity(0.4) : const Color(0xFFE5E7EB)),
                    ),
                    child: Row(children: [
                      const Icon(LucideIcons.calendarCheck, size: 16, color: _kOrange), const SizedBox(width: 10),
                      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Décaler les tâches automatiquement', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: kTextMain)),
                        SizedBox(height: 2),
                        Text('Reporter les tâches en cours qui chevauchent ce congé', style: TextStyle(color: kTextSub, fontSize: 11)),
                      ])),
                      Switch(value: _decalerTaches, onChanged: (v) => setState(() => _decalerTaches = v),
                          activeColor: _kOrange, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13), side: const BorderSide(color: Color(0xFFD1D5DB)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text('Fermer', style: TextStyle(color: kTextSub, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: canSubmit ? _submit : null,
                  icon: _submitting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(LucideIcons.calendarCheck, size: 15, color: Colors.white),
                  label: Text(_submitting ? 'En cours...' : 'Enregistrer',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canSubmit ? _kOrange : const Color(0xFFD1D5DB), elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _CongeItem extends StatelessWidget {
  final Conge conge;
  final VoidCallback onDelete;
  const _CongeItem({required this.conge, required this.onDelete});
  static const _kOrange = Color(0xFFF97316);

  @override
  Widget build(BuildContext context) {
    final color = conge.isActif ? _kOrange : (conge.isFutur ? const Color(0xFF3B82F6) : kTextSub);
    final label = conge.isActif ? 'En cours' : (conge.isFutur ? 'À venir' : 'Passé');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: conge.isActif ? const Color(0xFFFFF7ED) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: conge.isActif ? _kOrange.withOpacity(0.4) : const Color(0xFFE5E7EB)),
      ),
      child: Row(children: [
        Icon(LucideIcons.umbrella, size: 14, color: color), const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(conge.periodeDisplay, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          const SizedBox(height: 4),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            Text('${conge.dureeJours} jour(s)', style: const TextStyle(color: kTextSub, fontSize: 11)),
            if (conge.motif.isNotEmpty) ...[
              const Text(' · ', style: TextStyle(color: kTextSub, fontSize: 11)),
              Expanded(child: Text(conge.motif, style: const TextStyle(color: kTextSub, fontSize: 11), overflow: TextOverflow.ellipsis)),
            ],
          ]),
        ])),
        IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded, size: 17, color: kRed),
            tooltip: 'Supprimer', padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 30, minHeight: 30)),
      ]),
    );
  }
}

class _DatePickerBtn extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final bool enabled;
  const _DatePickerBtn({required this.label, required this.date, required this.onTap, this.enabled = true});
  static const _kOrange = Color(0xFFF97316);
  static String _fmt(DateTime d) {
    const m = ['jan','fév','mar','avr','mai','jun','jul','aoû','sep','oct','nov','déc'];
    return '${d.day.toString().padLeft(2, '0')} ${m[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: date != null ? _kOrange : const Color(0xFFE5E7EB)),
      ),
      child: Row(children: [
        Icon(LucideIcons.calendar, size: 14, color: date != null ? _kOrange : kTextSub), const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: kTextSub, fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(date != null ? _fmt(date!) : 'Sélectionner',
              style: TextStyle(fontSize: 12, color: date != null ? kTextMain : kTextSub, fontWeight: date != null ? FontWeight.w600 : FontWeight.w400)),
        ])),
      ]),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  TABLEAU DE SYNTHÈSE
// ══════════════════════════════════════════════════════════════════════════════
const List<Color> _kProjectColors = [
  Color(0xFF6366F1), Color(0xFF10B981), Color(0xFFEF4444), Color(0xFF8B5CF6),
  Color(0xFFF59E0B), Color(0xFF3B82F6), Color(0xFFEC4899), Color(0xFF14B8A6),
  Color(0xFF84CC16), Color(0xFFF97316),
];

class _EquipeTable extends StatefulWidget {
  final List<Membre>  membres;
  final Set<String>   membresEnConge;
  final Map<String, List<Map<String, dynamic>>> tachesParMembre;
  final List<Project> projets;
  const _EquipeTable({required this.membres, required this.membresEnConge, required this.tachesParMembre, required this.projets});

  @override
  State<_EquipeTable> createState() => _EquipeTableState();
}

class _EquipeTableState extends State<_EquipeTable> {
  final Set<String> _expanded = {};
  final Map<String, List<Map<String, dynamic>>> _detailCache = {};
  final Set<String> _loadingDetail = {};

  static const _kMois = ['jan','fév','mar','avr','mai','jun','jul','aoû','sep','oct','nov','déc'];
  static String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')} ${_kMois[d.month - 1]} ${d.year}';
  static String _duree(DateTime debut, DateTime fin) {
    final j = fin.difference(debut).inDays + 1;
    if (j < 1) return '—'; if (j < 8) return '$j j'; if (j < 31) return '${(j / 7).round()} sem';
    return '${(j / 30).round()} mois';
  }

  Future<void> _loadDetails(String membreId) async {
    if (_detailCache.containsKey(membreId)) return;
    setState(() => _loadingDetail.add(membreId));
    try {
      final rows = await MembreService.getMembreTachesWithDetails(membreId);
      if (mounted) setState(() { _detailCache[membreId] = rows; _loadingDetail.remove(membreId); });
    } catch (_) {
      if (mounted) setState(() => _loadingDetail.remove(membreId));
    }
  }

  void _toggle(String membreId) {
    if (_expanded.contains(membreId)) { setState(() => _expanded.remove(membreId)); }
    else { setState(() => _expanded.add(membreId)); _loadDetails(membreId); }
  }

  ({String label, Color fg, Color bg, IconData icon}) _statutInfo(Map<String, dynamic> t) {
    final statut = t['statut'] as String? ?? '';
    final fin    = DateTime.tryParse(t['date_fin'] as String? ?? '');
    final today  = DateTime.now();
    if (statut == 'termine') return (label: 'Terminé',   fg: const Color(0xFF10B981), bg: const Color(0xFFF0FDF4), icon: LucideIcons.checkCircle);
    if (fin != null && fin.isBefore(today)) return (label: 'En retard', fg: kRed, bg: const Color(0xFFFEF2F2), icon: LucideIcons.alertTriangle);
    if (statut == 'en_cours') return (label: 'En cours', fg: kAccent, bg: const Color(0xFFFFFBEB), icon: LucideIcons.activity);
    return (label: 'En attente', fg: kTextSub, bg: const Color(0xFFF3F4F6), icon: LucideIcons.clock);
  }

  int _nbTaches(String id) => widget.tachesParMembre[id]?.length ?? 0;

  String _periodeGlobale(String id) {
    final dates = <DateTime>[];
    for (final t in widget.tachesParMembre[id] ?? []) {
      final d = DateTime.tryParse(t['date_debut'] as String? ?? '');
      final f = DateTime.tryParse(t['date_fin']   as String? ?? '');
      if (d != null) dates.add(d); if (f != null) dates.add(f);
    }
    if (dates.isEmpty) return '—';
    dates.sort();
    return '${_fmtDate(dates.first)} → ${_fmtDate(dates.last)}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.membres.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildTableHeader(),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        ...widget.membres.asMap().entries.map((e) {
          final isLast = e.key == widget.membres.length - 1;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildMembreRow(e.value),
            if (_expanded.contains(e.value.id)) _buildDetailPanel(e.value),
            if (!isLast) const Divider(height: 1, color: Color(0xFFEEEEEE)),
          ]);
        }),
      ]),
    );
  }

  Widget _buildTableHeader() {
    const hStyle = TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kTextSub, letterSpacing: 0.7);
    return Container(
      color: const Color(0xFFF9FAFB),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: const Row(children: [
        SizedBox(width: 32),
        Expanded(flex: 3, child: Text('MEMBRE',           style: hStyle)),
        Expanded(flex: 2, child: Text('PROJETS ASSIGNÉS', style: hStyle)),
        Expanded(flex: 1, child: Text('TÂCHES',           style: hStyle, textAlign: TextAlign.center)),
        Expanded(flex: 3, child: Text('PÉRIODE GLOBALE',  style: hStyle)),
        Expanded(flex: 2, child: Text('STATUT MEMBRE',    style: hStyle)),
      ]),
    );
  }

  Widget _buildMembreRow(Membre m) {
    final nbT     = _nbTaches(m.id);
    final periode = _periodeGlobale(m.id);
    final enConge = widget.membresEnConge.contains(m.id);
    final isExp   = _expanded.contains(m.id);
    final loading = _loadingDetail.contains(m.id);

    final today     = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final aTache    = (widget.tachesParMembre[m.id] ?? []).any((t) {
      if (t['statut'] != 'en_cours') return false;
      final d = DateTime.tryParse(t['date_debut'] as String? ?? '');
      final f = DateTime.tryParse(t['date_fin']   as String? ?? '');
      if (d == null || f == null) return false;
      return !todayDate.isBefore(DateTime(d.year, d.month, d.day)) && !todayDate.isAfter(DateTime(f.year, f.month, f.day));
    });

    final (sLabel, sColor, sBg, sIcon) = enConge
        ? ('En congé',    const Color(0xFFF97316), const Color(0xFFFFF7ED),   LucideIcons.umbrella)
        : aTache
            ? ('En mission',  kAccent,               const Color(0xFFFFFBEB),   LucideIcons.zap)
            : m.disponible
                ? ('Disponible',  const Color(0xFF10B981), const Color(0xFFF0FDF4), LucideIcons.checkCircle)
                : ('En activité', const Color(0xFF6366F1), const Color(0xFFF5F3FF), LucideIcons.briefcase);

    return InkWell(
      onTap: () => _toggle(m.id),
      hoverColor: const Color(0xFFFAFAFA),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          SizedBox(width: 32, child: loading
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: kAccent))
              : AnimatedRotation(turns: isExp ? 0.25 : 0, duration: const Duration(milliseconds: 180),
                  child: Icon(LucideIcons.chevronRight, size: 15, color: nbT > 0 ? kAccent : kTextSub))),
          Expanded(flex: 3, child: Row(children: [
            Container(width: 36, height: 36,
                decoration: BoxDecoration(color: kAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(18)),
                child: Center(child: Text(m.nom.isNotEmpty ? m.nom[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kAccent)))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.nom, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextMain), overflow: TextOverflow.ellipsis),
              Text(m.role, style: const TextStyle(fontSize: 11, color: kTextSub), overflow: TextOverflow.ellipsis),
            ])),
          ])),
          Expanded(flex: 2, child: m.projetsAssignes.isEmpty
              ? const Text('—', style: TextStyle(fontSize: 12, color: kTextSub))
              : Row(children: [
                  const Icon(LucideIcons.folderOpen, size: 13, color: kAccent), const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: kAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
                    child: Text('${m.projetsAssignes.length}', style: const TextStyle(fontSize: 12, color: kAccent, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 5),
                  const Flexible(child: Text('projet(s)', style: TextStyle(fontSize: 11, color: kTextSub), overflow: TextOverflow.ellipsis)),
                ])),
          Expanded(flex: 1, child: Center(child: nbT == 0
              ? const Text('—', style: TextStyle(color: kTextSub, fontSize: 12))
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)),
                  child: Text('$nbT', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kTextMain), textAlign: TextAlign.center)))),
          Expanded(flex: 3, child: Row(children: [
            if (periode != '—') const Padding(padding: EdgeInsets.only(right: 5), child: Icon(LucideIcons.calendarDays, size: 12, color: kTextSub)),
            Expanded(child: Text(periode, style: TextStyle(fontSize: 11, color: periode == '—' ? kTextSub : kTextMain, fontWeight: periode == '—' ? FontWeight.w400 : FontWeight.w500), overflow: TextOverflow.ellipsis)),
          ])),
          Expanded(flex: 2, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(color: sBg, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(sIcon, size: 11, color: sColor), const SizedBox(width: 5),
              Flexible(child: Text(sLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sColor), overflow: TextOverflow.ellipsis)),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _buildDetailPanel(Membre m) {
    if (_loadingDetail.contains(m.id)) {
      return Container(color: const Color(0xFFF9FAFB), padding: const EdgeInsets.symmetric(vertical: 20),
          child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kAccent))));
    }
    final rows = _detailCache[m.id] ?? [];
    final byProjet = <String, _ProjetDetailData>{};
    for (final row in rows) {
      final projId   = row['projet_id'] as String? ?? 'unknown';
      final projInfo = row['projets']   as Map<String, dynamic>?;
      final tache    = row['taches']    as Map<String, dynamic>?;
      if (tache == null) continue;
      if (!byProjet.containsKey(projId)) byProjet[projId] = _ProjetDetailData(titre: projInfo?['titre'] as String? ?? '—', taches: []);
      byProjet[projId]!.taches.add(tache);
    }
    if (byProjet.isEmpty) {
      return Container(color: const Color(0xFFF9FAFB), padding: const EdgeInsets.fromLTRB(56, 12, 16, 14),
          child: const Text('Aucune tâche assignée.', style: TextStyle(fontSize: 12, color: kTextSub)));
    }
    return Container(
      color: const Color(0xFFF9FAFB),
      padding: const EdgeInsets.fromLTRB(56, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: byProjet.entries.map((e) => _buildProjetBlock(e.key, e.value)).toList()),
    );
  }

  Widget _buildProjetBlock(String projId, _ProjetDetailData data) {
    final taches = List<Map<String, dynamic>>.from(data.taches)..sort((a, b) {
      final da = DateTime.tryParse(a['date_debut'] as String? ?? '');
      final db = DateTime.tryParse(b['date_debut'] as String? ?? '');
      if (da == null && db == null) return 0; if (da == null) return 1; if (db == null) return -1;
      return da.compareTo(db);
    });
    final idx = widget.projets.indexWhere((p) => p.id == projId);
    final projColor = idx >= 0 ? _kProjectColors[idx % _kProjectColors.length] : kAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE5E7EB))),
      clipBehavior: Clip.hardEdge,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(color: projColor.withOpacity(0.06), border: Border(bottom: BorderSide(color: projColor.withOpacity(0.2)))),
          child: Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: projColor, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(data.titre, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: projColor), overflow: TextOverflow.ellipsis)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: projColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Text('${taches.length} tâche${taches.length > 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: projColor)),
            ),
          ]),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 8, 14, 4),
          child: Row(children: [
            Expanded(flex: 4, child: Text('NOM DE LA TÂCHE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kTextSub, letterSpacing: 0.5))),
            Expanded(flex: 3, child: Text('PÉRIODE',         style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kTextSub, letterSpacing: 0.5))),
            SizedBox(width: 52, child: Text('DURÉE',  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kTextSub, letterSpacing: 0.5), textAlign: TextAlign.center)),
            SizedBox(width: 80, child: Text('STATUT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kTextSub, letterSpacing: 0.5), textAlign: TextAlign.center)),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFFF3F4F6)),
        ...taches.asMap().entries.map((te) => _buildTacheRow(te.value, projColor, te.key == taches.length - 1)),
      ]),
    );
  }

  Widget _buildTacheRow(Map<String, dynamic> t, Color projColor, bool isLast) {
    final titre  = t['titre']     as String? ?? '—';
    final d      = DateTime.tryParse(t['date_debut'] as String? ?? '');
    final f      = DateTime.tryParse(t['date_fin']   as String? ?? '');
    final si     = _statutInfo(t);
    final periodeStr = (d != null && f != null) ? '${_fmtDate(d)} → ${_fmtDate(f)}' : (d != null ? 'Début : ${_fmtDate(d)}' : '—');
    final dureeStr   = (d != null && f != null) ? _duree(d, f) : '—';

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(flex: 4, child: Row(children: [
            Container(width: 5, height: 5, margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: projColor.withOpacity(0.6), shape: BoxShape.circle)),
            Expanded(child: Text(titre, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextMain), overflow: TextOverflow.ellipsis)),
          ])),
          Expanded(flex: 3, child: Row(children: [
            const Icon(LucideIcons.calendar, size: 10, color: kTextSub), const SizedBox(width: 4),
            Expanded(child: Text(periodeStr, style: const TextStyle(fontSize: 10, color: kTextSub), overflow: TextOverflow.ellipsis)),
          ])),
          SizedBox(width: 52, child: Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(6)),
            child: Text(dureeStr, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kTextMain), textAlign: TextAlign.center),
          ))),
          const SizedBox(width: 8),
          SizedBox(width: 80, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(color: si.bg, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(si.icon, size: 10, color: si.fg), const SizedBox(width: 3),
              Flexible(child: Text(si.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: si.fg), overflow: TextOverflow.ellipsis)),
            ]),
          )),
        ]),
      ),
      if (!isLast) const Divider(height: 1, color: Color(0xFFF5F5F5), indent: 27),
    ]);
  }
}

class _ProjetDetailData {
  final String titre;
  final List<Map<String, dynamic>> taches;
  _ProjetDetailData({required this.titre, required this.taches});
}

// ══════════════════════════════════════════════════════════════════════════════
//  GANTT — PLANNING DE L'ÉQUIPE
// ══════════════════════════════════════════════════════════════════════════════
class _GanttView extends StatefulWidget {
  final List<Membre>  membres;
  final Map<String, List<Map<String, dynamic>>> tachesParMembre;
  final List<Conge>   tousLesConges;
  final List<Project> projets;
  const _GanttView({required this.membres, required this.tachesParMembre, required this.tousLesConges, required this.projets});

  @override
  State<_GanttView> createState() => _GanttViewState();
}

class _GanttViewState extends State<_GanttView> {
  final _scroll = ScrollController();
  static const double _dayW = 26.0, _rowH = 60.0, _headerH = 44.0, _leftW = 182.0;
  late DateTime _start, _end;
  late int _totalDays;
  late Map<String, List<Conge>> _congesParMembre;

  @override
  void initState() { super.initState(); _init(); WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToToday()); }

  @override
  void didUpdateWidget(_GanttView old) { super.didUpdateWidget(old); _init(); }

  @override
  void dispose() { _scroll.dispose(); super.dispose(); }

  void _init() {
    _congesParMembre = {};
    for (final c in widget.tousLesConges) _congesParMembre.putIfAbsent(c.membreId, () => []).add(c);
    _computeRange();
  }

  void _computeRange() {
    final dates = <DateTime>[DateTime.now()];
    for (final tasks in widget.tachesParMembre.values) for (final t in tasks) {
      final d = DateTime.tryParse(t['date_debut'] as String? ?? '');
      final f = DateTime.tryParse(t['date_fin']   as String? ?? '');
      if (d != null) dates.add(d); if (f != null) dates.add(f);
    }
    for (final c in widget.tousLesConges) { dates.add(c.dateDebut); dates.add(c.dateFin); }
    final minD = dates.reduce((a, b) => a.isBefore(b) ? a : b);
    final maxD = dates.reduce((a, b) => a.isAfter(b)  ? a : b);
    _start     = DateTime(minD.year, minD.month, 1).subtract(const Duration(days: 3));
    _end       = DateTime(maxD.year, maxD.month + 1, 1).add(const Duration(days: 3));
    _totalDays = _end.difference(_start).inDays + 1;
  }

  void _scrollToToday() {
    if (!_scroll.hasClients) return;
    final offset = (DateTime.now().difference(_start).inDays * _dayW - 240).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(offset, duration: const Duration(milliseconds: 450), curve: Curves.easeOut);
  }

  Color _projetColor(String? projetId) {
    if (projetId == null) return const Color(0xFF94A3B8);
    final idx = widget.projets.indexWhere((p) => p.id == projetId);
    return _kProjectColors[(idx < 0 ? 0 : idx) % _kProjectColors.length];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.membres.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: kCardBg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildLegend(),
        const Divider(height: 1),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: _leftW, child: Column(children: [_nameHeader(), ...widget.membres.map(_buildNameCell)])),
          Container(width: 1, color: const Color(0xFFE5E7EB)),
          Expanded(child: SingleChildScrollView(
            controller: _scroll, scrollDirection: Axis.horizontal,
            child: SizedBox(width: _totalDays * _dayW, child: Column(children: [_buildHeader(), ...widget.membres.map(_buildMemberRow)])),
          )),
        ]),
      ]),
    );
  }

  Widget _buildLegend() {
    final usedIds = <String>{};
    for (final tasks in widget.tachesParMembre.values) for (final t in tasks) { final pid = t['projet_id'] as String?; if (pid != null) usedIds.add(pid); }
    final usedProjets = widget.projets.where((p) => usedIds.contains(p.id)).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Wrap(spacing: 14, runSpacing: 8, children: [
        ...usedProjets.map((p) { final idx = widget.projets.indexOf(p); return _legendDot(color: _kProjectColors[(idx < 0 ? 0 : idx) % _kProjectColors.length], label: p.titre); }),
        _legendDot(color: const Color(0xFFF59E0B), label: 'Congé / Absence'),
        _legendDot(color: const Color(0xFFE2E8F0), label: 'Week-end', border: true),
        _legendDot(color: const Color(0xFFEF4444).withOpacity(0.5), label: "Aujourd'hui"),
      ]),
    );
  }

  Widget _legendDot({required Color color, required String label, bool border = false}) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 11, height: 11, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3), border: border ? Border.all(color: const Color(0xFFCBD5E1)) : null)),
    const SizedBox(width: 5),
    Text(label, style: const TextStyle(fontSize: 11, color: kTextSub)),
  ]);

  Widget _nameHeader() => Container(height: _headerH, color: const Color(0xFFF9FAFB), padding: const EdgeInsets.symmetric(horizontal: 14), alignment: Alignment.centerLeft,
      child: const Text('MEMBRE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kTextSub, letterSpacing: 0.8)));

  Widget _buildNameCell(Membre m) => Container(
    height: _rowH, width: _leftW, padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE)))),
    child: Row(children: [
      Container(width: 30, height: 30, decoration: BoxDecoration(color: kAccent.withOpacity(0.12), borderRadius: BorderRadius.circular(15)),
          child: const Icon(LucideIcons.user, color: kAccent, size: 14)),
      const SizedBox(width: 8),
      Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(m.nom, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextMain), overflow: TextOverflow.ellipsis, maxLines: 1),
        Text(m.role, style: const TextStyle(fontSize: 10, color: kTextSub), overflow: TextOverflow.ellipsis, maxLines: 1),
      ])),
    ]),
  );

  Widget _buildHeader() {
    final segs = <({int days, String label})>[];
    DateTime cur = _start;
    while (cur.isBefore(_end)) {
      final next   = DateTime(cur.year, cur.month + 1, 1);
      final segEnd = next.isAfter(_end) ? _end : next;
      segs.add((days: segEnd.difference(cur).inDays, label: _monthLabel(cur)));
      cur = next;
    }
    return SizedBox(height: _headerH, child: Stack(children: [
      Container(width: _totalDays * _dayW, color: const Color(0xFFF9FAFB)),
      ..._weekendPositioned(height: _headerH, opacity: 0.45),
      _todayLine(height: _headerH),
      Row(children: segs.map((s) => Container(
        width: s.days * _dayW, height: _headerH, alignment: Alignment.center,
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB)), right: BorderSide(color: Color(0xFFE5E7EB)))),
        child: Text(s.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kTextMain), overflow: TextOverflow.ellipsis),
      )).toList()),
    ]));
  }

  static const _kMonths = ['Jan','Fév','Mar','Avr','Mai','Jun','Jul','Aoû','Sep','Oct','Nov','Déc'];
  String _monthLabel(DateTime d) => '${_kMonths[d.month - 1]} ${d.year}';

  Widget _buildMemberRow(Membre m) {
    final tasks  = widget.tachesParMembre[m.id] ?? [];
    final conges = _congesParMembre[m.id] ?? [];
    return SizedBox(height: _rowH, width: _totalDays * _dayW, child: Stack(clipBehavior: Clip.hardEdge, children: [
      Container(decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))))),
      ..._weekendPositioned(height: _rowH, opacity: 1.0),
      _todayLine(height: _rowH),
      ...tasks.map(_buildTaskBar),
      ...conges.map(_buildCongeBar),
    ]));
  }

  List<Widget> _weekendPositioned({required double height, required double opacity}) {
    final list = <Widget>[];
    for (int i = 0; i < _totalDays; i++) {
      final d = _start.add(Duration(days: i));
      if (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday)
        list.add(Positioned(left: i * _dayW, top: 0, width: _dayW, height: height, child: Container(color: const Color(0xFFE2E8F0).withOpacity(opacity))));
    }
    return list;
  }

  Widget _todayLine({required double height}) {
    final offset = DateTime.now().difference(_start).inDays * _dayW + _dayW / 2;
    if (offset < 0 || offset > _totalDays * _dayW) return const SizedBox.shrink();
    return Positioned(left: offset, top: 0, width: 1.5, height: height, child: Container(color: const Color(0xFFEF4444).withOpacity(0.55)));
  }

  Widget _buildTaskBar(Map<String, dynamic> t) {
    final d = DateTime.tryParse(t['date_debut'] as String? ?? '');
    final f = DateTime.tryParse(t['date_fin']   as String? ?? '');
    if (d == null || f == null) return const SizedBox.shrink();
    final left  = d.difference(_start).inDays * _dayW;
    final width = ((f.difference(d).inDays + 1) * _dayW).clamp(4.0, double.infinity);
    final color = _projetColor(t['projet_id'] as String?);
    final titre = t['titre'] as String? ?? '';
    return Positioned(left: left, top: _rowH * 0.18, height: _rowH * 0.52, width: width,
        child: Tooltip(message: titre, child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(color: color.withOpacity(0.85), borderRadius: BorderRadius.circular(4)),
          padding: const EdgeInsets.only(left: 5), alignment: Alignment.centerLeft,
          child: width > 38 ? Text(titre, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis, maxLines: 1) : null,
        )));
  }

  Widget _buildCongeBar(Conge c) {
    final left  = c.dateDebut.difference(_start).inDays * _dayW;
    final width = ((c.dateFin.difference(c.dateDebut).inDays + 1) * _dayW).clamp(4.0, double.infinity);
    return Positioned(left: left, bottom: 5, height: _rowH * 0.26, width: width,
        child: Tooltip(message: c.motif.isNotEmpty ? 'Congé : ${c.motif}' : 'Congé', child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.88), borderRadius: BorderRadius.circular(3)),
          alignment: Alignment.center,
          child: width > 40 ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(LucideIcons.umbrella, size: 8, color: Colors.white), SizedBox(width: 3),
            Text('Congé', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w600)),
          ]) : null,
        )));
  }
}