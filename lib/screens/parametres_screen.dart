import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';
import '../models/architecte.dart';
import '../service/auth_service.dart';

class ParametresScreen extends StatefulWidget {
  const ParametresScreen({super.key});
  @override
  State<ParametresScreen> createState() => _ParametresScreenState();
}

class _ParametresScreenState extends State<ParametresScreen> {
  // ── Profil ─────────────────────────────────────────────────────────────────
  late final TextEditingController _prenomCtrl;
  late final TextEditingController _nomCtrl;
  late final TextEditingController _telCtrl;
  late final TextEditingController _cabinetCtrl;

  // ── Mot de passe ───────────────────────────────────────────────────────────
  final _ancienMdpCtrl  = TextEditingController();
  final _nouveauMdpCtrl = TextEditingController();
  final _confirmMdpCtrl = TextEditingController();
  bool _showAncien  = false;
  bool _showNouveau = false;
  bool _showConfirm = false;
  bool _savingMdp   = false;

  // ── Notifications ──────────────────────────────────────────────────────────
  bool _emailNotif    = true;
  bool _pushNotif     = true;
  bool _majProjets    = true;
  bool _commentaires  = true;
  bool _tachesDemain  = true;
  bool _congesEquipe  = true;
  bool _reunions      = true;

  // ── État ───────────────────────────────────────────────────────────────────
  bool _hasChanges = false;
  bool _saving     = false;
  late Map<String, String> _initialText;

  Architecte get _user => AuthService.currentUser!;

