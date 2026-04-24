import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../constants/colors.dart';

/// Ouvre le sélecteur de position. Retourne [LatLng] si confirmé, null sinon.
Future<LatLng?> showMapLocationPicker(BuildContext context, {LatLng? initial}) {
  return showDialog<LatLng>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => _MapLocationPickerDialog(initial: initial),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
class _MapLocationPickerDialog extends StatefulWidget {
  final LatLng? initial;
  const _MapLocationPickerDialog({this.initial});
  @override
  State<_MapLocationPickerDialog> createState() => _MapLocationPickerDialogState();
}

class _MapLocationPickerDialogState extends State<_MapLocationPickerDialog>
    with SingleTickerProviderStateMixin {

  final _mapCtrl    = MapController();
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  LatLng? _selected;
  double  _zoom         = 7.0;
  bool    _searching    = false;
  bool    _loadingGps   = false;
  List<Map<String, dynamic>> _suggestions = [];

  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  static const _defaultCenter = LatLng(33.8, 10.85);

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
    if (widget.initial != null) _zoom = 14.0;

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Zoom ──────────────────────────────────────────────────────────────────
  void _zoomIn()  => _mapCtrl.move(_mapCtrl.camera.center, (_zoom + 1).clamp(1.0, 19.0));
  void _zoomOut() => _mapCtrl.move(_mapCtrl.camera.center, (_zoom - 1).clamp(1.0, 19.0));
  void _centerOnMarker() {
    if (_selected != null) _mapCtrl.move(_selected!, _zoom.clamp(12.0, 19.0));
  }

  // ── GPS ───────────────────────────────────────────────────────────────────
  Future<void> _goToMyPosition() async {
    setState(() => _loadingGps = true);
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) throw Exception('Service de localisation désactivé');
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever) throw Exception('Permission refusée');
      final pos = await Geolocator.getCurrentPosition();
      final ll  = LatLng(pos.latitude, pos.longitude);
      setState(() { _selected = ll; _zoom = 16.0; });
      _mapCtrl.move(ll, 16.0);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$e'),
        backgroundColor: kRed,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } finally {
      if (mounted) setState(() => _loadingGps = false);
    }
  }

  // ── Recherche Nominatim ───────────────────────────────────────────────────
  Future<void> _onSearchChanged(String q) async {
    if (q.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': q.trim(), 'format': 'json', 'limit': '5',
        'accept-language': 'fr',
      });
      final res  = await http.get(uri, headers: {'User-Agent': 'ArchiManager/1.0'});
      final data = jsonDecode(res.body) as List;
      if (mounted) setState(() => _suggestions = data.cast<Map<String, dynamic>>());
    } catch (_) {
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectSuggestion(Map<String, dynamic> item) {
    final lat = double.tryParse(item['lat'] as String? ?? '');
    final lon = double.tryParse(item['lon'] as String? ?? '');
    if (lat == null || lon == null) return;
    final ll = LatLng(lat, lon);
    _searchCtrl.text = item['display_name'] as String? ?? '';
    setState(() { _selected = ll; _zoom = 15.0; _suggestions = []; });
    _mapCtrl.move(ll, 15.0);
    _searchFocus.unfocus();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenH  = MediaQuery.of(context).size.height;
    final screenW  = MediaQuery.of(context).size.width;
    final isMobile = screenW < 600;

    return Dialog(
      insetPadding: isMobile
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      shape: isMobile
          ? const RoundedRectangleBorder()
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 640, maxHeight: screenH * 0.94),
        child: Column(children: [

          // ── Header ────────────────────────────────────────────────────────
          _buildHeader(),

          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // ── Carte ─────────────────────────────────────────────────────────
          Expanded(child: _buildMap()),

          // ── Footer ────────────────────────────────────────────────────────
          _buildFooter(),
        ]),
      ),
    );
  }

  Widget _buildHeader() => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Titre + fermer
      Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: kAccent.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
          child: const Icon(LucideIcons.mapPin, color: kAccent, size: 18),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Choisir la position', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kTextMain)),
          SizedBox(height: 2),
          Text('Recherchez une adresse ou appuyez sur la carte', style: TextStyle(fontSize: 11, color: kTextSub)),
        ])),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.close_rounded, size: 18, color: kTextSub),
          ),
        ),
      ]),

      const SizedBox(height: 12),

      // Barre de recherche
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _searching
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kAccent))
                : const Icon(LucideIcons.search, size: 16, color: kTextSub),
          ),
          Expanded(child: TextField(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            style: const TextStyle(fontSize: 13, color: kTextMain),
            decoration: const InputDecoration(
              hintText: 'Ex : Djerba, Tunis, Sfax…',
              hintStyle: TextStyle(color: kTextSub, fontSize: 13),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: _onSearchChanged,
            onSubmitted: (_) {
              if (_suggestions.isNotEmpty) _selectSuggestion(_suggestions.first);
            },
          )),
          if (_searchCtrl.text.isNotEmpty)
            GestureDetector(
              onTap: () { _searchCtrl.clear(); setState(() => _suggestions = []); },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.close_rounded, size: 16, color: kTextSub),
              ),
            ),
        ]),
      ),

      // Suggestions
      if (_suggestions.isNotEmpty)
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.09), blurRadius: 14, offset: const Offset(0, 5))],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: _suggestions.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
            itemBuilder: (_, i) {
              final s    = _suggestions[i];
              final name = s['display_name'] as String? ?? '';
              final type = s['type'] as String? ?? '';
              return InkWell(
                onTap: () => _selectSuggestion(s),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(children: [
                    Icon(_iconForType(type), size: 14, color: kAccent),
                    const SizedBox(width: 10),
                    Expanded(child: Text(name, style: const TextStyle(fontSize: 12, color: kTextMain), maxLines: 2, overflow: TextOverflow.ellipsis)),
                    const Icon(LucideIcons.cornerDownLeft, size: 12, color: kTextSub),
                  ]),
                ),
              );
            },
          ),
        ),
    ]),
  );

  Widget _buildMap() => Stack(children: [

    // Carte principale
    FlutterMap(
      mapController: _mapCtrl,
      options: MapOptions(
        initialCenter: _selected ?? _defaultCenter,
        initialZoom: _zoom,
        onTap: (_, ll) {
          setState(() => _selected = ll);
          _searchFocus.unfocus();
          if (_suggestions.isNotEmpty) setState(() => _suggestions = []);
        },
        onMapEvent: (event) {
          final z = event.camera.zoom;
          if ((z - _zoom).abs() > 0.01) setState(() => _zoom = z);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.archi.manager',
        ),
        if (_selected != null)
          MarkerLayer(markers: [
            Marker(
              point: _selected!,
              width: 64, height: 64,
              alignment: Alignment.center,
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Stack(alignment: Alignment.center, children: [
                  // Halo extérieur animé
                  Container(
                    width: 44 + _pulseAnim.value * 20,
                    height: 44 + _pulseAnim.value * 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: kAccent.withOpacity(0.18 * (1 - _pulseAnim.value)),
                    ),
                  ),
                  // Halo intérieur
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: kAccent.withOpacity(0.15),
                    ),
                  ),
                  // Pin
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: kAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [BoxShadow(color: kAccent.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 3))],
                      ),
                      child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 14),
                    ),
                    Container(width: 2, height: 7, color: kAccent),
                  ]),
                ]),
              ),
            ),
          ]),
      ],
    ),

    // ── Instruction centrale (si aucune position) ─────────────────────────
    if (_selected == null)
      Center(child: IgnorePointer(child: AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.60),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(LucideIcons.mousePointerClick, size: 14, color: Colors.white),
            SizedBox(width: 7),
            Text('Appuyez sur la carte', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      ))),

    // ── GPS + Centrer (gauche) ────────────────────────────────────────────
    Positioned(left: 10, bottom: 12, child: Column(children: [
      _MapFab(
        tooltip: 'Ma position GPS',
        loading: _loadingGps,
        icon: LucideIcons.navigation,
        onTap: _goToMyPosition,
      ),
      if (_selected != null) ...[
        const SizedBox(height: 8),
        _MapFab(
          tooltip: 'Centrer sur le marqueur',
          icon: LucideIcons.crosshair,
          onTap: _centerOnMarker,
        ),
      ],
    ])),

    // ── Zoom +/niveau/- (droite) ──────────────────────────────────────────
    Positioned(right: 10, bottom: 12, child: Column(children: [
      _MapFab(icon: LucideIcons.plus,  tooltip: 'Zoom avant',  onTap: _zoomIn),
      const SizedBox(height: 3),
      Container(
        width: 38,
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 6)],
        ),
        child: Text(
          _zoom.toStringAsFixed(1),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kTextMain),
        ),
      ),
      const SizedBox(height: 3),
      _MapFab(icon: LucideIcons.minus, tooltip: 'Zoom arrière', onTap: _zoomOut),
    ])),

    // ── Attribution ───────────────────────────────────────────────────────
    Positioned(right: 6, top: 6, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.78), borderRadius: BorderRadius.circular(4)),
      child: const Text('© OpenStreetMap', style: TextStyle(fontSize: 9, color: kTextSub)),
    )),
  ]);

  Widget _buildFooter() => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
    child: Column(mainAxisSize: MainAxisSize.min, children: [

      // Coordonnées avec switch animé
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(anim),
            child: child,
          ),
        ),
        child: _selected == null
            ? Container(
                key: const ValueKey('no_pos'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(children: [
                  Icon(LucideIcons.info, size: 14, color: Color(0xFFF59E0B)),
                  SizedBox(width: 8),
                  Text('Aucune position sélectionnée — utilisez la carte ou la recherche', style: TextStyle(fontSize: 12, color: Color(0xFF92400E))),
                ]),
              )
            : Container(
                key: const ValueKey('has_pos'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: const Color(0xFF6EE7B7)),
                ),
                child: Row(children: [
                  const Icon(LucideIcons.checkCircle, size: 15, color: Color(0xFF10B981)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Position confirmée', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF065F46))),
                    const SizedBox(height: 2),
                    Text(
                      'Lat ${_selected!.latitude.toStringAsFixed(6)}   Lng ${_selected!.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF047857)),
                    ),
                  ])),
                  GestureDetector(
                    onTap: () => setState(() => _selected = null),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded, size: 16, color: Color(0xFF10B981)),
                    ),
                  ),
                ]),
              ),
      ),

      const SizedBox(height: 12),

      Row(children: [
        Expanded(child: OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 13),
            side: const BorderSide(color: Color(0xFFD1D5DB)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Annuler', style: TextStyle(color: kTextSub, fontWeight: FontWeight.w600)),
        )),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton.icon(
          onPressed: _selected == null ? null : () => Navigator.pop(context, _selected),
          icon: const Icon(LucideIcons.mapPin, size: 14, color: Colors.white),
          label: const Text('Confirmer la position', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: kAccent,
            disabledBackgroundColor: const Color(0xFFD1D5DB),
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        )),
      ]),
    ]),
  );

  IconData _iconForType(String type) {
    switch (type) {
      case 'city':
      case 'town':
      case 'village':   return LucideIcons.building2;
      case 'road':
      case 'street':    return LucideIcons.navigation;
      case 'house':
      case 'building':  return LucideIcons.home;
      default:          return LucideIcons.mapPin;
    }
  }
}

// ── Bouton flottant sur la carte ──────────────────────────────────────────────
class _MapFab extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool loading;

  const _MapFab({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.13), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Center(
          child: loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kAccent))
              : Icon(icon, size: 17, color: kTextMain),
        ),
      ),
    ),
  );
}
