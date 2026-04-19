import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../constants/colors.dart';
import '../models/membre.dart';

// ─── Card membre DISPONIBLE ───────────────────────────────────────────────────
class MembreDisponibleCard extends StatelessWidget {
  final Membre membre;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onView;
  final VoidCallback? onAssign;

  const MembreDisponibleCard({
    required this.membre,
    this.onEdit,
    this.onDelete,
    this.onView,
    this.onAssign,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            membre.nom,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: kTextMain,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            membre.role,
                            style: const TextStyle(
                              color: kTextSub,
                              fontSize: 13,
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
                        color: kAccent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Disponible',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Spécialité
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13),
                    children: [
                      const TextSpan(
                        text: 'Spécialité: ',
                        style: TextStyle(color: kTextSub),
                      ),
                      TextSpan(
                        text: membre.specialite,
                        style: const TextStyle(
                          color: kTextMain,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _InfoRow(icon: LucideIcons.mail, text: membre.email),
                const SizedBox(height: 6),
                _InfoRow(icon: LucideIcons.phone, text: membre.telephone),
              ],
            ),
          ),

          // ── Divider ─────────────────────────────────────────────────────
          const Divider(height: 1, color: Color(0xFFF0F0F0)),

          // ── Actions ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              children: [
                // Bouton Assigner
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onAssign,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Assigner à un projet',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Modifier / Supprimer
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(
                        LucideIcons.pencil,
                        size: 18,
                        color: kTextSub,
                      ),
                      onPressed: onEdit,
                      tooltip: 'Modifier',
                    ),
                    IconButton(
                      icon: const Icon(
                        LucideIcons.trash2,
                        size: 18,
                        color: kRed,
                      ),
                      onPressed: onDelete,
                      tooltip: 'Supprimer',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Row membre EN ACTIVITÉ ───────────────────────────────────────────────────
class MembreActifRow extends StatelessWidget {
  final Membre membre;

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onView;

  const MembreActifRow({
    required this.membre,
    this.onEdit,
    this.onDelete,
    this.onView,
  });
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isMobile
          ? _MobileActifLayout(
              membre: membre,
              onEdit: onEdit,
              onDelete: onDelete,
              onView: onView,
            )
          : _DesktopActifLayout(
              membre: membre,
              onEdit: onEdit,
              onDelete: onDelete,
              onView: onView,
            ),
    );
  }
}

class _DesktopActifLayout extends StatelessWidget {
  final Membre membre;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onView;

  const _DesktopActifLayout({
    required this.membre,
    this.onEdit,
    this.onDelete,
    this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Nom + role + spécialité + tel
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                membre.nom,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: kTextMain,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                membre.role,
                style: const TextStyle(color: kTextSub, fontSize: 13),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 12),
                  children: [
                    const TextSpan(
                      text: 'Spécialité: ',
                      style: TextStyle(color: kTextSub),
                    ),
                    TextSpan(
                      text: membre.specialite,
                      style: const TextStyle(color: kTextMain),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              _InfoRow(icon: LucideIcons.phone, text: membre.telephone),
            ],
          ),
        ),
        // Email
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _InfoRow(icon: LucideIcons.mail, text: membre.email),
          ),
        ),
        // Projets + actions
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Projets assignés (${membre.projetsAssignes.length})',
                style: const TextStyle(color: kTextSub, fontSize: 12),
              ),
              const SizedBox(height: 4),
              ...membre.projetsAssignes.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: kAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      p,
                      style: const TextStyle(
                        color: kTextMain,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      LucideIcons.eye,
                      size: 18,
                      color: kTextSub,
                    ),
                    onPressed: onView,
                    tooltip: 'Consulter',
                  ),
                  IconButton(
                    icon: const Icon(
                      LucideIcons.pencil,
                      size: 18,
                      color: kTextSub,
                    ),
                    onPressed: onEdit,
                    tooltip: 'Modifier',
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.trash2, size: 18, color: kRed),
                    onPressed: onDelete,
                    tooltip: 'Supprimer',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MobileActifLayout extends StatelessWidget {
  final Membre membre;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onView;

  const _MobileActifLayout({
    required this.membre,
    this.onEdit,
    this.onDelete,
    this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          membre.nom,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: kTextMain,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          membre.role,
          style: const TextStyle(color: kTextSub, fontSize: 13),
        ),
        const SizedBox(height: 8),
        _InfoRow(icon: LucideIcons.mail, text: membre.email),
        const SizedBox(height: 4),
        _InfoRow(icon: LucideIcons.phone, text: membre.telephone),
        const SizedBox(height: 10),
        Text(
          'Projets assignés (${membre.projetsAssignes.length})',
          style: const TextStyle(color: kTextSub, fontSize: 12),
        ),
        const SizedBox(height: 4),
        ...membre.projetsAssignes.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: kAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                p,
                style: const TextStyle(
                  color: kTextMain,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(
                  LucideIcons.pencil,
                  size: 13,
                  color: kTextMain,
                ),
                label: const Text(
                  'Modifier',
                  style: TextStyle(color: kTextMain, fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  side: const BorderSide(color: Color(0xFFE0E0E0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(LucideIcons.trash2, size: 13, color: kRed),
                label: const Text(
                  'Supprimer',
                  style: TextStyle(color: kRed, fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  side: const BorderSide(color: Color(0xFFE0E0E0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Helper ────────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: kTextSub),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: kTextSub, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
