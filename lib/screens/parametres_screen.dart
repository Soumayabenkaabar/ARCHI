import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../constants/colors.dart';

class ParametresScreen extends StatefulWidget {
  const ParametresScreen({super.key});

  @override
  State<ParametresScreen> createState() => _ParametresScreenState();
}

class _ParametresScreenState extends State<ParametresScreen> {
  // Profil
  final _prenomCtrl = TextEditingController(text: 'Ahmed');
  final _nomCtrl = TextEditingController(text: 'Bennani');
  final _emailCtrl = TextEditingController(text: 'ahmed.bennani@archi.ma');
  final _telCtrl = TextEditingController(text: '0661234567');
  final _entrepriseCtrl = TextEditingController(text: 'ArchiManager Pro');
  final _roleCtrl = TextEditingController(text: 'Architecte');

  // Canaux
  bool _emailNotif = true;
  bool _pushNotif = true;

  // Types d'alertes
  bool _majProjets = true;
  bool _commentaires = true;
  bool _tachesDemain = true;
  bool _congesEquipe = true;
  bool _reunions = true;

  // Suivi des modifications
  bool _hasChanges = false;

  // Valeurs initiales pour reset
  late final Map<String, String> _initialText;
  late final Map<String, bool> _initialBools;

  @override
  void initState() {
    super.initState();
    _initialText = {
      'prenom': _prenomCtrl.text,
      'nom': _nomCtrl.text,
      'email': _emailCtrl.text,
      'tel': _telCtrl.text,
      'entreprise': _entrepriseCtrl.text,
      'role': _roleCtrl.text,
    };
    _initialBools = {
      'email': _emailNotif,
      'push': _pushNotif,
      'maj': _majProjets,
      'comm': _commentaires,
      'taches': _tachesDemain,
      'conges': _congesEquipe,
      'reunions': _reunions,
    };
    for (final ctrl in [
      _prenomCtrl,
      _nomCtrl,
      _emailCtrl,
      _telCtrl,
      _entrepriseCtrl,
      _roleCtrl,
    ]) {
      ctrl.addListener(_checkChanges);
    }
  }

  void _checkChanges() {
    final textChanged =
        _prenomCtrl.text != _initialText['prenom'] ||
        _nomCtrl.text != _initialText['nom'] ||
        _emailCtrl.text != _initialText['email'] ||
        _telCtrl.text != _initialText['tel'] ||
        _entrepriseCtrl.text != _initialText['entreprise'] ||
        _roleCtrl.text != _initialText['role'];

    final boolChanged =
        _emailNotif != _initialBools['email'] ||
        _pushNotif != _initialBools['push'] ||
        _majProjets != _initialBools['maj'] ||
        _commentaires != _initialBools['comm'] ||
        _tachesDemain != _initialBools['taches'] ||
        _congesEquipe != _initialBools['conges'] ||
        _reunions != _initialBools['reunions'];

    final changed = textChanged || boolChanged;
    if (changed != _hasChanges) setState(() => _hasChanges = changed);
  }

  void _cancel() {
    setState(() {
      _prenomCtrl.text = _initialText['prenom']!;
      _nomCtrl.text = _initialText['nom']!;
      _emailCtrl.text = _initialText['email']!;
      _telCtrl.text = _initialText['tel']!;
      _entrepriseCtrl.text = _initialText['entreprise']!;
      _roleCtrl.text = _initialText['role']!;
      _emailNotif = _initialBools['email']!;
      _pushNotif = _initialBools['push']!;
      _majProjets = _initialBools['maj']!;
      _commentaires = _initialBools['comm']!;
      _tachesDemain = _initialBools['taches']!;
      _congesEquipe = _initialBools['conges']!;
      _reunions = _initialBools['reunions']!;
      _hasChanges = false;
    });
  }

  @override
  void dispose() {
    for (final ctrl in [
      _prenomCtrl,
      _nomCtrl,
      _emailCtrl,
      _telCtrl,
      _entrepriseCtrl,
      _roleCtrl,
    ]) {
      ctrl.removeListener(_checkChanges);
      ctrl.dispose();
    }
    super.dispose();
  }

