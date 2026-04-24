import 'package:archi_manager/service/client_service.dart';
import 'package:archi_manager/service/membre_service.dart';
import 'package:archi_manager/models/client.dart';
import 'package:archi_manager/models/membre.dart';
import 'package:archi_manager/screens/projet_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../constants/colors.dart';
import '../models/project.dart';
import '../service/projet_service.dart';
import '../widgets/project_full_card.dart';
import '../widgets/map_location_picker.dart';

class ProjetsScreen extends StatefulWidget {
  const ProjetsScreen({super.key});

  @override
  State<ProjetsScreen> createState() => _ProjetsScreenState();
}

class _ProjetsScreenState extends State<ProjetsScreen> {
  String selectedFilter = 'Tous';
  String _searchQuery = '';
  String _sortBy = 'statut'; // 'statut' | 'nom' | 'avancement'
  List<Project> projets = [];
  bool isLoading = true;

  static const List<String> _statuts = ['En cours', 'Planification', 'Terminé'];

  @override
  void initState() {
    super.initState();
    loadProjets();
  }

  Future<void> loadProjets() async {
    try {
      final data = await ProjetService.getProjets();
      setState(() {
        projets = data;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur projets: $e');
      setState(() => isLoading = false);
    }
  }

  static const Map<String, int> _statutOrder = {
    'en_cours': 0,
    'en_attente': 1,
    'termine': 2,
    'annule': 3,
  };

  static const Map<String, String> _labelToDb = {
    'En cours': 'en_cours',
    'Planification': 'en_attente',
    'Terminé': 'termine',
    'Annulé': 'annule',
  };

  List<Project> get _filtered {
    var list = projets.where((p) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!p.titre.toLowerCase().contains(q) &&
            !p.client.toLowerCase().contains(q) &&
            !p.localisation.toLowerCase().contains(q)) return false;
      }
      if (selectedFilter != 'Tous') {
        final db = _labelToDb[selectedFilter];
        if (db != null && p.statut != db) return false;
      }
      return true;
    }).toList();

