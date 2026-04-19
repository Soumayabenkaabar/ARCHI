import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../constants/colors.dart';

class EquipeTab extends StatelessWidget {
  const EquipeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final pad = isMobile ? 16.0 : 28.0;

    final membres = [
      _MembreData(
        'Ahmed Bennani',
        'Chef de projet',
        'ahmed.bennani@archi.ma',
        '0661234567',
        const Color(0xFF374151),
      ),
      _MembreData(
        'Fatima Zahra',
        'Architecte',
        'fatima.z@archi.ma',
        '0662345678',
        kAccent,
      ),
      _MembreData(
        'Youssef El Amrani',
        'Ingénieur structure',
        'youssef.ea@archi.ma',
        '0663456789',
        const Color(0xFF374151),
      ),
      _MembreData(
        'Nadia Berrada',
        "Architecte d'intérieur",
        'nadia.b@archi.ma',
        '0669012345',
        const Color(0xFF374151),
      ),
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Équipe du projet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: kTextMain,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Liste des intervenants et membres de l'équipe",
                      style: TextStyle(color: kTextSub, fontSize: 12),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(
                  LucideIcons.userPlus,
                  size: 14,
                  color: Colors.white,
                ),
                label: const Text(
                  'Ajouter un membre',
                  style: TextStyle(
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

          // ── Grille membres ────────────────────────────────────────────
          LayoutBuilder(
            builder: (ctx, constraints) {
              final cols = constraints.maxWidth > 700
                  ? 3
                  : constraints.maxWidth > 450
                  ? 2
                  : 1;
              final rows = <Widget>[];
              for (int i = 0; i < membres.length; i += cols) {
                final rowItems = membres.skip(i).take(cols).toList();
                rows.add(
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (int j = 0; j < rowItems.length; j++) ...[
                          if (j > 0) const SizedBox(width: 16),
                          Expanded(child: _MembreCard(membre: rowItems[j])),
                        ],
                        for (int k = rowItems.length; k < cols; k++) ...[
                          const SizedBox(width: 16),
                          const Expanded(child: SizedBox()),
                        ],
                      ],
                    ),
                  ),
                );
                if (i + cols < membres.length) {
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

class _MembreData {
  final String nom;
  final String role;
  final String email;
  final String tel;
  final Color roleColor;
  const _MembreData(this.nom, this.role, this.email, this.tel, this.roleColor);
}

class _MembreCard extends StatelessWidget {
  final _MembreData membre;
  const _MembreCard({required this.membre});

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
          // Avatar + Nom + badge
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  LucideIcons.user,
                  color: Color(0xFF3B82F6),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      membre.nom,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: kTextMain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: membre.roleColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        membre.role,
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
          // Email
          Row(
            children: [
              const Icon(LucideIcons.mail, size: 13, color: kTextSub),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  membre.email,
                  style: const TextStyle(color: kTextSub, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Téléphone
          Row(
            children: [
              const Icon(LucideIcons.phone, size: 13, color: kTextSub),
              const SizedBox(width: 8),
              Text(
                membre.tel,
                style: const TextStyle(color: kTextSub, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
