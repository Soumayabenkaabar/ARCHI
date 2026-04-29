import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../constants/colors.dart';
import '../models/client.dart';

class ClientCard extends StatelessWidget {
  final Client client;
  final ClientStats? stats;
  final VoidCallback? onView;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ClientCard({
    super.key,
    required this.client,
    this.stats,
    this.onView,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final totalProjets = s?.total ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Ligne principale : avatar + nom + badge portail ────────
          Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: kAccent.withOpacity(0.15),
              child: Text(
                client.nom.isNotEmpty ? client.nom[0].toUpperCase() : '?',
                style: const TextStyle(color: kAccent, fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                client.nom,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kTextMain),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ])),
            // Badge portail
            _PortailBadge(actif: client.accesPortail),
          ]),

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFEEEFF1)),
          const SizedBox(height: 10),

          // ── Contact ───────────────────────────────────────────────
          if (client.email.isNotEmpty)
            _InfoChip(icon: LucideIcons.mail, text: client.email),
          if (client.telephone.isNotEmpty) ...[
            const SizedBox(height: 5),
            _InfoChip(icon: LucideIcons.phone, text: client.telephone),
          ],

          const SizedBox(height: 10),

          // ── Projets : total + détail par statut ───────────────────
          Row(children: [
            const Icon(LucideIcons.briefcase, size: 12, color: kTextSub),
            const SizedBox(width: 5),
            Text(
              '$totalProjets projet${totalProjets != 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextSub),
            ),
          ]),

          if (s != null && s.total > 0) ...[
            const SizedBox(height: 7),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (s.enCours   > 0) _StatutChip(label: 'En cours',      count: s.enCours,   color: kAccent),
              if (s.enAttente > 0) _StatutChip(label: 'Planification', count: s.enAttente, color: const Color(0xFFF59E0B)),
              if (s.termine   > 0) _StatutChip(label: 'Terminé',       count: s.termine,   color: const Color(0xFF10B981)),
              if (s.annule    > 0) _StatutChip(label: 'Annulé',        count: s.annule,    color: kRed),
            ]),
          ],

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFEEEFF1)),
          const SizedBox(height: 10),

          // ── Actions ───────────────────────────────────────────────
          Row(children: [
            const Spacer(),
            _ActionButton(icon: LucideIcons.eye,    color: kAccent,   tooltip: 'Consulter', onTap: onView),
            const SizedBox(width: 6),
            _ActionButton(icon: LucideIcons.pencil, color: kWarning,  tooltip: 'Modifier',  onTap: onEdit),
            const SizedBox(width: 6),
            _ActionButton(icon: LucideIcons.trash2, color: kRed,      tooltip: 'Supprimer', onTap: onDelete),
          ]),
        ],
      ),
    );
  }
}

// ── Badge portail ─────────────────────────────────────────────────────────────
class _PortailBadge extends StatelessWidget {
  final bool actif;
  const _PortailBadge({required this.actif});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: actif ? const Color(0xFFECFDF5) : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: actif ? const Color(0xFF6EE7B7) : const Color(0xFFE5E7EB)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(actif ? LucideIcons.shieldCheck : LucideIcons.shieldOff,
          size: 11, color: actif ? const Color(0xFF10B981) : kTextSub),
      const SizedBox(width: 4),
      Text(
        actif ? 'Portail actif' : 'Sans portail',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: actif ? const Color(0xFF065F46) : kTextSub,
        ),
      ),
    ]),
  );
}

// ── Chip statut projet ────────────────────────────────────────────────────────
class _StatutChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatutChip({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(
        '$count $label',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    ]),
  );
}

// ── Chip info contact ─────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 12, color: kTextSub),
    const SizedBox(width: 6),
    Expanded(child: Text(text,
        style: const TextStyle(color: kTextSub, fontSize: 12),
        maxLines: 1, overflow: TextOverflow.ellipsis)),
  ]);
}

// ── Bouton action ─────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;
  const _ActionButton({required this.icon, required this.color, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 14, color: color),
      ),
    ),
  );
}
