import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../models/tache.dart';
import '../service/tache_service.dart';

class Modele3DTab extends StatefulWidget {
  final String projectId;
  const Modele3DTab({super.key, required this.projectId});

  @override
  State<Modele3DTab> createState() => _Modele3DTabState();
}

class _Modele3DTabState extends State<Modele3DTab> {
  List<Tache> taches = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await TacheService.getTaches(widget.projectId);
      setState(() {
        taches = data;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
    }
  }

  List<_Layer3D> get _layers => taches.reversed
      .map((t) => _Layer3D(label: t.titre, statut: t.statut))
      .toList();

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Center(child: CircularProgressIndicator(color: kAccent));

    final isMobile = MediaQuery.of(context).size.width < 800;
    final pad = isMobile ? 16.0 : 28.0;
    final layers = _layers;

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          const Text(
            'Visualisation 3D',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: kTextMain,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Vue 3D du projet avec progression des tâches par couleur',
            style: TextStyle(color: kTextSub, fontSize: 12),
          ),

          const SizedBox(height: 20),

          // ── Légende ─────────────────────────────────────────────────
          Container(
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
                const Text(
                  'Légende',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: kTextMain,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 20,
                  runSpacing: 8,
                  children: [
                    _LegendItem(
                      color: const Color(0xFF374151),
                      label: 'Terminé (100%)',
                    ),
                    _LegendItem(color: kAccent, label: 'En cours'),
                    _LegendItem(
                      color: const Color(0xFFD1D5DB),
                      label: 'Pas commencé (0%)',
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Modèle 3D ───────────────────────────────────────────────
          if (layers.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'Aucune tâche disponible',
                  style: TextStyle(color: kTextSub),
                ),
              ),
            )
          else
            Center(
              child: SizedBox(
                height: layers.length * 58.0 + 30,
                width: isMobile ? double.infinity : 500,
                child: CustomPaint(
                  painter: _Building3DPainter(layers: layers),
                  size: Size.infinite,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Layer3D {
  final String label;
  final String statut; // 'en_attente' | 'en_cours' | 'termine'
  const _Layer3D({required this.label, required this.statut});

  Color get color {
    switch (statut) {
      case 'termine':
        return const Color(0xFF374151);
      case 'en_cours':
        return kAccent;
      default:
        return const Color(0xFFD1D5DB);
    }
  }

  Color get sideColor {
    switch (statut) {
      case 'termine':
        return const Color(0xFF1F2937);
      case 'en_cours':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  Color get topColor {
    switch (statut) {
      case 'termine':
        return const Color(0xFF4B5563);
      case 'en_cours':
        return const Color(0xFFFBBF24);
      default:
        return const Color(0xFFE5E7EB);
    }
  }

  bool get isPlanifie => statut == 'en_attente';
}

class _Building3DPainter extends CustomPainter {
  final List<_Layer3D> layers;
  const _Building3DPainter({required this.layers});

  @override
  void paint(Canvas canvas, Size size) {
    const layerH = 40.0;
    const depthX = 24.0;
    const depthY = 12.0;
    const gap = 3.0;

    final totalLayers = layers.length;
    final blockW = size.width * 0.55;
    final startX = (size.width - blockW - depthX) / 2;

    // Sol
    final groundPaint = Paint()..color = const Color(0xFFE5E7EB);
    final groundPath = Path()
      ..moveTo(startX, size.height - 14)
      ..lineTo(startX + blockW, size.height - 14)
      ..lineTo(startX + blockW + depthX, size.height - 14 - depthY)
      ..lineTo(startX + depthX, size.height - 14 - depthY)
      ..close();
    canvas.drawPath(groundPath, groundPaint);

    for (int i = 0; i < totalLayers; i++) {
      final layer = layers[totalLayers - 1 - i]; // du bas vers le haut
      final y = size.height - 14 - (i + 1) * (layerH + gap);

      // Face avant
      final frontPaint = Paint()..color = layer.color;
      canvas.drawRect(Rect.fromLTWH(startX, y, blockW, layerH), frontPaint);

      // Face droite (côté)
      final sidePaint = Paint()..color = layer.sideColor;
      final sidePath = Path()
        ..moveTo(startX + blockW, y)
        ..lineTo(startX + blockW + depthX, y - depthY)
        ..lineTo(startX + blockW + depthX, y - depthY + layerH)
        ..lineTo(startX + blockW, y + layerH)
        ..close();
      canvas.drawPath(sidePath, sidePaint);

      // Face du dessus
      final topPaint = Paint()..color = layer.topColor;
      final topPath = Path()
        ..moveTo(startX, y)
        ..lineTo(startX + blockW, y)
        ..lineTo(startX + blockW + depthX, y - depthY)
        ..lineTo(startX + depthX, y - depthY)
        ..close();
      canvas.drawPath(topPath, topPaint);

      // Texte centré sur la face avant
      final shortLabel = layer.label.length > 16
          ? '${layer.label.substring(0, 14)}...'
          : layer.label;
      final tp = TextPainter(
        text: TextSpan(
          text: shortLabel,
          style: TextStyle(
            color: layer.isPlanifie ? const Color(0xFF374151) : Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: blockW - 16);

      tp.paint(
        canvas,
        Offset(startX + (blockW - tp.width) / 2, y + (layerH - tp.height) / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: kTextSub, fontSize: 12)),
      ],
    );
  }
}
