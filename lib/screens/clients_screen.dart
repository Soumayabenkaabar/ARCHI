import 'package:archi_manager/service/client_service.dart';
import '../models/client.dart' show ClientStats;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../constants/colors.dart';
import '../models/client.dart';
import '../widgets/client_card.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final TextEditingController searchController = TextEditingController();

  List<Client> clients = [];
  Map<String, ClientStats> _projectStats = {};
  bool isLoading = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadClients();
  }

  Future<void> loadClients() async {
    try {
      final results = await Future.wait([
        ClientService.getClients(),
        ClientService.getProjectStats(),
      ]);
      if (!mounted) return;
      setState(() {
        clients       = results[0] as List<Client>;
        _projectStats = results[1] as Map<String, ClientStats>;
        isLoading     = false;
      });
    } catch (e) {
      debugPrint('Erreur chargement clients: $e');
    }
  }

  // ── Popup Ajouter / Modifier un client ──────────────────────────────────────
  void showAddClientDialog({Client? clientToEdit}) {
    final nomController = TextEditingController(text: clientToEdit?.nom ?? '');
    final emailController = TextEditingController(text: clientToEdit?.email ?? '');
    final telController = TextEditingController(text: clientToEdit?.telephone ?? '');

    final formKey = GlobalKey<FormState>();
    bool dialogLoading = false;
    bool accesPortail = clientToEdit?.accesPortail ?? true;
    final isEdit = clientToEdit != null;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final screenContext = context;

    showDialog(
      context: screenContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            return Dialog(
              insetPadding: isMobile
                  ? const EdgeInsets.fromLTRB(12, 24, 12, 24)
                  : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header ──────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: (isEdit ? kWarning : kAccent).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                isEdit ? LucideIcons.pencil : LucideIcons.userPlus,
                                color: isEdit ? kWarning : kAccent,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isEdit ? 'Modifier le client' : 'Ajouter un client',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: kTextMain,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isEdit
                                        ? 'Modifiez les informations du client'
                                        : 'Remplissez les informations du nouveau client',
                                    style: const TextStyle(color: kTextSub, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () => Navigator.pop(dialogContext),
                              borderRadius: BorderRadius.circular(8),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(LucideIcons.x, size: 16, color: kTextSub),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Champs ──────────────────────────────────────
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              _DialogField(
                                icon: LucideIcons.user,
                                label: 'NOM COMPLET *',
                                hint: 'Mohamed Ben Ali',
                                controller: nomController,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r"[a-zA-ZÀ-ÿ \-']")),
                                ],
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Nom obligatoire';
                                  if (v.trim().length < 2) return 'Minimum 2 caractères';
                                  if (v.trim().length > 100) return 'Maximum 100 caractères';
                                  if (!RegExp(r"^[a-zA-ZÀ-ÿ \-']+$").hasMatch(v.trim()))
                                    return 'Le nom ne doit contenir que des lettres';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),

                              _DialogField(
                                icon: LucideIcons.mail,
                                label: 'EMAIL *',
                                hint: 'contact@ocp.ma',
                                controller: emailController,
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Email obligatoire';
                                  final regex = RegExp(r'^[\w\.\-]+@[\w\-]+\.[a-z]{2,}$',
                                      caseSensitive: false);
                                  if (!regex.hasMatch(v.trim())) return 'Format email invalide';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),

                              _DialogField(
                                icon: LucideIcons.phone,
                                label: 'TÉLÉPHONE',
                                hint: '20000000',
                                controller: telController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(8),
                                ],
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return null;
                                  if (v.length != 8) return 'Le numéro doit contenir exactement 8 chiffres';
                                  final num = int.tryParse(v);
                                  if (num == null || num < 20000000) return 'Numéro invalide (min : 20000000)';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),

                              // Toggle Accès portail
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                ),
                                child: Row(
                                  children: [
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Accès portail client',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 13,
                                                color: kTextMain),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Le client recevra un email pour créer son mot de passe',
                                            style: TextStyle(color: kTextSub, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: accesPortail,
                                      onChanged: (v) => setStateDialog(() => accesPortail = v),
                                      activeColor: kAccent,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── Actions ─────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Annuler', style: TextStyle(color: kTextSub)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: dialogLoading
                                    ? null
                                    : () async {
                                        if (!formKey.currentState!.validate()) return;
                                        setStateDialog(() => dialogLoading = true);

                                        try {
                                          final client = Client(
                                            id: clientToEdit?.id ?? '',
                                            nom: nomController.text.trim().isNotEmpty
                                                ? nomController.text.trim()
                                                : clientToEdit?.nom ?? '',
                                            email: emailController.text.trim().isNotEmpty
                                                ? emailController.text.trim()
                                                : clientToEdit?.email ?? '',
                                            telephone: telController.text.trim().isNotEmpty
                                                ? telController.text.trim()
                                                : clientToEdit?.telephone ?? '',
                                            accesPortail: accesPortail,
                                          );

                                          if (isEdit) {
                                            // ── MODIFIER ──────────────────────────
                                            await ClientService.updateClient(client);
                                            if (dialogContext.mounted) Navigator.pop(dialogContext);
                                            await loadClients();
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(screenContext).showSnackBar(
                                              SnackBar(
                                                content: const Text('Client modifié avec succès'),
                                                backgroundColor: kAccent,
                                                behavior: SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8)),
                                              ),
                                            );
                                          } else {
                                            // ── AJOUTER ───────────────────────────
                                            await ClientService.addClient(client);
                                            if (dialogContext.mounted) Navigator.pop(dialogContext);
                                            await loadClients();
                                            if (!mounted) return;

                                            if (client.accesPortail && client.email.isNotEmpty) {
                                              showDialog(
                                                context: screenContext,
                                                builder: (ctx) => AlertDialog(
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(16)),
                                                  title: const Row(
                                                    children: [
                                                      Icon(LucideIcons.mailCheck,
                                                          color: kAccent, size: 20),
                                                      SizedBox(width: 10),
                                                      Text(
                                                        'Invitation envoyée',
                                                        style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.w700),
                                                      ),
                                                    ],
                                                  ),
                                                  content: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      _InfoTile(
                                                        icon: LucideIcons.user,
                                                        label: 'Client',
                                                        value: client.nom,
                                                      ),
                                                      const SizedBox(height: 10),
                                                      _InfoTile(
                                                        icon: LucideIcons.mail,
                                                        label: 'Email',
                                                        value: client.email,
                                                      ),
                                                      const SizedBox(height: 14),
                                                      Container(
                                                        padding: const EdgeInsets.all(12),
                                                        decoration: BoxDecoration(
                                                          color: kAccent.withOpacity(0.07),
                                                          borderRadius: BorderRadius.circular(8),
                                                          border: Border.all(
                                                              color: kAccent.withOpacity(0.2)),
                                                        ),
                                                        child: const Row(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment.start,
                                                          children: [
                                                            Icon(LucideIcons.info,
                                                                size: 14, color: kAccent),
                                                            SizedBox(width: 8),
                                                            Expanded(
                                                              child: Text(
                                                                'Un email d\'invitation a été envoyé. Le client définit lui-même son mot de passe via le lien reçu.',
                                                                style: TextStyle(
                                                                    fontSize: 11, color: kAccent),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  actions: [
                                                    ElevatedButton(
                                                      onPressed: () => Navigator.pop(ctx),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: kAccent,
                                                        elevation: 0,
                                                        shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(8)),
                                                      ),
                                                      child: const Text('OK, compris',
                                                          style: TextStyle(color: Colors.white)),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            } else {
                                              ScaffoldMessenger.of(screenContext).showSnackBar(
                                                SnackBar(
                                                  content: const Text('Client ajouté avec succès'),
                                                  backgroundColor: kAccent,
                                                  behavior: SnackBarBehavior.floating,
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8)),
                                                ),
                                              );
                                            }
                                          }
                                        } catch (e) {
                                          if (dialogContext.mounted) {
                                            setStateDialog(() => dialogLoading = false);
                                          }
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(screenContext).showSnackBar(
                                            SnackBar(content: Text('Erreur: $e')),
                                          );
                                        }
                                      },
                                icon: dialogLoading
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2, color: Colors.white),
                                      )
                                    : Icon(
                                        isEdit ? LucideIcons.check : LucideIcons.userPlus,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                label: Text(
                                  isEdit ? 'Enregistrer' : 'Ajouter le client',
                                  style: const TextStyle(
                                      color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isEdit ? kWarning : kAccent,
                                  elevation: 0,
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
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
        );
      },
    );
  }

  // ── Popup Consulter un client ───────────────────────────────────────────────
  void showViewClientDialog(Client client, {ClientStats? stats}) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: MediaQuery.of(dialogContext).size.width < 600
              ? const EdgeInsets.fromLTRB(12, 24, 12, 24)
              : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: kAccent.withOpacity(0.15),
                        child: Text(
                          client.nom.isNotEmpty ? client.nom[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: kAccent, fontWeight: FontWeight.w700, fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(client.nom,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: kTextMain)),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.pop(dialogContext),
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(LucideIcons.x, size: 16, color: kTextSub),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Infos ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: LucideIcons.mail,
                        label: 'Email',
                        value: client.email.isNotEmpty ? client.email : '—',
                      ),
                      const SizedBox(height: 10),
                      _InfoRow(
                        icon: LucideIcons.phone,
                        label: 'Téléphone',
                        value: client.telephone.isNotEmpty ? client.telephone : '—',
                      ),
                      const SizedBox(height: 10),
                      _InfoRow(
                        icon: LucideIcons.briefcase,
                        label: 'Projets',
                        value: '${stats?.total ?? 0} projet(s)',
                      ),
                      if (stats != null && stats.total > 0) ...[
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          if (stats.enCours   > 0) _StatutPill(label: 'En cours',      count: stats.enCours,   color: kAccent),
                          if (stats.enAttente > 0) _StatutPill(label: 'Planification', count: stats.enAttente, color: const Color(0xFFF59E0B)),
                          if (stats.termine   > 0) _StatutPill(label: 'Terminé',       count: stats.termine,   color: const Color(0xFF10B981)),
                          if (stats.annule    > 0) _StatutPill(label: 'Annulé',        count: stats.annule,    color: kRed),
                        ]),
                      ],
                      const SizedBox(height: 10),
                      _InfoRow(
                        icon: LucideIcons.calendar,
                        label: 'Client depuis',
                        value: client.dateDepuisDisplay,
                      ),
                      const SizedBox(height: 10),
                      _InfoRow(
                        icon: LucideIcons.shieldCheck,
                        label: 'Accès portail',
                        value: client.accesPortail ? 'Activé' : 'Désactivé',
                        valueColor: client.accesPortail ? kGreen : kTextSub,
                      ),
                    ],
                  ),
                ),

                // ── Actions ───────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            side: const BorderSide(color: Color(0xFFD1D5DB)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Fermer', style: TextStyle(color: kTextSub)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            showAddClientDialog(clientToEdit: client);
                          },
                          icon: const Icon(LucideIcons.pencil, size: 14, color: Colors.white),
                          label: const Text('Modifier',
                              style: TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kWarning,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
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
    );
  }

  // ── Confirmation suppression ────────────────────────────────────────────────
  void showDeleteConfirmDialog(Client client) {
    final screenContext = context;
    showDialog(
      context: screenContext,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration:
                  BoxDecoration(color: kRed.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(LucideIcons.trash2, color: kRed, size: 22),
            ),
            const SizedBox(height: 14),
            const Text(
              'Supprimer le client',
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 16, color: kTextMain),
            ),
            const SizedBox(height: 8),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(color: kTextSub, fontSize: 13),
                children: [
                  const TextSpan(text: 'Êtes-vous sûr de vouloir supprimer '),
                  TextSpan(
                    text: client.nom,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: kTextMain),
                  ),
                  const TextSpan(text: ' ? Cette action est irréversible.'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Annuler', style: TextStyle(color: kTextSub)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    try {
                      if (client.id.isNotEmpty) {
                        await ClientService.deleteClient(client.id);
                      }
                      await loadClients();
                      if (!mounted) return;
                      ScaffoldMessenger.of(screenContext).showSnackBar(
                        SnackBar(
                          content: const Text('Client supprimé'),
                          backgroundColor: kRed,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(screenContext).showSnackBar(
                        SnackBar(content: Text('Erreur: $e')),
                      );
                    }
                  },
                  icon: const Icon(LucideIcons.trash2, size: 14, color: Colors.white),
                  label: const Text('Supprimer',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kRed,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final pad = isMobile ? 16.0 : 28.0;

    final filteredClients = clients.where((c) {
      final name = c.nom.toLowerCase();
      final email = c.email.toLowerCase();
      return name.contains(searchQuery.toLowerCase()) ||
          email.contains(searchQuery.toLowerCase());
    }).toList();

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: kBg,
      child: RefreshIndicator(
        onRefresh: loadClients,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── HEADER ───────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Clients',
                      style: TextStyle(
                        fontSize: isMobile ? 24 : 28,
                        fontWeight: FontWeight.w800,
                        color: kTextMain,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => showAddClientDialog(),
                    icon: const Icon(LucideIcons.userPlus, size: 15, color: Colors.white),
                    label: Text(
                      isMobile ? 'Nouveau' : 'Nouveau client',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccent,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 18,
                        vertical: isMobile ? 10 : 14,
                      ),
                      shape:
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Gérez votre base de clients et leurs accès',
                style: TextStyle(color: kTextSub, fontSize: isMobile ? 12 : 14),
              ),
              const SizedBox(height: 20),

              // ── SEARCH ───────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.1)),
                ),
                child: TextField(
                  controller: searchController,
                  onChanged: (v) => setState(() => searchQuery = v),
                  decoration: const InputDecoration(
                    icon: Icon(LucideIcons.search, size: 18),
                    hintText: 'Rechercher un client...',
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── LISTE ────────────────────────────────────────────
              if (filteredClients.isEmpty)
                const Center(child: Text('Aucun client trouvé')),

              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 580) {
                    return Column(
                      children: filteredClients
                          .map((c) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: ClientCard(
                                  client: c,
                                  stats: _projectStats[c.id],
                                  onView: () => showViewClientDialog(c, stats: _projectStats[c.id]),
                                  onEdit: () => showAddClientDialog(clientToEdit: c),
                                  onDelete: () => showDeleteConfirmDialog(c),
                                ),
                              ))
                          .toList(),
                    );
                  }

                  final rows = <Widget>[];
                  for (int i = 0; i < filteredClients.length; i += 2) {
                    final rowItems = filteredClients.skip(i).take(2).toList();
                    rows.add(
                      IntrinsicHeight(
                        child: Row(
                          children: [
                            Expanded(
                              child: ClientCard(
                                client: rowItems[0],
                                stats: _projectStats[rowItems[0].id],
                                onView: () => showViewClientDialog(rowItems[0], stats: _projectStats[rowItems[0].id]),
                                onEdit: () =>
                                    showAddClientDialog(clientToEdit: rowItems[0]),
                                onDelete: () => showDeleteConfirmDialog(rowItems[0]),
                              ),
                            ),
                            const SizedBox(width: 20),
                            if (rowItems.length > 1)
                              Expanded(
                                child: ClientCard(
                                  client: rowItems[1],
                                  stats: _projectStats[rowItems[1].id],
                                  onView: () => showViewClientDialog(rowItems[1], stats: _projectStats[rowItems[1].id]),
                                  onEdit: () =>
                                      showAddClientDialog(clientToEdit: rowItems[1]),
                                  onDelete: () => showDeleteConfirmDialog(rowItems[1]),
                                ),
                              )
                            else
                              const Expanded(child: SizedBox()),
                          ],
                        ),
                      ),
                    );
                    if (i + 2 < filteredClients.length) {
                      rows.add(const SizedBox(height: 20));
                    }
                  }
                  return Column(children: rows);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widget champ formulaire ────────────────────────────────────────────────────
class _DialogField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
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
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: kTextSub,
              letterSpacing: 0.5),
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
              borderSide: const BorderSide(color: kAccent, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: kRed),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tile info dans popup invitation ───────────────────────────────────────────
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: kTextSub),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10,
                        color: kTextSub,
                        fontWeight: FontWeight.w600)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 13,
                        color: kTextMain,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widget ligne d'info (popup consulter) ─────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: kTextSub),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      color: kTextSub,
                      fontWeight: FontWeight.w500)),
              Text(
                value,
                style: TextStyle(
                    fontSize: 13,
                    color: valueColor ?? kTextMain,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Pill statut (popup consulter) ─────────────────────────────────────────────
class _StatutPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatutPill({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text('$count $label', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    ]),
  );
}