    switch (_sortBy) {
      case 'statut':
        list.sort((a, b) => (_statutOrder[a.statut] ?? 9).compareTo(_statutOrder[b.statut] ?? 9));
      case 'nom':
        list.sort((a, b) => a.titre.toLowerCase().compareTo(b.titre.toLowerCase()));
      case 'avancement':
        list.sort((a, b) => b.avancement.compareTo(a.avancement));
    }
    return list;
  }

  // Groupement par statut pour la vue "Tous"
  Map<String, List<Project>> get _grouped {
    final order = ['en_cours', 'en_attente', 'termine', 'annule'];
    final map = <String, List<Project>>{};
    for (final s in order) {
      final items = _filtered.where((p) => p.statut == s).toList();
      if (items.isNotEmpty) map[s] = items;
    }
    return map;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'En cours':    return const Color(0xFF3B82F6);
      case 'Planification': return const Color(0xFFF59E0B);
      case 'Terminé':     return const Color(0xFF10B981);
      case 'Annulé':      return const Color(0xFF9CA3AF);
      default:            return const Color(0xFF6B7280);
    }
  }

  static const Map<String, String> _dbToLabel = {
    'en_cours': 'En cours',
    'en_attente': 'Planification',
    'termine': 'Terminé',
    'annule': 'Annulé',
  };

  Widget _buildGroupedList(BuildContext context) {
    final groups = _grouped;
    if (groups.isEmpty) return const SizedBox();

    final groupColors = {
      'en_cours': const Color(0xFF3B82F6),
      'en_attente': const Color(0xFFF59E0B),
      'termine': const Color(0xFF10B981),
      'annule': const Color(0xFF9CA3AF),
    };
    final groupIcons = {
      'en_cours': LucideIcons.activity,
      'en_attente': LucideIcons.clock,
      'termine': LucideIcons.checkCircle,
      'annule': LucideIcons.xCircle,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groups.entries.map((entry) {
        final statut = entry.key;
        final items = entry.value;
        final color = groupColors[statut] ?? kTextSub;
        final icon = groupIcons[statut] ?? LucideIcons.folder;
        final label = _dbToLabel[statut] ?? statut;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 14, color: color),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${items.length}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Divider(color: color.withOpacity(0.2), thickness: 1)),
                ],
              ),
            ),
            // Grid for this group
            LayoutBuilder(builder: (ctx, c) {
              final cols = c.maxWidth > 900 ? 3 : c.maxWidth > 580 ? 2 : 1;
              if (cols == 1) {
                return Column(
                  children: items.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ProjetDetailScreen(project: p, projectIndex: 0),
                      )),
                      child: ProjectFullCard(project: p),
                    ),
                  )).toList(),
                );
              }
              return _ProjetGrid(projects: items, columns: cols, onRefresh: loadProjets);
            }),
            const SizedBox(height: 24),
          ],
        );
      }).toList(),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  POPUP AJOUTER PROJET
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> showAddProjetDialog() async {
    // ── Charger clients et membres depuis la BDD ──────────────────────────
    List<Client> clients = [];
    List<Membre> membres = [];
    try {
      clients = await ClientService.getClients();
      membres = await MembreService.getMembres();
    } catch (e) {
      debugPrint('Erreur chargement données: $e');
      if (mounted) {
        _showSnack(context, 'Erreur chargement données', kRed);
      }
      return;
    }

    // ── Contrôleurs ────────────────────────────────────────────────────────
    final titreCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final localisationCtrl = TextEditingController();
    final budgetCtrl = TextEditingController();
    final dateDebutCtrl = TextEditingController();
    final dateFinCtrl = TextEditingController();

    String statut = 'En cours';
    String? selectedClientId;
    String? selectedChef;
    bool isSaving = false;
    LatLng? selectedPosition;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, sd) {
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Header ──────────────────────────────────────────────
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
                              color: kAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              LucideIcons.folderPlus,
                              color: kAccent,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nouveau projet',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: kAccent,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Créez un nouveau projet de construction',
                                  style: TextStyle(
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

                    // ── Champs ──────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Titre
                          _ProjetField(
                            icon: LucideIcons.building2,
                            label: 'TITRE DU PROJET',
                            hint: 'Villa Carthage',
                            controller: titreCtrl,
                          ),
                          const SizedBox(height: 12),

                          // Description
                          _ProjetField(
                            icon: LucideIcons.fileText,
                            label: 'DESCRIPTION',
                            hint: 'Construction villa R+1 avec piscine...',
                            controller: descCtrl,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 12),

                          // ── Client (dropdown BDD) + Localisation ───────────
                          Row(
                            children: [
                              Expanded(
                                child: _DropdownField(
                                  label: 'CLIENT',
                                  icon: LucideIcons.user,
                                  hint: 'Choisir un client',
                                  value: selectedClientId,
                                  items: clients
                                      .map<DropdownMenuItem<String>>(
                                        (c) => DropdownMenuItem(
                                          value: c.id,
                                          child: Text(c.nom),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      sd(() => selectedClientId = v),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _LocationField(
                                  controller: localisationCtrl,
                                  pickedPosition: selectedPosition,
                                  onPickMap: () async {
                                    final pos = await showMapLocationPicker(ctx, initial: selectedPosition);
                                    if (pos != null) sd(() => selectedPosition = pos);
                                  },
                                  onClearPosition: () => sd(() => selectedPosition = null),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // ── Chef de projet (dropdown BDD) + Budget ─────────
                          Row(
                            children: [
                              Expanded(
                                child: _DropdownField(
                                  label: 'CHEF DE PROJET',
                                  icon: LucideIcons.hardHat,
                                  hint: 'Choisir un chef',
                                  value: selectedChef,
                                  items: membres
                                      .map<DropdownMenuItem<String>>(
                                        (m) => DropdownMenuItem(
                                          value: m.nom,
                                          child: Text(m.nom),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) => sd(() => selectedChef = v),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ProjetField(
                                  icon: LucideIcons.banknote,
                                  label: 'BUDGET (DT)',
                                  hint: '8500000',
                                  controller: budgetCtrl,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Date début + Date fin
                          Row(
                            children: [
                              Expanded(
                                child: _ProjetField(
                                  icon: LucideIcons.calendarDays,
                                  label: 'DATE DÉBUT',
                                  hint: 'Jan 2025',
                                  controller: dateDebutCtrl,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ProjetField(
                                  icon: LucideIcons.calendarCheck,
                                  label: 'DATE FIN',
                                  hint: 'Déc 2025',
                                  controller: dateFinCtrl,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Statut selector
                          const Text(
                            'STATUT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: kTextSub,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: _statuts.map((s) {
                              final isSelected = statut == s;
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: s == _statuts.last ? 0 : 8,
                                  ),
                                  child: GestureDetector(
                                    onTap: () => sd(() => statut = s),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 150,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? _statusColor(s).withOpacity(0.1)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isSelected
                                              ? _statusColor(s)
                                              : const Color(0xFFE5E7EB),
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? _statusColor(s)
                                                  : const Color(0xFFD1D5DB),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            s,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: isSelected
                                                  ? _statusColor(s)
                                                  : kTextSub,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    // ── Actions ─────────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                side: const BorderSide(
                                  color: Color(0xFFD1D5DB),
                                ),
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      String statutDb;

                                      switch (statut) {
                                        case 'En cours':
                                          statutDb = 'en_cours';
                                          break;
                                        case 'Planification':
                                          statutDb = 'en_attente';
                                          break;
                                        case 'Terminé':
                                          statutDb = 'termine';
                                          break;
                                        default:
                                          statutDb = 'en_cours';
                                      }

                                      // ── Validations ──────────────────────────────
                                      if (titreCtrl.text.trim().isEmpty) {
                                        _showSnack(
                                          ctx,
                                          'Le titre est obligatoire',
                                          kRed,
                                        );
                                        return;
                                      }
                                      if (selectedClientId == null) {
                                        _showSnack(
                                          ctx,
                                          'Choisissez un client',
                                          kRed,
                                        );
                                        return;
                                      }
                                      if (selectedChef == null) {
                                        _showSnack(
                                          ctx,
                                          'Choisissez un chef de projet',
                                          kRed,
                                        );
                                        return;
                                      }
                                      final budgetVal = double.tryParse(
                                        budgetCtrl.text.replaceAll(' ', ''),
                                      );
                                      if (budgetCtrl.text.trim().isNotEmpty &&
                                          budgetVal == null) {
                                        _showSnack(
                                          ctx,
                                          'Le budget doit être un nombre valide',
                                          kRed,
                                        );
                                        return;
                                      }
                                      if (budgetVal != null && budgetVal < 0) {
                                        _showSnack(
                                          ctx,
                                          'Le budget ne peut pas être négatif',
                                          kRed,
                                        );
                                        return;
                                      }

                                      sd(() => isSaving = true);
                                      try {
                                        final clientNom = (clients.firstWhere(
                                          (c) => c.id == selectedClientId,
                                        )).nom;
                                        final nouveau = Project(
                                          id: '',
                                          clientId: selectedClientId!,
                                          titre: titreCtrl.text.trim(),
                                          description: descCtrl.text.trim(),
                                          statut: statutDb,
                                          avancement: 0,
                                          dateDebut:
                                              dateDebutCtrl.text.trim().isEmpty
                                              ? null
                                              : dateDebutCtrl.text.trim(),
                                          dateFin:
                                              dateFinCtrl.text.trim().isEmpty
                                              ? null
                                              : dateFinCtrl.text.trim(),
                                          budgetTotal:
                                              double.tryParse(
                                                budgetCtrl.text.replaceAll(
                                                  ' ',
                                                  '',
                                                ),
                                              ) ??
                                              0,
                                          budgetDepense: 0,
                                          client: clientNom,
                                          localisation: localisationCtrl.text.trim(),
                                          chef: selectedChef!,
                                          taches: 0,
                                          latitude:  selectedPosition?.latitude,
                                          longitude: selectedPosition?.longitude,
                                        );
                                        await ProjetService.addProjet(nouveau);
                                        if (mounted) Navigator.pop(ctx);
                                        loadProjets();
                                        if (mounted)
                                          _showSnack(
                                            context,
                                            'Projet créé avec succès',
                                            kAccent,
                                          );
                                      } catch (e) {
                                        debugPrint("ERREUR SUPABASE: $e");
                                        _showSnack(ctx, 'Erreur: $e', kRed);
                                      }

                                      sd(() => isSaving = false);
                                    },
                              icon: isSaving
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      LucideIcons.folderPlus,
                                      size: 15,
                                      color: Colors.white,
                                    ),
                              label: Text(
                                isSaving ? 'Création...' : 'Créer le projet',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kAccent,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
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
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final pad = isMobile ? 16.0 : 28.0;
    final filtered = _filtered;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: kAccent));
    }

    return Container(
      color: kBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mes Projets',
                        style: TextStyle(
                          fontSize: isMobile ? 26 : 28,
                          fontWeight: FontWeight.w800,
                          color: kTextMain,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Gérez tous vos projets de construction',
                        style: TextStyle(color: kTextSub, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: showAddProjetDialog,
                  icon: const Icon(
                    LucideIcons.plus,
                    size: 15,
                    color: Colors.white,
                  ),
                  label: Text(
                    isMobile ? 'Nouveau' : 'Nouveau projet',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccent,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 18,
                      vertical: isMobile ? 10 : 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Stats ─────────────────────────────────────────────────────
            LayoutBuilder(builder: (ctx, c) {
              final stats = [
                _StatData('Total', '${projets.length}', LucideIcons.layoutGrid, kAccent),
                _StatData('En cours', '${projets.where((p) => p.statut == "en_cours").length}', LucideIcons.activity, const Color(0xFF3B82F6)),
                _StatData('Planification', '${projets.where((p) => p.statut == "en_attente").length}', LucideIcons.clock, const Color(0xFFF59E0B)),
                _StatData('Terminés', '${projets.where((p) => p.statut == "termine").length}', LucideIcons.checkCircle, const Color(0xFF10B981)),
              ];
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: stats.map((s) => SizedBox(
                  width: c.maxWidth < 500
                      ? (c.maxWidth - 10) / 2
                      : (c.maxWidth - 30) / 4,
                  child: _MiniStat(label: s.label, value: s.value, icon: s.icon, color: s.color),
                )).toList(),
              );
            }),

            const SizedBox(height: 20),

            // ── Recherche + Tri ───────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: kCardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: const TextStyle(fontSize: 13, color: kTextMain),
                      decoration: const InputDecoration(
                        hintText: 'Rechercher un projet...',
                        hintStyle: TextStyle(color: kTextSub, fontSize: 13),
                        prefixIcon: Icon(LucideIcons.search, size: 15, color: kTextSub),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 11),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  height: 40,
                  decoration: BoxDecoration(
                    color: kCardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sortBy,
                      style: const TextStyle(fontSize: 12, color: kTextMain),
                      icon: const Icon(LucideIcons.chevronsUpDown, size: 13, color: kTextSub),
                      dropdownColor: Colors.white,
                      items: const [
                        DropdownMenuItem(value: 'statut', child: Text('Trier : Statut')),
                        DropdownMenuItem(value: 'nom', child: Text('Trier : Nom')),
                        DropdownMenuItem(value: 'avancement', child: Text('Trier : Avancement')),
                      ],
                      onChanged: (v) => setState(() => _sortBy = v ?? 'statut'),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Filtres ───────────────────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  'Tous',
                  'En cours',
                  'Planification',
                  'Terminé',
                  'Annulé',
                ].map((l) => _buildFilter(l)).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // ── Liste projets ─────────────────────────────────────────────
            if (filtered.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Column(
                    children: [
                      Icon(LucideIcons.folderOpen, size: 48, color: kTextSub.withOpacity(0.4)),
                      const SizedBox(height: 14),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'Aucun résultat pour "$_searchQuery"'
                            : selectedFilter == 'Tous'
                                ? 'Aucun projet trouvé'
                                : 'Aucun projet "$selectedFilter"',
                        style: const TextStyle(color: kTextSub, fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Appuyez sur "Nouveau projet" pour commencer',
                        style: TextStyle(color: kTextSub.withOpacity(0.6), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 900) {
                    return _ProjetGrid(projects: filtered, columns: 3, onRefresh: loadProjets);
                  }
                  if (constraints.maxWidth > 580) {
                    return _ProjetGrid(projects: filtered, columns: 2, onRefresh: loadProjets);
                  }
                  return Column(
                    children: filtered.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ProjetDetailScreen(project: p, projectIndex: 0),
                        )),
                        child: ProjectFullCard(project: p),
                      ),
                    )).toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilter(String label) {
    final isSelected = selectedFilter == label;
    final color = label == 'Tous' ? kAccent : _statusColor(label);
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: () => setState(() => selectedFilter = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? color : kCardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE5E7EB),
              width: isSelected ? 0 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : kTextSub,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  GRID DESKTOP/TABLETTE
// ══════════════════════════════════════════════════════════════════════════════
class _ProjetGrid extends StatelessWidget {
  final List<Project> projects;
  final int columns;
  final VoidCallback onRefresh;
  const _ProjetGrid({
    required this.projects,
    required this.columns,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (int i = 0; i < projects.length; i += columns) {
      final rowItems = projects.skip(i).take(columns).toList();
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int j = 0; j < rowItems.length; j++) ...[
                if (j > 0) const SizedBox(width: 20),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProjetDetailScreen(
                          project: rowItems[j],
                          projectIndex: 0,
                        ),
                      ),
                    ),
                    child: ProjectFullCard(project: rowItems[j]),
                  ),
                ),
              ],
              for (int k = rowItems.length; k < columns; k++) ...[
                const SizedBox(width: 20),
                const Expanded(child: SizedBox()),
              ],
            ],
          ),
        ),
      );
      if (i + columns < projects.length) rows.add(const SizedBox(height: 20));
    }
    return Column(children: rows);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  HELPERS WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

/// Dropdown stylé avec label au-dessus — cohérent avec _ProjetField
class _DropdownField extends StatelessWidget {
  final String label, hint;
  final IconData icon;
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  const _DropdownField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
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
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            hint: Row(
              children: [
                Icon(icon, size: 14, color: kTextSub),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hint,
                    style: const TextStyle(color: kTextSub, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            icon: const Icon(
              LucideIcons.chevronsUpDown,
              size: 14,
              color: kTextSub,
            ),
            dropdownColor: Colors.white,
            style: const TextStyle(fontSize: 13, color: kTextMain),
            items: items,
            onChanged: onChanged,
          ),
        ),
      ),
    ],
  );
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _MiniStat({
    required this.label,
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
          label,
          style: const TextStyle(color: kTextSub, fontSize: 11),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

class _ProjetField extends StatelessWidget {
  final IconData icon;
  final String label, hint;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final int maxLines;

  const _ProjetField({
    required this.icon,
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
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
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 13, color: kTextMain),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: kTextSub),
          prefixIcon: maxLines == 1
              ? Icon(icon, size: 14, color: kTextSub)
              : null,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: maxLines > 1 ? 14 : 10,
            vertical: maxLines > 1 ? 12 : 11,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: kAccent, width: 2),
          ),
        ),
      ),
    ],
  );
}

class _StatData {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatData(this.label, this.value, this.icon, this.color);
}

// ── Champ localisation avec sélecteur carte ───────────────────────────────────
class _LocationField extends StatelessWidget {
  final TextEditingController controller;
  final LatLng? pickedPosition;
  final VoidCallback onPickMap;
  final VoidCallback onClearPosition;

  const _LocationField({
    required this.controller,
    required this.pickedPosition,
    required this.onPickMap,
    required this.onClearPosition,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('LOCALISATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSub, letterSpacing: 0.5)),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        style: const TextStyle(fontSize: 13, color: kTextMain),
        decoration: InputDecoration(
          hintText: 'Tunis, Djerba...',
          hintStyle: const TextStyle(color: kTextSub),
          prefixIcon: const Icon(LucideIcons.mapPin, size: 14, color: kTextSub),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          filled: true,
          fillColor: Colors.white,
          border:        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kAccent, width: 2)),
        ),
      ),
      const SizedBox(height: 6),
      // Bouton sélecteur carte + affichage coordonnées
      if (pickedPosition == null)
        GestureDetector(
          onTap: onPickMap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: kAccent.withOpacity(0.07),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: kAccent.withOpacity(0.25)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.mapPin, size: 12, color: kAccent),
              SizedBox(width: 5),
              Text('Épingler sur la carte', style: TextStyle(fontSize: 11, color: kAccent, fontWeight: FontWeight.w600)),
            ]),
          ),
        )
      else
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.08),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
          ),
          child: Row(children: [
            const Icon(LucideIcons.checkCircle, size: 12, color: Color(0xFF10B981)),
            const SizedBox(width: 5),
            Expanded(child: Text(
              '${pickedPosition!.latitude.toStringAsFixed(5)}, ${pickedPosition!.longitude.toStringAsFixed(5)}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            )),
            GestureDetector(
              onTap: onPickMap,
              child: const Icon(LucideIcons.pencil, size: 11, color: Color(0xFF10B981)),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onClearPosition,
              child: const Icon(Icons.close_rounded, size: 13, color: Color(0xFF10B981)),
            ),
          ]),
        ),
    ]);
  }
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
