import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:geolocator/geolocator.dart';
import '../constants/colors.dart';
import '../models/project.dart';

// ─── Données geo des projets ──────────────────────────────────────────────────
class _ChantierGeo {
  final Project project;
  final LatLng position;
  final String adresse;

  const _ChantierGeo({
    required this.project,
    required this.position,
    required this.adresse,
  });
}

final _chantiers = [
  _ChantierGeo(
    project: sampleProjects[0],
    position: const LatLng(33.740368, 10.918548),
    adresse: 'Cedouikech ,Djerba',
  ),
  _ChantierGeo(
    project: sampleProjects[1],
    position: const LatLng(33.8075, 10.8906),
    adresse: 'El Mey , djerba',
  ),
  _ChantierGeo(
    project: sampleProjects[2],
    position: const LatLng(33.7647, 10.7513),
    adresse: 'Guelala, Djerba',
  ),
];

// ─── Carte Screen ─────────────────────────────────────────────────────────────
class CarteScreen extends StatefulWidget {
  const CarteScreen({super.key});

  @override
  State<CarteScreen> createState() => _CarteScreenState();
}

class _CarteScreenState extends State<CarteScreen> {
  final MapController _mapController = MapController();
  int? _selectedIndex;
  LatLng? _myPosition;
  bool _loadingPosition = false;

  Color _statusColor(String status) {
    switch (status) {
      case 'En cours':
        return kAccent;
      case 'Terminé':
        return const Color(0xFF374151);
      case 'Planification':
        return const Color(0xFFD1D5DB);
      default:
        return kAccent;
    }
  }

