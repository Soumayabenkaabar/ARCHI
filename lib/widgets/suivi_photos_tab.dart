import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../constants/colors.dart';

class SuiviPhotosTab extends StatelessWidget {
  const SuiviPhotosTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final pad = isMobile ? 16.0 : 28.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chantier',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: kTextMain,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Photos, rapports et observations du chantier',
                      style: TextStyle(color: kTextSub, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Boutons
              if (!isMobile) ...[
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(
                    LucideIcons.fileText,
                    size: 14,
                    color: kTextSub,
                  ),
                  label: const Text(
                    'Nouveau rapport',
                    style: TextStyle(color: kTextSub, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(
                  LucideIcons.camera,
                  size: 14,
                  color: Colors.white,
                ),
                label: Text(
                  isMobile ? 'Photos' : 'Ajouter des photos',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccent,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),

          if (isMobile) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(
                  LucideIcons.fileText,
                  size: 14,
                  color: kTextSub,
                ),
                label: const Text(
                  'Nouveau rapport',
                  style: TextStyle(color: kTextSub, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ── Photos du chantier ───────────────────────────────────────
          _SectionCard(
            title: 'Photos du chantier',
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final cols = constraints.maxWidth > 500 ? 3 : 2;
                return GridView.count(
                  crossAxisCount: cols,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 0.85,
                  children: const [
                    _PhotoCard(
                      emoji: '🏗️',
                      title: 'Fondations terminées',
                      date: '28/02/2026',
                      tag: 'Fondations',
                      tagColor: Color(0xFF374151),
                    ),
                    _PhotoCard(
                      emoji: '🧱',
                      title: 'Élévation murs niveau 1',
                      date: '20/03/2026',
                      tag: 'Élévation des murs',
                      tagColor: Color(0xFFF5A623),
                    ),
                    _PhotoCard(
                      emoji: '📐',
                      title: 'Tracé des cloisons',
                      date: '05/04/2026',
                      tag: 'Gros œuvre',
                      tagColor: Color(0xFF3B82F6),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // ── Rapports de chantier ─────────────────────────────────────
          _SectionCard(
            title: 'Rapports de chantier',
            child: Column(
              children: const [
                _RapportRow(
                  titre: 'Rapport hebdomadaire - Semaine 12',
                  date: '26 mars 2026',
                  auteur: 'Ahmed Bennani',
                  statut: 'Conforme',
                  statutColor: Color(0xFF374151),
                ),
                _RapportRow(
                  titre: 'Rapport hebdomadaire - Semaine 11',
                  date: '19 mars 2026',
                  auteur: 'Ahmed Bennani',
                  statut: 'Conforme',
                  statutColor: Color(0xFF374151),
                ),
                _RapportRow(
                  titre: 'Rapport hebdomadaire - Semaine 10',
                  date: '12 mars 2026',
                  auteur: 'Sanaa Idrissi',
                  statut: 'À réviser',
                  statutColor: Color(0xFFF5A623),
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Photo Card ────────────────────────────────────────────────────────────────
class _PhotoCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String date;
  final String tag;
  final Color tagColor;

  const _PhotoCard({
    required this.emoji,
    required this.title,
    required this.date,
    required this.tag,
    required this.tagColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo simulée avec emoji
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                ),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 48)),
              ),
            ),
          ),
          // Info
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: kTextMain,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 10,
                      color: kTextSub,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      date,
                      style: const TextStyle(color: kTextSub, fontSize: 10),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: tagColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: tagColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
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

// ── Rapport Row ───────────────────────────────────────────────────────────────
class _RapportRow extends StatelessWidget {
  final String titre;
  final String date;
  final String auteur;
  final String statut;
  final Color statutColor;
  final bool isLast;

  const _RapportRow({
    required this.titre,
    required this.date,
    required this.auteur,
    required this.statut,
    required this.statutColor,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        children: [
          // Icône document
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              LucideIcons.fileText,
              color: Color(0xFF3B82F6),
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: kTextMain,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      date,
                      style: const TextStyle(color: kTextSub, fontSize: 11),
                    ),
                    const Text(
                      ' • ',
                      style: TextStyle(color: kTextSub, fontSize: 11),
                    ),
                    Text(
                      'Par $auteur',
                      style: const TextStyle(color: kTextSub, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Badge statut
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statutColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statut,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
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
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: kTextMain,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