  @override
  void initState() {
    super.initState();
    final u = _user;
    _prenomCtrl  = TextEditingController(text: u.prenom);
    _nomCtrl     = TextEditingController(text: u.nom);
    _telCtrl     = TextEditingController(text: u.telephone ?? '');
    _cabinetCtrl = TextEditingController(text: u.cabinet ?? '');
    _initialText = {
      'prenom':  u.prenom,
      'nom':     u.nom,
      'tel':     u.telephone ?? '',
      'cabinet': u.cabinet ?? '',
    };
    for (final c in [_prenomCtrl, _nomCtrl, _telCtrl, _cabinetCtrl]) {
      c.addListener(_checkChanges);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _prenomCtrl, _nomCtrl, _telCtrl, _cabinetCtrl,
      _ancienMdpCtrl, _nouveauMdpCtrl, _confirmMdpCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _checkChanges() {
    final changed =
        _prenomCtrl.text  != _initialText['prenom']  ||
        _nomCtrl.text     != _initialText['nom']      ||
        _telCtrl.text     != _initialText['tel']      ||
        _cabinetCtrl.text != _initialText['cabinet'];
    if (changed != _hasChanges) setState(() => _hasChanges = changed);
  }

  void _cancel() {
    setState(() {
      _prenomCtrl.text  = _initialText['prenom']!;
      _nomCtrl.text     = _initialText['nom']!;
      _telCtrl.text     = _initialText['tel']!;
      _cabinetCtrl.text = _initialText['cabinet']!;
      _hasChanges = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = Architecte(
        id:        _user.id,
        nom:       _nomCtrl.text.trim(),
        prenom:    _prenomCtrl.text.trim(),
        email:     _user.email,
        telephone: _telCtrl.text.trim().isEmpty ? null : _telCtrl.text.trim(),
        cabinet:   _cabinetCtrl.text.trim().isEmpty ? null : _cabinetCtrl.text.trim(),
        createdAt: _user.createdAt,
      );
      await AuthService.updateCurrentUser(updated);
      _initialText = {
        'prenom':  updated.prenom,
        'nom':     updated.nom,
        'tel':     updated.telephone ?? '',
        'cabinet': updated.cabinet ?? '',
      };
      setState(() { _hasChanges = false; _saving = false; });
      _snack('✓ Profil mis à jour', const Color(0xFF10B981));
    } catch (e) {
      setState(() => _saving = false);
      _snack('Erreur : $e', kRed);
    }
  }

  Future<void> _changePassword() async {
    final ancien  = _ancienMdpCtrl.text;
    final nouveau = _nouveauMdpCtrl.text;
    final confirm = _confirmMdpCtrl.text;

    if (ancien.isEmpty || nouveau.isEmpty || confirm.isEmpty) {
      _snack('Remplissez tous les champs', kRed); return;
    }
    if (nouveau.length < 6) {
      _snack('Mot de passe min. 6 caractères', kRed); return;
    }
    if (nouveau != confirm) {
      _snack('Les mots de passe ne correspondent pas', kRed); return;
    }
    if (nouveau == ancien) {
      _snack('Le nouveau mot de passe est identique à l\'ancien', kRed); return;
    }

    setState(() => _savingMdp = true);
    try {
      // Vérifier l'ancien mot de passe par re-authentification
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: _user.email,
        password: ancien,
      );
      if (res.user == null) throw Exception('Mot de passe actuel incorrect');

      // Mettre à jour le mot de passe
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: nouveau),
      );

      _ancienMdpCtrl.clear();
      _nouveauMdpCtrl.clear();
      _confirmMdpCtrl.clear();
      setState(() => _savingMdp = false);
      _snack('✓ Mot de passe modifié avec succès', const Color(0xFF10B981));
    } on AuthException catch (e) {
      setState(() => _savingMdp = false);
      final msg = e.message.toLowerCase().contains('invalid')
          ? 'Mot de passe actuel incorrect'
          : e.message;
      _snack(msg, kRed);
    } catch (e) {
      setState(() => _savingMdp = false);
      _snack('Erreur : $e', kRed);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          msg.startsWith('✓') ? LucideIcons.checkCircle : LucideIcons.alertCircle,
          color: Colors.white, size: 15,
        ),
        const SizedBox(width: 8),
        Flexible(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500))),
      ]),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final pad = isMobile ? 16.0 : 28.0;

    return Container(
      color: kBg,
      child: Column(
        children: [
          // ── Contenu scrollable ───────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(pad, pad, pad, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kAccent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.settings_rounded, color: kAccent, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Paramètres', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: kTextMain)),
                        Text('Configurez votre profil et vos préférences', style: TextStyle(color: kTextSub, fontSize: 12)),
                      ],
                    )),
                  ]),

                  const SizedBox(height: 28),

                  LayoutBuilder(builder: (context, constraints) {
                    final wide = constraints.maxWidth > 700;

                    final profilCard = _ProfilCard(
                      user:        _user,
                      prenomCtrl:  _prenomCtrl,
                      nomCtrl:     _nomCtrl,
                      telCtrl:     _telCtrl,
                      cabinetCtrl: _cabinetCtrl,
                    );

                    final mdpCard = _MdpCard(
                      ancienCtrl:    _ancienMdpCtrl,
                      nouveauCtrl:   _nouveauMdpCtrl,
                      confirmCtrl:   _confirmMdpCtrl,
                      showAncien:    _showAncien,
                      showNouveau:   _showNouveau,
                      showConfirm:   _showConfirm,
                      saving:        _savingMdp,
                      onToggleAncien:  () => setState(() => _showAncien  = !_showAncien),
                      onToggleNouveau: () => setState(() => _showNouveau = !_showNouveau),
                      onToggleConfirm: () => setState(() => _showConfirm = !_showConfirm),
                      onSave: _changePassword,
                    );

                    final notifCard = _NotifCard(
                      emailNotif:   _emailNotif,
                      pushNotif:    _pushNotif,
                      majProjets:   _majProjets,
                      commentaires: _commentaires,
                      tachesDemain: _tachesDemain,
                      congesEquipe: _congesEquipe,
                      reunions:     _reunions,
                      onEmailChanged:   (v) => setState(() => _emailNotif   = v),
                      onPushChanged:    (v) => setState(() => _pushNotif    = v),
                      onMajChanged:     (v) => setState(() => _majProjets   = v),
                      onCommChanged:    (v) => setState(() => _commentaires = v),
                      onTachesChanged:  (v) => setState(() => _tachesDemain = v),
                      onCongesChanged:  (v) => setState(() => _congesEquipe = v),
                      onReunionsChanged:(v) => setState(() => _reunions     = v),
                    );

                    if (wide) {
                      return Column(children: [
                        IntrinsicHeight(child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: profilCard),
                            const SizedBox(width: 20),
                            Expanded(child: notifCard),
                          ],
                        )),
                        const SizedBox(height: 20),
                        mdpCard,
                      ]);
                    }

                    return Column(children: [
                      profilCard,
                      const SizedBox(height: 16),
                      mdpCard,
                      const SizedBox(height: 16),
                      notifCard,
                    ]);
                  }),
                ],
              ),
            ),
          ),

          // ── Barre d'actions — visible seulement si modifié ───────────────
          if (_hasChanges)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: Container(
                padding: EdgeInsets.fromLTRB(pad, 12, pad, 12),
                decoration: const BoxDecoration(
                  color: kCardBg,
                  border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: isMobile
                    ? Column(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(LucideIcons.save, size: 15, color: Colors.white),
                            label: const Text('Enregistrer les modifications', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kAccent, elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _cancel,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: Color(0xFFD1D5DB)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Annuler', style: TextStyle(color: kTextSub, fontSize: 14)),
                          ),
                        ),
                      ])
                    : Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        OutlinedButton(
                          onPressed: _cancel,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            side: const BorderSide(color: Color(0xFFD1D5DB)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Annuler', style: TextStyle(color: kTextSub)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(LucideIcons.save, size: 15, color: Colors.white),
                          label: const Text('Enregistrer les modifications', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kAccent, elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ]),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Profil Card ──────────────────────────────────────────────────────────────
class _ProfilCard extends StatelessWidget {
  final Architecte user;
  final TextEditingController prenomCtrl;
  final TextEditingController nomCtrl;
  final TextEditingController telCtrl;
  final TextEditingController cabinetCtrl;

  const _ProfilCard({
    required this.user,
    required this.prenomCtrl,
    required this.nomCtrl,
    required this.telCtrl,
    required this.cabinetCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(LucideIcons.user, color: kTextSub, size: 18),
            SizedBox(width: 10),
            Text('Informations du profil', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextMain)),
          ]),

          const SizedBox(height: 20),

          // Avatar avec initiales
          Center(child: Column(children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: kAccent.withOpacity(0.15),
              child: Text(user.initials, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: kAccent)),
            ),
            const SizedBox(height: 8),
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(LucideIcons.mail, size: 12, color: kTextSub),
              const SizedBox(width: 4),
              Text(user.email, style: const TextStyle(fontSize: 12, color: kTextSub)),
            ]),
          ])),

          const SizedBox(height: 24),

          Row(children: [
            Expanded(child: _Field(icon: LucideIcons.user, label: 'Prénom', controller: prenomCtrl)),
            const SizedBox(width: 16),
            Expanded(child: _Field(icon: LucideIcons.user, label: 'Nom', controller: nomCtrl)),
          ]),
          const SizedBox(height: 16),
          _Field(icon: LucideIcons.phone, label: 'Téléphone', controller: telCtrl, keyboardType: TextInputType.phone),
          const SizedBox(height: 16),
          _Field(icon: LucideIcons.building2, label: 'Cabinet / Entreprise', controller: cabinetCtrl),
        ],
      ),
    );
  }
}

