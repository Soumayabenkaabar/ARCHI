import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:geolocator/geolocator.dart';
import '../constants/colors.dart';
import '../models/project.dart';
import '../service/projet_service.dart';

// ─── Géocodage Nominatim (cache en mémoire) ───────────────────────────────────
final _geocodeCache = <String, LatLng?>{};

Future<LatLng?> _geocode(String address) async {
  final key = address.trim().toLowerCase();
  if (_geocodeCache.containsKey(key)) return _geocodeCache[key];
  try {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': address.trim(),
      'format': 'json',
      'limit': '1',
    });
    final res = await http.get(uri, headers: {'User-Agent': 'ArchiManager/1.0'});
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as List;
      if (data.isNotEmpty) {
        final lat = double.tryParse(data[0]['lat'] as String? ?? '');
        final lon = double.tryParse(data[0]['lon'] as String? ?? '');
        if (lat != null && lon != null) {
          return _geocodeCache[key] = LatLng(lat, lon);
        }
      }
    }
  } catch (_) {}
  return _geocodeCache[key] = null;
}

// ─── Modèle interne ───────────────────────────────────────────────────────────
class _ChantierGeo {
  final Project project;
  final LatLng position;
  const _ChantierGeo({required this.project, required this.position});
}

Color _statutColor(String statut) {
  switch (statut) {
    case 'en_cours':   return kAccent;
    case 'termine':    return const Color(0xFF10B981);
    case 'annule':     return kRed;
    default:           return const Color(0xFFD1D5DB); // en_attente
  }
}

// ─── Carte Screen ─────────────────────────────────────────────────────────────
class CarteScreen extends StatefulWidget {
  const CarteScreen({super.key});
  @override
  State<CarteScreen> createState() => _CarteScreenState();
}

class _CarteScreenState extends State<CarteScreen> {
  final MapController _mapController = MapController();

  List<Project>     _projects  = [];
  List<_ChantierGeo> _geocoded = [];
  bool   _loading          = true;
  int?   _selectedIndex;
  LatLng? _myPosition;
  bool   _loadingPosition  = false;

