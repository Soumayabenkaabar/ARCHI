import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../constants/colors.dart';
import '../models/client.dart';

class ClientCard extends StatelessWidget {
  final Client client;
  final VoidCallback? onView;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ClientCard({
    super.key,
    required this.client,
    this.onView,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Ligne principale : avatar + nom + badge accès ──────────
          Row(
            children: [
              // Avatar initiales
              CircleAvatar(
                radius: 20,
                backgroundColor: kAccent.withOpacity(0.15),
                child: Text(
                  client.nom.isNotEmpty ? client.nom[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: kAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.nom,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: kTextMain,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (client.entreprise.isNotEmpty)
                      Text(
                        client.entreprise,
                        style: const TextStyle(color: kTextSub, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // Badge accès portail
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: client.accesPortail
                      ? kGreen.withOpacity(0.12)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  client.accesPortail ? 'Actif' : 'Inactif',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: client.accesPortail ? kGreen : kTextSub,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFEEEFF1)),
          const SizedBox(height: 10),

          // ── Infos secondaires ──────────────────────────────────────
          if (client.email.isNotEmpty)
            _InfoChip(icon: LucideIcons.mail, text: client.email),
          if (client.telephone.isNotEmpty) ...[
            const SizedBox(height: 6),
            _InfoChip(icon: LucideIcons.phone, text: client.telephone),
          ],

          const SizedBox(height: 10),

          // ── Pied de carte : projets + actions ─────────────────────
          Row(
            children: [
              // Nombre de projets
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: kAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.briefcase, size: 11, color: kAccent),
                    const SizedBox(width: 4),
                    Text(
                      '${client.nbProjets} projet${client.nbProjets > 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: kAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // ── Boutons d'action ───────────────────────────────────
              _ActionButton(
                icon: LucideIcons.eye,
                color: kAccent,
                tooltip: 'Consulter',
                onTap: onView,
              ),
              const SizedBox(width: 6),
              _ActionButton(
                icon: LucideIcons.pencil,
                color: kWarning,
                tooltip: 'Modifier',
                onTap: onEdit,
              ),
              const SizedBox(width: 6),
              _ActionButton(
                icon: LucideIcons.trash2,
                color: kRed,
                tooltip: 'Supprimer',
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Chip info ──────────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: kTextSub),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: kTextSub, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Bouton action icône ────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}