  void _save() {
    // Mettre à jour les valeurs initiales
    _initialText['prenom'] = _prenomCtrl.text;
    _initialText['nom'] = _nomCtrl.text;
    _initialText['email'] = _emailCtrl.text;
    _initialText['tel'] = _telCtrl.text;
    _initialText['entreprise'] = _entrepriseCtrl.text;
    _initialText['role'] = _roleCtrl.text;
    _initialBools['email'] = _emailNotif;
    _initialBools['push'] = _pushNotif;
    _initialBools['maj'] = _majProjets;
    _initialBools['comm'] = _commentaires;
    _initialBools['taches'] = _tachesDemain;
    _initialBools['conges'] = _congesEquipe;
    _initialBools['reunions'] = _reunions;
    setState(() => _hasChanges = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Modifications enregistrées'),
        backgroundColor: kAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final pad = isMobile ? 16.0 : 28.0;

    return Container(
      color: kBg,
      child: Column(
        children: [
          // ── Contenu scrollable ─────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(pad, pad, pad, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ────────────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: kAccent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.settings_rounded,
                          color: kAccent,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Paramètres',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: kTextMain,
                              ),
                            ),
                            Text(
                              'Configurez votre profil et vos préférences',
                              style: TextStyle(color: kTextSub, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ── Deux colonnes desktop / colonne mobile ─────────────
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth > 700) {
                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _ProfilCard(
                                  prenomCtrl: _prenomCtrl,
                                  nomCtrl: _nomCtrl,
                                  emailCtrl: _emailCtrl,
                                  telCtrl: _telCtrl,
                                  entrepriseCtrl: _entrepriseCtrl,
                                  roleCtrl: _roleCtrl,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: _NotifCard(
                                  emailNotif: _emailNotif,
                                  pushNotif: _pushNotif,
                                  majProjets: _majProjets,
                                  commentaires: _commentaires,
                                  tachesDemain: _tachesDemain,
                                  congesEquipe: _congesEquipe,
                                  reunions: _reunions,
                                  onEmailChanged: (v) {
                                    setState(() => _emailNotif = v);
                                    _checkChanges();
                                  },
                                  onPushChanged: (v) {
                                    setState(() => _pushNotif = v);
                                    _checkChanges();
                                  },
                                  onMajChanged: (v) {
                                    setState(() => _majProjets = v);
                                    _checkChanges();
                                  },
                                  onCommChanged: (v) {
                                    setState(() => _commentaires = v);
                                    _checkChanges();
                                  },
                                  onTachesChanged: (v) {
                                    setState(() => _tachesDemain = v);
                                    _checkChanges();
                                  },
                                  onCongesChanged: (v) {
                                    setState(() => _congesEquipe = v);
                                    _checkChanges();
                                  },
                                  onReunionsChanged: (v) {
                                    setState(() => _reunions = v);
                                    _checkChanges();
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return Column(
                        children: [
                          _ProfilCard(
                            prenomCtrl: _prenomCtrl,
                            nomCtrl: _nomCtrl,
                            emailCtrl: _emailCtrl,
                            telCtrl: _telCtrl,
                            entrepriseCtrl: _entrepriseCtrl,
                            roleCtrl: _roleCtrl,
                          ),
                          const SizedBox(height: 16),
                          _NotifCard(
                            emailNotif: _emailNotif,
                            pushNotif: _pushNotif,
                            majProjets: _majProjets,
                            commentaires: _commentaires,
                            tachesDemain: _tachesDemain,
                            congesEquipe: _congesEquipe,
                            reunions: _reunions,
                            onEmailChanged: (v) =>
                                setState(() => _emailNotif = v),
                            onPushChanged: (v) =>
                                setState(() => _pushNotif = v),
                            onMajChanged: (v) =>
                                setState(() => _majProjets = v),
                            onCommChanged: (v) {
                              setState(() => _commentaires = v);
                              _checkChanges();
                            },
                            onTachesChanged: (v) {
                              setState(() => _tachesDemain = v);
                              _checkChanges();
                            },
                            onCongesChanged: (v) {
                              setState(() => _congesEquipe = v);
                              _checkChanges();
                            },
                            onReunionsChanged: (v) {
                              setState(() => _reunions = v);
                              _checkChanges();
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // ── Barre d'actions — visible seulement si modifié ─────────────
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
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _save,
                              icon: const Icon(
                                LucideIcons.save,
                                size: 15,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Enregistrer les modifications',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kAccent,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _cancel,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
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
                                style: TextStyle(color: kTextSub, fontSize: 14),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: _cancel,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              side: const BorderSide(color: Color(0xFFD1D5DB)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Annuler',
                              style: TextStyle(color: kTextSub),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _save,
                            icon: const Icon(
                              LucideIcons.save,
                              size: 15,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Enregistrer les modifications',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kAccent,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Profil Card ──────────────────────────────────────────────────────────────
class _ProfilCard extends StatelessWidget {
  final TextEditingController prenomCtrl;
  final TextEditingController nomCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController telCtrl;
  final TextEditingController entrepriseCtrl;
  final TextEditingController roleCtrl;

  const _ProfilCard({
    required this.prenomCtrl,
    required this.nomCtrl,
    required this.emailCtrl,
    required this.telCtrl,
    required this.entrepriseCtrl,
    required this.roleCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre section
          Row(
            children: const [
              Icon(LucideIcons.user, color: kTextSub, size: 18),
              SizedBox(width: 10),
              Text(
                'Informations du profil',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kTextMain,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Prénom + Nom côte à côte
          Row(
            children: [
              Expanded(
                child: _Field(
                  icon: LucideIcons.user,
                  label: 'Prénom',
                  controller: prenomCtrl,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _Field(
                  icon: LucideIcons.user,
                  label: 'Nom',
                  controller: nomCtrl,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _Field(
            icon: LucideIcons.mail,
            label: 'Email',
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
          ),

          const SizedBox(height: 16),

          _Field(
            icon: LucideIcons.phone,
            label: 'Téléphone',
            controller: telCtrl,
            keyboardType: TextInputType.phone,
          ),

          const SizedBox(height: 16),

          _Field(
            icon: LucideIcons.building2,
            label: 'Entreprise',
            controller: entrepriseCtrl,
          ),

          const SizedBox(height: 16),

          _Field(
            icon: LucideIcons.briefcase,
            label: 'Rôle',
            controller: roleCtrl,
          ),
        ],
      ),
    );
  }
}

// ─── Notifications Card ───────────────────────────────────────────────────────
class _NotifCard extends StatelessWidget {
  final bool emailNotif;
  final bool pushNotif;
  final bool majProjets;
  final bool commentaires;
  final bool tachesDemain;
  final bool congesEquipe;
  final bool reunions;
  final ValueChanged<bool> onEmailChanged;
  final ValueChanged<bool> onPushChanged;
  final ValueChanged<bool> onMajChanged;
  final ValueChanged<bool> onCommChanged;
  final ValueChanged<bool> onTachesChanged;
  final ValueChanged<bool> onCongesChanged;
  final ValueChanged<bool> onReunionsChanged;

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
          // Titre
          Row(
            children: const [
              Icon(LucideIcons.bell, color: kTextSub, size: 18),
              SizedBox(width: 10),
              Text(
                'Contrôle des notifications',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kTextMain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Gérez comment et pourquoi vous souhaitez être alerté.',
            style: TextStyle(color: kTextSub, fontSize: 12),
          ),

          const SizedBox(height: 20),

          // ── CANAUX D'ENVOI ─────────────────────────────────────────────
          _SectionLabel(label: "CANAUX D'ENVOI"),
          const SizedBox(height: 10),

          _ToggleCard(
            icon: LucideIcons.mail,
            iconColor: kAccent,
            title: 'Notifications par Email',
            subtitle:
                'Recevez un récapitulatif et des alertes importantes sur votre boîte mail.',
            value: emailNotif,
            onChanged: onEmailChanged,
          ),
          const SizedBox(height: 10),
          _ToggleCard(
            icon: LucideIcons.smartphone,
            iconColor: kAccent,
            title: 'Notifications Push / In-App',
            subtitle:
                'Alertes instantanées directement sur votre tableau de bord et mobile.',
            value: pushNotif,
            onChanged: onPushChanged,
          ),

          const SizedBox(height: 20),

          // ── TYPES D'ALERTES ────────────────────────────────────────────
          _SectionLabel(label: "TYPES D'ALERTES"),
          const SizedBox(height: 10),

          _ToggleRow(
            icon: LucideIcons.refreshCw,
            label: 'Mises à jour des projets',
            value: majProjets,
            onChanged: onMajChanged,
          ),
          _ToggleRow(
            icon: LucideIcons.messageSquare,
            label: 'Commentaires des clients (avancement)',
            value: commentaires,
            onChanged: onCommChanged,
          ),
          _ToggleRow(
            icon: LucideIcons.calendarCheck,
            label: 'Tâches qui commencent demain',
            value: tachesDemain,
            onChanged: onTachesChanged,
          ),
          _ToggleRow(
            icon: LucideIcons.umbrella,
            label: "Rappels pour les congés d'équipe",
            value: congesEquipe,
            onChanged: onCongesChanged,
          ),
          _ToggleRow(
            icon: LucideIcons.calendarClock,
            label: 'Rappels de tâches et réunions',
            value: reunions,
            onChanged: onReunionsChanged,
            isLast: true,
          ),
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: const Border(left: BorderSide(color: kAccent, width: 3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
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
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: kTextSub),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: kTextSub,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
            color: kTextMain,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kAccent, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: kTextSub,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: kTextMain,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: kTextSub, fontSize: 11),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: kAccent),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isLast;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 16, color: kTextSub),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: kTextMain, fontSize: 13),
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: kAccent,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, color: Color(0xFFF3F4F6)),
      ],
    );
  }
}