  static const _defaultCenter = LatLng(33.8, 10.85); // Tunisie par défaut

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _selectedIndex = null; });
    try {
      final projects = await ProjetService.getProjets();
      // Coordonnées stockées en priorité, géocodage en fallback
      final futures = projects.map((p) async {
        // 1. Coordonnées exactes enregistrées
        if (p.hasPosition) {
          return _ChantierGeo(project: p, position: LatLng(p.latitude!, p.longitude!));
        }
        // 2. Géocodage du champ localisation
        if (p.localisation.isEmpty) return null;
        final pos = await _geocode(p.localisation);
        if (pos == null) return null;
        return _ChantierGeo(project: p, position: pos);
      });
      final results = await Future.wait(futures);
      final geocoded = results.whereType<_ChantierGeo>().toList();

      setState(() {
        _projects = projects;
        _geocoded = geocoded;
        _loading  = false;
      });

      // Centrer la carte sur le barycentre des projets géocodés
      if (geocoded.isNotEmpty) {
        final avgLat = geocoded.map((c) => c.position.latitude).reduce((a, b) => a + b) / geocoded.length;
        final avgLng = geocoded.map((c) => c.position.longitude).reduce((a, b) => a + b) / geocoded.length;
        _mapController.move(LatLng(avgLat, avgLng), geocoded.length == 1 ? 12.0 : 8.0);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _goToMyPosition() async {
    setState(() => _loadingPosition = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Service désactivé');
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever) throw Exception('Permission refusée');
      final pos = await Geolocator.getCurrentPosition();
      final ll = LatLng(pos.latitude, pos.longitude);
      setState(() => _myPosition = ll);
      _mapController.move(ll, 13);
    } catch (e) {
      if (mounted) showDialog(
        context: context,
        builder: (dctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: kRed.withOpacity(0.12), shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded, color: kRed, size: 24),
            ),
            const SizedBox(width: 12),
            Flexible(child: Text('Position indisponible : $e', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dctx),
              child: const Text('OK', style: TextStyle(color: kRed, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingPosition = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final pad = isMobile ? 16.0 : 28.0;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final geo       = _geocoded;
    final projs     = _projects;
    final nbEnCours = _projects.where((p) => p.statut == 'en_cours').length;
    final nbTermine = _projects.where((p) => p.statut == 'termine').length;
    final nbAttente = _projects.where((p) => p.statut == 'en_attente').length;

    return Container(
      color: kBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Header ────────────────────────────────────────────────────────
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Carte des chantiers', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: kTextMain)),
              const SizedBox(height: 4),
              Text('${_projects.length} projet${_projects.length > 1 ? "s" : ""} · ${_geocoded.length} localisé${_geocoded.length > 1 ? "s" : ""}',
                  style: const TextStyle(color: kTextSub, fontSize: 13)),
            ])),
            IconButton(onPressed: _load, tooltip: 'Actualiser', icon: const Icon(LucideIcons.refreshCw, size: 18, color: kTextSub)),
            if (isMobile) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _loadingPosition ? null : _goToMyPosition,
                icon: _loadingPosition
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: kTextSub))
                    : const Icon(LucideIcons.navigation, size: 14, color: kTextSub),
                label: const Text('Ma position', style: TextStyle(color: kTextSub, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ]),

          const SizedBox(height: 16),

          // ── KPI statuts ───────────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _StatBadge(label: 'En cours',      count: nbEnCours, color: kAccent),
              const SizedBox(width: 10),
              _StatBadge(label: 'Terminés',      count: nbTermine, color: const Color(0xFF10B981)),
              const SizedBox(width: 10),
              _StatBadge(label: 'Planification', count: nbAttente, color: const Color(0xFFD1D5DB), textColor: kTextSub),
            ]),
          ),

          const SizedBox(height: 16),

          // ── Légende ───────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(12),
              border: const Border(left: BorderSide(color: kAccent, width: 3)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(LucideIcons.mapPin, color: kAccent, size: 16),
                SizedBox(width: 8),
                Text('Légende & Informations', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: kTextMain)),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 20, runSpacing: 8, children: [
                _LegendeDot(color: kAccent,                       label: 'En cours'),
                _LegendeDot(color: const Color(0xFF10B981),       label: 'Terminé'),
                _LegendeDot(color: kRed,                          label: 'Annulé'),
                _LegendeDot(color: const Color(0xFFD1D5DB),       label: 'Planification'),
                _LegendeDot(color: Colors.blue,                   label: 'Votre position'),
              ]),
            ]),
          ),

          const SizedBox(height: 16),

          // ── Carte ─────────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(12),
              border: const Border(left: BorderSide(color: kAccent, width: 3)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                child: Row(children: [
                  const Icon(LucideIcons.mapPin, color: kAccent, size: 15),
                  const SizedBox(width: 8),
                  Text('Carte interactive – ${geo.length} marqueur${geo.length > 1 ? "s" : ""}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: kTextMain)),
                  const Spacer(),
                  if (!isMobile)
                    OutlinedButton.icon(
                      onPressed: _loadingPosition ? null : _goToMyPosition,
                      icon: _loadingPosition
                          ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: kTextSub))
                          : const Icon(LucideIcons.navigation, size: 13, color: kTextSub),
                      label: const Text('Ma position', style: TextStyle(color: kTextSub, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                ]),
              ),

              const SizedBox(height: 12),

              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                child: SizedBox(
                  height: isMobile ? 280 : 440,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _defaultCenter,
                      initialZoom: 7.0,
                      onTap: (_, __) => setState(() => _selectedIndex = null),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.archi.manager',
                      ),
                      MarkerLayer(markers: [
                        // Ma position
                        if (_myPosition != null)
                          Marker(
                            point: _myPosition!,
                            width: 20, height: 20,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: const [BoxShadow(color: Colors.blue, blurRadius: 8)],
                              ),
                            ),
                          ),

                        // Marqueurs projets
                        ...geo.asMap().entries.map((e) {
                          final i = e.key;
                          final c = e.value;
                          final color      = _statutColor(c.project.statut);
                          final isSelected = _selectedIndex == i;
                          return Marker(
                            point: c.position,
                            width:  isSelected ? 170 : 36,
                            height: isSelected ? 80  : 36,
                            alignment: Alignment.topCenter,
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedIndex = _selectedIndex == i ? null : i),
                              child: isSelected
                                  ? _MarkerPopup(chantier: c, color: color, onClose: () => setState(() => _selectedIndex = null))
                                  : _MarkerPin(color: color),
                            ),
                          );
                        }),
                      ]),
                    ],
                  ),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 24),

          // ── Titre liste ───────────────────────────────────────────────────
          Text('Projets (${projs.length})', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kTextMain)),

          const SizedBox(height: 14),

          // ── Liste projets ─────────────────────────────────────────────────
          if (projs.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(children: [
                const Icon(LucideIcons.mapPinOff, size: 32, color: kTextSub),
                const SizedBox(height: 10),
                const Text('Aucun projet trouvé', style: TextStyle(color: kTextSub, fontSize: 14)),
              ]),
            ))
          else
            LayoutBuilder(builder: (context, constraints) {
              final cols = constraints.maxWidth > 700 ? 3 : 1;
              if (cols == 1) {
                return Column(children: projs.map((p) {
                  final geo = _geocoded.firstWhere((c) => c.project.id == p.id, orElse: () => _ChantierGeo(project: p, position: _defaultCenter));
                  final hasGeo = _geocoded.any((c) => c.project.id == p.id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ProjetCarteCard(
                      project: p,
                      hasGeo: hasGeo,
                      onTap: hasGeo ? () {
                        _mapController.move(geo.position, 14);
                        setState(() => _selectedIndex = _geocoded.indexWhere((c) => c.project.id == p.id));
                      } : null,
                    ),
                  );
                }).toList());
              }

              // Grille 3 colonnes desktop
              final rows = <Widget>[];
              for (int i = 0; i < projs.length; i += 3) {
                final chunk = projs.sublist(i, (i + 3).clamp(0, projs.length));
                rows.add(Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: chunk.asMap().entries.map((e) {
                    final p      = e.value;
                    final idx    = e.key;
                    final geoObj = _geocoded.firstWhere((c) => c.project.id == p.id, orElse: () => _ChantierGeo(project: p, position: _defaultCenter));
                    final hasGeo = _geocoded.any((c) => c.project.id == p.id);
                    return Expanded(child: Padding(
                      padding: EdgeInsets.only(left: idx == 0 ? 0 : 16),
                      child: _ProjetCarteCard(
                        project: p,
                        hasGeo: hasGeo,
                        onTap: hasGeo ? () {
                          _mapController.move(geoObj.position, 14);
                          setState(() => _selectedIndex = _geocoded.indexWhere((c) => c.project.id == p.id));
                        } : null,
                      ),
                    ));
                  }).toList()),
                ));
              }
              return Column(children: rows);
            }),
        ]),
      ),
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────
class _StatBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final Color textColor;
  const _StatBadge({required this.label, required this.count, required this.color, this.textColor = Colors.white});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text('$count $label', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color == const Color(0xFFD1D5DB) ? kTextSub : color)),
    ]),
  );
}