// ─── Mot de passe Card ────────────────────────────────────────────────────────
class _MdpCard extends StatelessWidget {
  final TextEditingController ancienCtrl;
  final TextEditingController nouveauCtrl;
  final TextEditingController confirmCtrl;
  final bool showAncien;
  final bool showNouveau;
  final bool showConfirm;
  final bool saving;
  final VoidCallback onToggleAncien;
  final VoidCallback onToggleNouveau;
  final VoidCallback onToggleConfirm;
  final VoidCallback onSave;

  const _MdpCard({
    required this.ancienCtrl,
    required this.nouveauCtrl,
    required this.confirmCtrl,
    required this.showAncien,
    required this.showNouveau,
    required this.showConfirm,
    required this.saving,
    required this.onToggleAncien,
    required this.onToggleNouveau,
    required this.onToggleConfirm,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(LucideIcons.lock, color: kTextSub, size: 18),
            SizedBox(width: 10),
            Text('Changer le mot de passe', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextMain)),
          ]),
          const SizedBox(height: 6),
          const Text('Vérification de votre mot de passe actuel requise.', style: TextStyle(color: kTextSub, fontSize: 12)),
          const SizedBox(height: 20),

          isMobile
              ? Column(children: [
                  _PwdField(label: 'Mot de passe actuel',     ctrl: ancienCtrl,  show: showAncien,  onToggle: onToggleAncien),
                  const SizedBox(height: 14),
                  _PwdField(label: 'Nouveau mot de passe',    ctrl: nouveauCtrl, show: showNouveau, onToggle: onToggleNouveau),
                  const SizedBox(height: 14),
                  _PwdField(label: 'Confirmer le mot de passe', ctrl: confirmCtrl, show: showConfirm, onToggle: onToggleConfirm),
                ])
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: _PwdField(label: 'Mot de passe actuel',       ctrl: ancienCtrl,  show: showAncien,  onToggle: onToggleAncien)),
                  const SizedBox(width: 14),
                  Expanded(child: _PwdField(label: 'Nouveau mot de passe',      ctrl: nouveauCtrl, show: showNouveau, onToggle: onToggleNouveau)),
                  const SizedBox(width: 14),
                  Expanded(child: _PwdField(label: 'Confirmer le mot de passe', ctrl: confirmCtrl, show: showConfirm, onToggle: onToggleConfirm)),
                ]),

          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: saving ? null : onSave,
              icon: saving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(LucideIcons.keyRound, size: 14, color: Colors.white),
              label: const Text('Changer le mot de passe', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccent, elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Notifications Card ───────────────────────────────────────────────────────
class _NotifCard extends StatelessWidget {
  final bool emailNotif, pushNotif, majProjets, commentaires, tachesDemain, congesEquipe, reunions;
  final ValueChanged<bool> onEmailChanged, onPushChanged, onMajChanged, onCommChanged,
      onTachesChanged, onCongesChanged, onReunionsChanged;

  const _NotifCard({
    required this.emailNotif,
    required this.pushNotif,
    required this.majProjets,
    required this.commentaires,
    required this.tachesDemain,
    required this.congesEquipe,
    required this.reunions,
    required this.onEmailChanged,
    required this.onPushChanged,
    required this.onMajChanged,
    required this.onCommChanged,
    required this.onTachesChanged,
    required this.onCongesChanged,
    required this.onReunionsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(LucideIcons.bell, color: kTextSub, size: 18),
            SizedBox(width: 10),
            Text('Contrôle des notifications', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextMain)),
          ]),
          const SizedBox(height: 4),
          const Text('Gérez comment et pourquoi vous souhaitez être alerté.', style: TextStyle(color: kTextSub, fontSize: 12)),
          const SizedBox(height: 20),

          _SectionLabel(label: "CANAUX D'ENVOI"),
          const SizedBox(height: 10),
          _ToggleCard(icon: LucideIcons.mail,       iconColor: kAccent, title: 'Notifications par Email',        subtitle: 'Récapitulatif et alertes importantes sur votre boîte mail.',         value: emailNotif, onChanged: onEmailChanged),
          const SizedBox(height: 10),
          _ToggleCard(icon: LucideIcons.smartphone, iconColor: kAccent, title: 'Notifications Push / In-App',    subtitle: 'Alertes instantanées sur votre tableau de bord et mobile.',          value: pushNotif,  onChanged: onPushChanged),
          const SizedBox(height: 20),

          _SectionLabel(label: "TYPES D'ALERTES"),
          const SizedBox(height: 10),
          _ToggleRow(icon: LucideIcons.refreshCw,      label: 'Mises à jour des projets',                value: majProjets,   onChanged: onMajChanged),
          _ToggleRow(icon: LucideIcons.messageSquare,  label: 'Commentaires des clients (avancement)',   value: commentaires,  onChanged: onCommChanged),
          _ToggleRow(icon: LucideIcons.calendarCheck,  label: 'Tâches qui commencent demain',            value: tachesDemain,  onChanged: onTachesChanged),
          _ToggleRow(icon: LucideIcons.umbrella,       label: "Rappels pour les congés d'équipe",        value: congesEquipe,  onChanged: onCongesChanged),
          _ToggleRow(icon: LucideIcons.calendarClock,  label: 'Rappels de tâches et réunions',           value: reunions,      onChanged: onReunionsChanged, isLast: true),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: kCardBg,
      borderRadius: BorderRadius.circular(14),
      border: const Border(left: BorderSide(color: kAccent, width: 3)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: child,
  );
}

