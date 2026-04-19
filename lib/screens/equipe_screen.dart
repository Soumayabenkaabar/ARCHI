import 'package:archi_manager/service/membre_service.dart';
import 'package:archi_manager/service/projet_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../constants/colors.dart';
import '../models/membre.dart';
import '../models/project.dart';
import '../widgets/membre_card.dart';

class EquipeScreen extends StatefulWidget {
  const EquipeScreen({super.key});
  @override
  State<EquipeScreen> createState() => _EquipeScreenState();
}

class _EquipeScreenState extends State<EquipeScreen> {
  final TextEditingController searchController = TextEditingController();
  List<Membre> membres = [];
  bool isLoading = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadMembres();
  }

  Future<void> loadMembres() async {
    try {
      final data = await MembreService.getMembres();
      setState(() {
        membres = data;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur membres: $e');
    }
  }

  Future<void> showAddMembreDialog() async {
    final nomCtrl = TextEditingController();
    final roleCtrl = TextEditingController();
    final specialiteCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    bool disponible = true;

    // ✅ getProjets() retourne List<Project> — on convertit en List<Map> pour le dialog
    final projetsRaw = await ProjetService.getProjets();
    final projets = projetsRaw
        .map((p) => {'id': p.id, 'titre': p.titre})
        .toList();
    String? selectedProjetId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, sd) {
          return _MembreDialog(
            title: 'Nouveau membre',
            subtitle: 'Ajoutez un intervenant à votre équipe',
            icon: LucideIcons.userPlus,
            nomCtrl: nomCtrl,
            roleCtrl: roleCtrl,
            specialiteCtrl: specialiteCtrl,
            emailCtrl: emailCtrl,
            telCtrl: telCtrl,
            disponible: disponible,
            onDisponibleChanged: (v) => sd(() => disponible = v),
            projets: projets,
            selectedProjetId: selectedProjetId,
            onProjetChanged: (v) => sd(() => selectedProjetId = v),
            btnLabel: 'Ajouter le membre',
            btnIcon: LucideIcons.userPlus,
            onSubmit: () async {
              if (!disponible && selectedProjetId == null) {
                _showSnack(context, 'Choisissez un projet', kRed);
                return;
              }
              await MembreService.addMembre(
                Membre(
                  id: '',
                  nom: nomCtrl.text,
                  role: roleCtrl.text,
                  specialite: specialiteCtrl.text,
                  email: emailCtrl.text,
                  telephone: telCtrl.text,
                  disponible: disponible,
                  projetsAssignes: disponible
                      ? []
                      : [
                          projets.firstWhere(
                            (p) => p['id'].toString() == selectedProjetId,
                          )['titre']!,
                        ],
                ),
              );
              Navigator.pop(context);
              loadMembres();
              _showSnack(context, 'Membre ajouté avec succès', kAccent);
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final pad = isMobile ? 16.0 : 28.0;
    if (isLoading)
      return const Center(child: CircularProgressIndicator(color: kAccent));

    final filtered = membres
        .where((m) => m.nom.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();
    final disponibles = filtered.where((m) => m.disponible).toList();
    final actifs = filtered.where((m) => !m.disponible).toList();

    return Container(
      color: kBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gestion de l\'équipe',
                        style: TextStyle(
                          fontSize: isMobile ? 22 : 28,
                          fontWeight: FontWeight.w800,
                          color: kTextMain,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Gérez votre équipe et leurs assignations',
                        style: TextStyle(
                          color: kTextSub,
                          fontSize: isMobile ? 12 : 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: showAddMembreDialog,
                  icon: const Icon(
                    LucideIcons.userPlus,
                    size: 15,
                    color: Colors.white,
                  ),
                  label: Text(
                    isMobile ? 'Ajouter' : 'Ajouter un membre',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccent,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 18,
                      vertical: isMobile ? 10 : 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

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

            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Total',
                      value: '${filtered.length}',
                      icon: LucideIcons.users,
                      color: kAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      title: 'En activité',
                      value: '${actifs.length}',
                      icon: LucideIcons.activity,
                      color: const Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      title: 'Disponibles',
                      value: '${disponibles.length}',
                      icon: LucideIcons.checkCircle,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            if (disponibles.isNotEmpty) ...[
              _SectionTitle(
                icon: LucideIcons.checkCircle,
                color: kAccent,
                label: 'Membres disponibles',
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (ctx, constraints) {
                  final cols = constraints.maxWidth > 900
                      ? 3
                      : constraints.maxWidth > 580
                      ? 2
                      : 1;
                  final rows = <Widget>[];
                  for (int i = 0; i < disponibles.length; i += cols) {
                    final rowItems = disponibles.skip(i).take(cols).toList();
                    rows.add(
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (int j = 0; j < rowItems.length; j++) ...[
                              if (j > 0) const SizedBox(width: 16),
                              Expanded(
                                child: MembreDisponibleCard(
                                  membre: rowItems[j],
                                  onAssign: () => showAssignDialog(
                                    context,
                                    rowItems[j],
                                    loadMembres,
                                  ),
                                  onEdit: () => showEditDialog(
                                    context,
                                    rowItems[j],
                                    loadMembres,
                                  ),
                                  onDelete: () async {
                                    if (rowItems[j].id == null) return;
                                    await MembreService.deleteMembre(
                                      rowItems[j].id!,
                                    );
                                    _showSnack(
                                      context,
                                      'Membre supprimé',
                                      kRed,
                                    );
                                    loadMembres();
                                  },
                                ),
                              ),
                            ],
                            for (int k = rowItems.length; k < cols; k++) ...[
                              const SizedBox(width: 16),
                              const Expanded(child: SizedBox()),
                            ],
                          ],
                        ),
                      ),
                    );
                    if (i + cols < disponibles.length)
                      rows.add(const SizedBox(height: 16));
                  }
                  return Column(children: rows);
                },
              ),
              const SizedBox(height: 24),
            ],

            if (actifs.isNotEmpty) ...[
              _SectionTitle(
                icon: LucideIcons.briefcase,
                color: kAccent,
                label: 'Membres en activité',
              ),
              const SizedBox(height: 14),
              ...actifs.map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: MembreActifRow(
                    membre: m,
                    onView: () => showViewDialog(context, m),
                    onEdit: () => showEditDialog(context, m, loadMembres),
                    onDelete: () async {
                      if (m.id == null) return;
                      await MembreService.deleteMembre(m.id!);
                      _showSnack(context, 'Membre supprimé', kRed);
                      loadMembres();
                    },
                  ),
                ),
              ),
            ],

            if (filtered.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: const [
                      Icon(LucideIcons.users, size: 40, color: kTextSub),
                      SizedBox(height: 12),
                      Text(
                        'Aucun membre trouvé',
                        style: TextStyle(
                          color: kTextSub,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
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
Future<void> showEditDialog(
  BuildContext context,
  Membre membre,
  VoidCallback onRefresh,
) async {
  final nomCtrl = TextEditingController(text: membre.nom);
  final roleCtrl = TextEditingController(text: membre.role);
  final specialiteCtrl = TextEditingController(text: membre.specialite);
  final emailCtrl = TextEditingController(text: membre.email);
  final telCtrl = TextEditingController(text: membre.telephone);
  bool disponible = membre.disponible;

  // ✅ getProjets() retourne List<Project> — on convertit en List<Map> pour le dialog
  final projetsRaw = await ProjetService.getProjets();
  final projets = projetsRaw
      .map((p) => {'id': p.id, 'titre': p.titre})
      .toList();

  // ✅ Pré-sélectionner le projet assigné au membre
  String? selectedProjetId;
  if (membre.projetsAssignes.isNotEmpty) {
    try {
      final found = projets.firstWhere(
        (p) => p['titre'] == membre.projetsAssignes.first,
        orElse: () => <String, String>{},
      );
      if (found.isNotEmpty) selectedProjetId = found['id'];
    } catch (_) {}
  }

  showDialog(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, sd) {
        return _MembreDialog(
          title: 'Modifier le membre',
          subtitle: 'Mettez à jour les informations',
          icon: LucideIcons.pencil,
          iconBg: kAccent.withOpacity(0.12),
          iconColor: kAccent,
          btnColor: kAccent,
          nomCtrl: nomCtrl,
          roleCtrl: roleCtrl,
          specialiteCtrl: specialiteCtrl,
          emailCtrl: emailCtrl,
          telCtrl: telCtrl,
          disponible: disponible,
          onDisponibleChanged: (v) => sd(() => disponible = v),
          projets: projets,
          selectedProjetId: selectedProjetId,
          onProjetChanged: (v) => sd(() => selectedProjetId = v),
          btnLabel: 'Enregistrer',
          btnIcon: LucideIcons.save,
          onSubmit: () async {
            if (!disponible && selectedProjetId == null) {
              _showSnack(context, 'Choisissez un projet pour ce membre', kRed);
              return;
            }
            await MembreService.updateMembre(
              Membre(
                id: membre.id,
                nom: nomCtrl.text,
                role: roleCtrl.text,
                specialite: specialiteCtrl.text,
                email: emailCtrl.text,
                telephone: telCtrl.text,
                disponible: disponible,
                projetsAssignes: disponible
                    ? []
                    : [
                        projets.firstWhere(
                          (p) => p['id'] == selectedProjetId,
                        )['titre']!,
                      ],
              ),
            );
            Navigator.pop(context);
            onRefresh();
            _showSnack(context, 'Membre modifié avec succès', kAccent);
          },
        );
      },
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  POPUP ASSIGNER
// ══════════════════════════════════════════════════════════════════════════════
void showAssignDialog(
  BuildContext context,
  Membre membre,
  VoidCallback onRefresh,
) async {
  // ✅ getProjets() retourne List<Project> — on convertit en List<Map>
  final projetsRaw = await ProjetService.getProjets();
  final projets = projetsRaw
      .map((p) => {'id': p.id, 'titre': p.titre})
      .toList();
  String? selectedId;

  showDialog(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, sd) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: kAccent,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          LucideIcons.folderInput,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Assigner à un projet',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              membre.nom,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kAccent.withOpacity(0.25)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: kAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                LucideIcons.user,
                                color: kAccent,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    membre.nom,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: kTextMain,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    membre.role,
                                    style: const TextStyle(
                                      color: kTextSub,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Disponible',
                                style: TextStyle(
                                  color: Color(0xFF16A34A),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'SÉLECTIONNER UN PROJET',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: kTextSub,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...projets.map((p) {
                        final id = p['id']!;
                        final isSelected = selectedId == id;
                        return GestureDetector(
                          onTap: () => sd(() => selectedId = id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFFFFBEB)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? kAccent
                                    : const Color(0xFFE5E7EB),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? kAccent
                                        : const Color(0xFFD1D5DB),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    p['titre'] ?? '',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: isSelected ? kAccent : kTextMain,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    LucideIcons.check,
                                    size: 16,
                                    color: kAccent,
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            side: const BorderSide(color: Color(0xFFD1D5DB)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Annuler',
                            style: TextStyle(
                              color: kTextSub,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: selectedId == null
                              ? null
                              : () async {
                                  final proj = projets.firstWhere(
                                    (p) => p['id'] == selectedId,
                                  );
                                  await MembreService.assignMembre(
                                    membre: membre,
                                    projet: proj['titre']!,
                                  );
                                  Navigator.pop(context);
                                  _showSnack(
                                    context,
                                    '${membre.nom} assigné avec succès',
                                    kAccent,
                                  );
                                  onRefresh();
                                },
                          icon: const Icon(
                            LucideIcons.check,
                            size: 15,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Confirmer',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: selectedId == null
                                ? const Color(0xFFD1D5DB)
                                : kAccent,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  POPUP VIEW
// ══════════════════════════════════════════════════════════════════════════════
void showViewDialog(BuildContext context, Membre membre) {
  showDialog(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: const BoxDecoration(
                color: kAccent,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Icon(
                      LucideIcons.user,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          membre.nom,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          membre.role,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      membre.disponible ? 'Disponible' : 'En activité',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _InfoTile(
                    icon: LucideIcons.settings2,
                    label: 'Spécialité',
                    value: membre.specialite,
                    color: kAccent,
                  ),
                  _InfoTile(
                    icon: LucideIcons.mail,
                    label: 'Email',
                    value: membre.email,
                    color: kAccent,
                  ),
                  _InfoTile(
                    icon: LucideIcons.phone,
                    label: 'Téléphone',
                    value: membre.telephone,
                    color: kAccent,
                  ),
                  if (membre.projetsAssignes.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kAccent.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: kAccent,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${membre.projetsAssignes.length} projet(s) assigné(s)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: kTextMain,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...membre.projetsAssignes.map(
                            (p) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  const Icon(
                                    LucideIcons.folderOpen,
                                    size: 13,
                                    color: kAccent,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      p,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: kTextMain,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Fermer',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  DIALOG MUTUALISÉ (Ajouter + Modifier)
// ══════════════════════════════════════════════════════════════════════════════
class _MembreDialog extends StatefulWidget {
  final String title, subtitle, btnLabel;
  final IconData icon, btnIcon;
  final Color? iconBg, iconColor, btnColor;
  final TextEditingController nomCtrl,
      roleCtrl,
      specialiteCtrl,
      emailCtrl,
      telCtrl;
  final bool disponible;
  final ValueChanged<bool> onDisponibleChanged;
  final Future<void> Function() onSubmit;
  // ✅ List<Map<String, String>> — clés typées String (id + titre)
  final List<Map<String, String>>? projets;
  final String? selectedProjetId;
  final ValueChanged<String?>? onProjetChanged;

  const _MembreDialog({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.btnLabel,
    required this.btnIcon,
    this.iconBg,
    this.iconColor,
    this.btnColor,
    required this.nomCtrl,
    required this.roleCtrl,
    required this.specialiteCtrl,
    required this.emailCtrl,
    required this.telCtrl,
    required this.disponible,
    required this.onDisponibleChanged,
    required this.onSubmit, // Future<void> Function()
    this.projets,
    this.selectedProjetId,
    this.onProjetChanged,
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
    final narrow = MediaQuery.of(context).size.width < 420;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: kAccent.withOpacity(0.08),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  border: Border(
                    bottom: BorderSide(color: kAccent.withOpacity(0.2)),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(widget.icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.subtitle,
                            style: const TextStyle(
                              color: kTextSub,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Form(
                key: _formKey,
                child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    narrow
                        ? Column(
                            children: [
                              _DialogField(
                                icon: LucideIcons.user,
                                label: 'NOM COMPLET *',
                                hint: 'Ahmed Ben Ali',
                                controller: widget.nomCtrl,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Nom obligatoire';
                                  if (v.trim().length < 2) return 'Minimum 2 caractères';
                                  if (v.trim().length > 100) return 'Maximum 100 caractères';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              _DialogField(
                                icon: LucideIcons.briefcase,
                                label: 'RÔLE *',
                                hint: 'Architecte',
                                controller: widget.roleCtrl,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Rôle obligatoire';
                                  if (v.trim().length < 2) return 'Minimum 2 caractères';
                                  return null;
                                },
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: _DialogField(
                                  icon: LucideIcons.user,
                                  label: 'NOM COMPLET *',
                                  hint: 'Ahmed Ben Ali',
                                  controller: widget.nomCtrl,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Nom obligatoire';
                                    if (v.trim().length < 2) return 'Minimum 2 caractères';
                                    if (v.trim().length > 100) return 'Maximum 100 caractères';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _DialogField(
                                  icon: LucideIcons.briefcase,
                                  label: 'RÔLE *',
                                  hint: 'Architecte',
                                  controller: widget.roleCtrl,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Rôle obligatoire';
                                    if (v.trim().length < 2) return 'Minimum 2 caractères';
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                    const SizedBox(height: 12),
                    _DialogField(
                      icon: LucideIcons.settings,
                      label: 'SPÉCIALITÉ',
                      hint: 'Béton armé',
                      controller: widget.specialiteCtrl,
                    ),
                    const SizedBox(height: 12),
                    _DialogField(
                      icon: LucideIcons.mail,
                      label: 'EMAIL',
                      hint: 'email@archi.ma',
                      controller: widget.emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final regex = RegExp(r'^[\w\.\-]+@[\w\-]+\.[a-z]{2,}$', caseSensitive: false);
                        if (!regex.hasMatch(v.trim())) return 'Format email invalide (ex: email@archi.ma)';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _DialogField(
                      icon: LucideIcons.phone,
                      label: 'TÉLÉPHONE',
                      hint: '20000000',
                      controller: widget.telCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        if (v.length != 8) return 'Le numéro doit contenir exactement 8 chiffres';
                        final num = int.tryParse(v);
                        if (num == null || num < 20000000) return 'Numéro invalide ';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: widget.disponible
                            ? const Color(0xFFF0FDF4)
                            : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: widget.disponible
                              ? const Color(0xFFBBF7D0)
                              : kAccent.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            widget.disponible
                                ? LucideIcons.checkCircle
                                : LucideIcons.briefcase,
                            color: widget.disponible
                                ? const Color(0xFF16A34A)
                                : kAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Statut : ${widget.disponible ? "Disponible" : "En activité"}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: widget.disponible
                                        ? const Color(0xFF16A34A)
                                        : kAccent,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Basculer pour changer le statut',
                                  style: TextStyle(
                                    color: kTextSub,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: widget.disponible,
                            onChanged: widget.onDisponibleChanged,
                            activeColor: const Color(0xFF16A34A),
                            inactiveThumbColor: kAccent,
                            inactiveTrackColor: kAccent.withOpacity(0.3),
                          ),
                        ],
                      ),
                    ),

                    if (!widget.disponible && widget.projets != null) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'PROJET ASSIGNÉ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: kTextSub,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kAccent.withOpacity(0.4)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: widget.selectedProjetId,
                            hint: const Text(
                              'Choisir un projet',
                              style: TextStyle(color: kTextSub, fontSize: 13),
                            ),
                            isExpanded: true,
                            icon: const Icon(
                              LucideIcons.chevronsUpDown,
                              size: 16,
                              color: kAccent,
                            ),
                            dropdownColor: Colors.white,
                            items: widget.projets!
                                .map<DropdownMenuItem<String>>(
                                  (p) => DropdownMenuItem(
                                    value: p['id'],
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: kAccent,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            p['titre'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: kTextMain,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: widget.onProjetChanged,
                          ),
                        ),
                      ),
                      if (widget.selectedProjetId != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.info,
                              size: 13,
                              color: kAccent,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Projet actuel chargé depuis la base de données',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: kAccent.withOpacity(0.8),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              )), // end Form + Padding

              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: const BorderSide(color: Color(0xFFD1D5DB)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Annuler',
                          style: TextStyle(
                            color: kTextSub,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
                        label: Text(
                          _loading ? 'En cours...' : widget.btnLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _loading ? bColor.withOpacity(0.6) : bColor,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  HELPERS
// ══════════════════════════════════════════════════════════════════════════════
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFBEB),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: kAccent.withOpacity(0.2)),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: kTextSub,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  color: kTextMain,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _SectionTitle({
    required this.icon,
    required this.color,
    required this.label,
  });
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 8),
      Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: kTextMain,
        ),
      ),
    ],
  );
}

class _StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: kCardBg,
      borderRadius: BorderRadius.circular(14),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: kTextMain,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(color: kTextSub, fontSize: 11),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
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
    required this.icon,
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.inputFormatters,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: kTextSub,
          letterSpacing: 0.5,
        ),
      ),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        inputFormatters: inputFormatters,
        style: const TextStyle(fontSize: 13, color: kTextMain),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: kTextSub),
          prefixIcon: Icon(icon, size: 14, color: kTextSub),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: kAccent, width: 2)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kRed)),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kRed, width: 2)),
          errorStyle: const TextStyle(fontSize: 11, color: kRed),
        ),
      ),
    ],
  );
}

void _showSnack(BuildContext context, String msg, Color color) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}