class _MarkerPin extends StatelessWidget {
  final Color color;
  const _MarkerPin({required this.color});
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Container(
      width: 30, height: 30,
      decoration: BoxDecoration(
        color: color, shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 16),
    ),
    Container(width: 2, height: 6, color: color),
  ]);
}

class _MarkerPopup extends StatelessWidget {
  final _ChantierGeo chantier;
  final Color color;
  final VoidCallback onClose;
  const _MarkerPopup({required this.chantier, required this.color, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final p = chantier.project;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: Text(p.titre, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kTextMain), overflow: TextOverflow.ellipsis)),
          GestureDetector(onTap: onClose, child: const Icon(Icons.close_rounded, size: 12, color: kTextSub)),
        ]),
        const SizedBox(height: 4),
        Text(p.localisation, style: const TextStyle(fontSize: 9, color: kTextSub)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
          child: Text(p.status, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

class _ProjetCarteCard extends StatelessWidget {
  final Project project;
  final bool hasGeo;
  final VoidCallback? onTap;
  const _ProjetCarteCard({required this.project, required this.hasGeo, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p     = project;
    final color = _statutColor(p.statut);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Titre + statut
        Row(children: [
          Expanded(child: Text(p.titre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kTextMain))),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(p.status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 10),

        // Client
        if (p.client.isNotEmpty) ...[
          Row(children: [
            const Icon(LucideIcons.briefcase, size: 13, color: kTextSub),
            const SizedBox(width: 6),
            Expanded(child: Text(p.client, style: const TextStyle(color: kTextSub, fontSize: 12), overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 4),
        ],

        // Localisation
        Row(children: [
          Icon(Icons.location_on_rounded, size: 13, color: hasGeo ? color : kTextSub),
          const SizedBox(width: 6),
          Expanded(child: Text(
            p.localisation.isEmpty ? 'Localisation non renseignée' : p.localisation,
            style: TextStyle(color: hasGeo ? kTextMain : kTextSub, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          )),
          if (!hasGeo && p.localisation.isNotEmpty)
            const Tooltip(
              message: 'Adresse non géocodée',
              child: Icon(LucideIcons.alertCircle, size: 13, color: Color(0xFFF59E0B)),
            ),
        ]),

        // Chef
        if (p.chef.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(children: [
            const Icon(LucideIcons.user, size: 13, color: kTextSub),
            const SizedBox(width: 6),
            Text(p.chef, style: const TextStyle(color: kTextSub, fontSize: 12)),
          ]),
        ],

        const SizedBox(height: 14),

        // Bouton
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onTap,
            icon: Icon(hasGeo ? LucideIcons.mapPin : LucideIcons.mapPinOff, size: 14, color: Colors.white),
            label: Text(
              hasGeo ? 'Voir sur la carte' : 'Non localisé',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: hasGeo ? kAccent : const Color(0xFF9CA3AF),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _LegendeDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendeDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 6),
    Text(label, style: const TextStyle(color: kTextSub, fontSize: 12)),
  ]);
}
