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
  final VoidCallback? onConge;
  final bool isEnConge;

  const MembreDisponibleCard({
    required this.membre,
    this.onEdit,
    this.onDelete,
    this.onView,
    this.onConge,
    this.isEnConge = false,
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
                            style: const TextStyle(color: kTextSub, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    if (isEnConge)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF97316),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('En congé',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: kAccent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Disponible',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                _InfoRow(icon: LucideIcons.mail, text: membre.email),
                const SizedBox(height: 6),
                _InfoRow(icon: LucideIcons.phone, text: membre.telephone),
              ],
            ),
          ),

          // ── Divider ─────────────────────────────────────────────────────
          const Divider(height: 1, color: Color(0xFFF0F0F0)),

          // ── Actions (congés · modifier · supprimer) ──────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(LucideIcons.umbrella, size: 18,
                      color: isEnConge ? const Color(0xFFF97316) : kTextSub),
                  onPressed: onConge,
                  tooltip: 'Gérer les congés',
                ),
                IconButton(
                  icon: const Icon(LucideIcons.pencil, size: 18, color: kTextSub),
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
  final VoidCallback? onConge;
  final bool isEnConge;

  const MembreActifRow({
    required this.membre,
    this.onEdit,
    this.onDelete,
    this.onView,
    this.onConge,
    this.isEnConge = false,
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
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: isMobile
          ? _MobileActifLayout(membre: membre, onEdit: onEdit, onDelete: onDelete, onView: onView, onConge: onConge, isEnConge: isEnConge)
          : _DesktopActifLayout(membre: membre, onEdit: onEdit, onDelete: onDelete, onView: onView, onConge: onConge, isEnConge: isEnConge),
    );
  }
}

class _DesktopActifLayout extends StatelessWidget {
  final Membre membre;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onView;
  final VoidCallback? onConge;
  final bool isEnConge;

  const _DesktopActifLayout({
    required this.membre, this.onEdit, this.onDelete, this.onView, this.onConge, this.isEnConge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Nom + rôle + spécialité + tél
        Expanded(
          flex: 3,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(membre.nom, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: kTextMain)),
            const SizedBox(height: 3),
            Text(membre.role, style: const TextStyle(color: kTextSub, fontSize: 13)),
            const SizedBox(height: 8),
            _InfoRow(icon: LucideIcons.phone, text: membre.telephone),
          ]),
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (isEnConge)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF97316).withOpacity(0.4)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.umbrella, size: 11, color: Color(0xFFF97316)),
                  SizedBox(width: 4),
                  Text('En congé', style: TextStyle(color: Color(0xFFF97316), fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
              ),
            _ProjetsSection(projets: membre.projetsAssignes),
            const SizedBox(height: 10),
            Row(children: [
              IconButton(icon: Icon(LucideIcons.umbrella, size: 18, color: isEnConge ? const Color(0xFFF97316) : kTextSub), onPressed: onConge, tooltip: 'Gérer les congés'),
              IconButton(icon: const Icon(LucideIcons.eye, size: 18, color: kTextSub), onPressed: onView, tooltip: 'Consulter'),
              IconButton(icon: const Icon(LucideIcons.pencil, size: 18, color: kTextSub), onPressed: onEdit, tooltip: 'Modifier'),
              IconButton(icon: const Icon(LucideIcons.trash2, size: 18, color: kRed), onPressed: onDelete, tooltip: 'Supprimer'),
            ]),
          ]),
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
  final VoidCallback? onConge;
  final bool isEnConge;

  const _MobileActifLayout({
    required this.membre, this.onEdit, this.onDelete, this.onView, this.onConge, this.isEnConge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(membre.nom, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: kTextMain)),
      const SizedBox(height: 3),
      Text(membre.role, style: const TextStyle(color: kTextSub, fontSize: 13)),
      const SizedBox(height: 8),
      _InfoRow(icon: LucideIcons.mail, text: membre.email),
      const SizedBox(height: 4),
      _InfoRow(icon: LucideIcons.phone, text: membre.telephone),
      const SizedBox(height: 10),
      _ProjetsSection(projets: membre.projetsAssignes),
      if (isEnConge)
        Container(
          margin: const EdgeInsets.only(top: 4, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF97316).withOpacity(0.4)),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(LucideIcons.umbrella, size: 12, color: Color(0xFFF97316)),
            SizedBox(width: 4),
            Text('En congé', style: TextStyle(color: Color(0xFFF97316), fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ),
      const SizedBox(height: 12),

      // ── Consulter (pleine largeur, action principale) ─────────────────
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onView,
          icon: const Icon(LucideIcons.eye, size: 14, color: Colors.white),
          label: const Text('Consulter le profil',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: kAccent,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 11),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          ),
        ),
      ),

      const SizedBox(height: 8),

      // ── Actions secondaires ────────────────────────────────────────────
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onConge,
            icon: Icon(LucideIcons.umbrella, size: 13,
                color: isEnConge ? const Color(0xFFF97316) : kTextSub),
            label: Text('Congés',
                style: TextStyle(
                    color: isEnConge ? const Color(0xFFF97316) : kTextSub, fontSize: 12)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8),
              side: BorderSide(
                  color: isEnConge
                      ? const Color(0xFFF97316).withOpacity(0.5)
                      : const Color(0xFFE0E0E0)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(LucideIcons.pencil, size: 13, color: kTextMain),
            label: const Text('Modifier',
                style: TextStyle(color: kTextMain, fontSize: 12)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8),
              side: const BorderSide(color: Color(0xFFE0E0E0)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onDelete,
            icon: const Icon(LucideIcons.trash2, size: 13, color: kRed),
            label: const Text('Supprimer',
                style: TextStyle(color: kRed, fontSize: 12)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8),
              side: const BorderSide(color: Color(0xFFE0E0E0)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ]),
    ]);
  }
}

// ── Widget projets assignés (source : tâches) ────────────────────────────────
class _ProjetsSection extends StatelessWidget {
  final List<String> projets;
  const _ProjetsSection({required this.projets});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En-tête
        Row(children: [
          const Icon(LucideIcons.folderOpen, size: 13, color: kAccent),
          const SizedBox(width: 6),
          Text(
            projets.isEmpty
                ? 'Aucun projet assigné'
                : 'Projet${projets.length > 1 ? "s" : ""} assigné${projets.length > 1 ? "s" : ""} via tâches',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: projets.isEmpty ? kTextSub : kTextMain,
            ),
          ),
          if (projets.isNotEmpty) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: kAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${projets.length}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kAccent),
              ),
            ),
          ],
        ]),
        if (projets.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: projets.map((p) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: kAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kAccent.withOpacity(0.25)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(color: kAccent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(p,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kAccent,
                  ),
                ),
              ]),
            )).toList(),
          ),
        ],
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
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 13, color: kTextSub),
    const SizedBox(width: 6),
    Expanded(child: Text(text, style: const TextStyle(color: kTextSub, fontSize: 13), overflow: TextOverflow.ellipsis)),
  ]);
}