  Future<void> _goToMyPosition() async {
    setState(() => _loadingPosition = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Service désactivé');

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever)
        throw Exception('Permission refusée');

      final pos = await Geolocator.getCurrentPosition();
      final ll = LatLng(pos.latitude, pos.longitude);
      setState(() => _myPosition = ll);
      _mapController.move(ll, 13);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Position indisponible: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingPosition = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final pad = isMobile ? 16.0 : 28.0;

    return Container(
      color: kBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Carte des chantiers',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: kTextMain,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Visualisez la localisation de tous vos projets',
                        style: TextStyle(color: kTextSub, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                // Bouton Ma position — mobile seulement
                if (isMobile)
                  OutlinedButton.icon(
                    onPressed: _loadingPosition ? null : _goToMyPosition,
                    icon: _loadingPosition
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: kTextSub,
                            ),
                          )
                        : const Icon(
                            LucideIcons.navigation,
                            size: 14,
                            color: kTextSub,
                          ),
                    label: const Text(
                      'Ma position',
                      style: TextStyle(color: kTextSub, fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Légende ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: kCardBg,
                borderRadius: BorderRadius.circular(12),
                border: const Border(
                  left: BorderSide(color: kAccent, width: 3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(LucideIcons.mapPin, color: kAccent, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Légende & Informations',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: kTextMain,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 20,
                    runSpacing: 8,
                    children: [
                      _LegendeDot(color: kAccent, label: 'En cours'),
                      _LegendeDot(
                        color: const Color(0xFF374151),
                        label: 'Terminé',
                      ),
                      _LegendeDot(
                        color: const Color(0xFFD1D5DB),
                        label: 'Planification',
                      ),
                      _LegendeDot(color: Colors.blue, label: 'Votre position'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Carte interactive ─────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: kCardBg,
                borderRadius: BorderRadius.circular(12),
                border: const Border(
                  left: BorderSide(color: kAccent, width: 3),
                ),
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
                  // Titre carte
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.mapPin,
                          color: kAccent,
                          size: 15,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Carte interactive - ${_chantiers.length} chantiers',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: kTextMain,
                          ),
                        ),
                        const Spacer(),
                        // Ma position — desktop seulement
                        if (!isMobile)
                          OutlinedButton.icon(
                            onPressed: _loadingPosition
                                ? null
                                : _goToMyPosition,
                            icon: _loadingPosition
                                ? const SizedBox(
                                    width: 13,
                                    height: 13,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: kTextSub,
                                    ),
                                  )
                                : const Icon(
                                    LucideIcons.navigation,
                                    size: 13,
                                    color: kTextSub,
                                  ),
                            label: const Text(
                              'Ma position',
                              style: TextStyle(color: kTextSub, fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              side: const BorderSide(color: Color(0xFFD1D5DB)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Carte
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    child: SizedBox(
                      height: isMobile ? 280 : 420,
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: const LatLng(34.0, -6.0),
                          initialZoom: 6.0,
                          onTap: (_, __) =>
                              setState(() => _selectedIndex = null),
                        ),
                        children: [
                          // Tuiles OSM
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.archi.manager',
                          ),

                          // Marqueurs chantiers
                          MarkerLayer(
                            markers: [
                              // Ma position
                              if (_myPosition != null)
                                Marker(
                                  point: _myPosition!,
                                  width: 20,
                                  height: 20,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.blue,
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                              // Chantiers
                              ..._chantiers.asMap().entries.map((e) {
                                final i = e.key;
                                final c = e.value;
                                final color = _statusColor(c.project.statut);
                                final isSelected = _selectedIndex == i;

                                return Marker(
                                  point: c.position,
                                  width: isSelected ? 160 : 36,
                                  height: isSelected ? 72 : 36,
                                  alignment: Alignment.topCenter,
                                  child: GestureDetector(
                                    onTap: () => setState(
                                      () => _selectedIndex = _selectedIndex == i
                                          ? null
                                          : i,
                                    ),
                                    child: isSelected
                                        ? _MarkerPopup(
                                            chantier: c,
                                            color: color,
                                            onClose: () => setState(
                                              () => _selectedIndex = null,
                                            ),
                                          )
                                        : _MarkerPin(color: color),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Liste des projets ─────────────────────────────────────────
            Text(
              'Liste des projets (${_chantiers.length})',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: kTextMain,
              ),
            ),
            const SizedBox(height: 14),

            LayoutBuilder(
              builder: (context, constraints) {
                final cols = constraints.maxWidth > 700 ? 3 : 1;
                if (cols == 1) {
                  return Column(
                    children: _chantiers
                        .map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ProjetCarteCard(
                              chantier: c,
                              onTap: () {
                                _mapController.move(c.position, 14);
                                setState(
                                  () => _selectedIndex = _chantiers.indexOf(c),
                                );
                              },
                            ),
                          ),
                        )
                        .toList(),
                  );
                }
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _chantiers.asMap().entries.map((e) {
                      final i = e.key;
                      final c = e.value;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(left: i == 0 ? 0 : 16),
                          child: _ProjetCarteCard(
                            chantier: c,
                            onTap: () {
                              _mapController.move(c.position, 14);
                              setState(() => _selectedIndex = i);
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Marqueur pin ─────────────────────────────────────────────────────────────
class _MarkerPin extends StatelessWidget {
  final Color color;
  const _MarkerPin({required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.location_on_rounded,
            color: Colors.white,
            size: 16,
          ),
        ),
        Container(width: 2, height: 6, color: color),
      ],
    );
  }
}

// ─── Popup marqueur ───────────────────────────────────────────────────────────
class _MarkerPopup extends StatelessWidget {
  final _ChantierGeo chantier;
  final Color color;
  final VoidCallback onClose;

  const _MarkerPopup({
    required this.chantier,
    required this.color,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  chantier.project.titre,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: kTextMain,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: onClose,
                child: const Icon(
                  Icons.close_rounded,
                  size: 12,
                  color: kTextSub,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            chantier.adresse,
            style: const TextStyle(fontSize: 9, color: kTextSub),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              chantier.project.statut,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card projet liste ────────────────────────────────────────────────────────
class _ProjetCarteCard extends StatelessWidget {
  final _ChantierGeo chantier;
  final VoidCallback onTap;

  const _ProjetCarteCard({required this.chantier, required this.onTap});

  Color get _statusColor {
    switch (chantier.project.statut) {
      case 'En cours':
        return kAccent;
      case 'Planification':
        return const Color(0xFFADB5BD);
      default:
        return const Color(0xFF374151);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = chantier.project;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
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
          // Titre + badge
          Row(
            children: [
              Expanded(
                child: Text(
                  p.titre,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: kTextMain,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  p.statut,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Adresse
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 14, color: kTextSub),
              const SizedBox(width: 6),
              Text(
                chantier.adresse,
                style: const TextStyle(color: kTextSub, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Coordonnées
          Row(
            children: [
              const Icon(Icons.navigation_rounded, size: 14, color: kTextSub),
              const SizedBox(width: 6),
              Text(
                '${chantier.position.latitude}, ${chantier.position.longitude}',
                style: const TextStyle(color: kTextSub, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Bouton Voir le projet
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(
                LucideIcons.externalLink,
                size: 14,
                color: Colors.white,
              ),
              label: const Text(
                'Voir le projet',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
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

// ─── Légende dot ──────────────────────────────────────────────────────────────
class _LegendeDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendeDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: kTextSub, fontSize: 12)),
      ],
    );
  }
}
