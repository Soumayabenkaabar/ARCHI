import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../constants/colors.dart';

class DocumentsTab extends StatelessWidget {
  const DocumentsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final pad = isMobile ? 16.0 : 28.0;

    final docs = [
      _DocData('Plan architectural V2', 'Plan', 'v2', '10/01/2026', kAccent),
      _DocData(
        'Devis initial',
        'Devis',
        'v1',
        '15/12/2025',
        const Color(0xFF374151),
      ),
      _DocData(
        'Permis de construire',
        'Permis',
        'v1',
        '05/01/2026',
        const Color(0xFF3B82F6),
      ),
      _DocData(
        'Rapport structure',
        'Rapport',
        'v1',
        '20/01/2026',
        const Color(0xFF10B981),
      ),
    ];

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
                      'Documents du projet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: kTextMain,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Plans, devis, factures et autres documents',
                      style: TextStyle(color: kTextSub, fontSize: 12),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(
                  LucideIcons.upload,
                  size: 14,
                  color: Colors.white,
                ),
                label: Text(
                  isMobile ? 'Uploader' : 'Uploader un document',
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
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Grille documents ─────────────────────────────────────────
          LayoutBuilder(
            builder: (ctx, constraints) {
              final cols = constraints.maxWidth > 600 ? 2 : 1;
              final rows = <Widget>[];
              for (int i = 0; i < docs.length; i += cols) {
                final rowItems = docs.skip(i).take(cols).toList();
                rows.add(
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (int j = 0; j < rowItems.length; j++) ...[
                          if (j > 0) const SizedBox(width: 16),
                          Expanded(child: _DocCard(doc: rowItems[j])),
                        ],
                        if (rowItems.length < cols) ...[
                          const SizedBox(width: 16),
                          const Expanded(child: SizedBox()),
                        ],
                      ],
                    ),
                  ),
                );
                if (i + cols < docs.length) {
                  rows.add(const SizedBox(height: 16));
                }
              }
              return Column(children: rows);
            },
          ),
        ],
      ),
    );
  }
}

class _DocData {
  final String titre;
  final String type;
  final String version;
  final String date;
  final Color typeColor;
  const _DocData(
    this.titre,
    this.type,
    this.version,
    this.date,
    this.typeColor,
  );
}

class _DocCard extends StatelessWidget {
  final _DocData doc;
  const _DocCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          // Icône + Titre + badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.titre,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: kTextMain,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: doc.typeColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        doc.type,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 12),

          // Version + Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Version',
                style: TextStyle(color: kTextSub, fontSize: 12),
              ),
              Text(
                doc.version,
                style: const TextStyle(
                  color: kTextMain,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Date',
                style: TextStyle(color: kTextSub, fontSize: 12),
              ),
              Text(
                doc.date,
                style: const TextStyle(
                  color: kTextMain,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Bouton Ouvrir
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(
                LucideIcons.externalLink,
                size: 13,
                color: kTextSub,
              ),
              label: const Text(
                'Ouvrir',
                style: TextStyle(color: kTextSub, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