class _Field extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;

  const _Field({
    required this.icon,
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Icon(icon, size: 13, color: kTextSub),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: kTextSub, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 7),
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: kTextMain, fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          filled: true,
          fillColor: Colors.white,
          border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kAccent, width: 2)),
        ),
      ),
    ],
  );
}

class _PwdField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool show;
  final VoidCallback onToggle;

  const _PwdField({required this.label, required this.ctrl, required this.show, required this.onToggle});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: kTextSub, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 7),
      TextField(
        controller: ctrl,
        obscureText: !show,
        style: const TextStyle(color: kTextMain, fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          filled: true,
          fillColor: Colors.white,
          border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kAccent, width: 2)),
          suffixIcon: IconButton(
            icon: Icon(show ? LucideIcons.eyeOff : LucideIcons.eye, size: 16, color: kTextSub),
            onPressed: onToggle,
          ),
        ),
      ),
    ],
  );
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(color: kTextSub, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8),
  );
}

class _ToggleCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleCard({
    required this.icon, required this.iconColor,
    required this.title, required this.subtitle,
    required this.value, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: Row(children: [
      Icon(icon, color: iconColor, size: 18),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: kTextMain)),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(color: kTextSub, fontSize: 11)),
      ])),
      Switch(value: value, onChanged: onChanged, activeColor: kAccent),
    ]),
  );
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isLast;

  const _ToggleRow({
    required this.icon, required this.label,
    required this.value, required this.onChanged,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Icon(icon, size: 16, color: kTextSub),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(color: kTextMain, fontSize: 13))),
        Switch(value: value, onChanged: onChanged, activeColor: kAccent, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
      ]),
    ),
    if (!isLast) const Divider(height: 1, color: Color(0xFFF3F4F6)),
  ]);
}
