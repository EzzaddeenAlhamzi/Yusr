import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../constants/app_colors.dart';
import '../map/osm_tile_provider.dart';

/// P2.4 — real interactive geographic map (OSM tiles via flutter_map).
/// Never uses decorative fake painters as the map surface.
class YusrMapView extends StatefulWidget {
  const YusrMapView({
    super.key,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.height = 230,
    this.zones = const [],
    this.onTap,
    this.centerOnUser = true,
    this.showAttribution = true,
  });

  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final double height;
  final List<YusrMapZone> zones;
  final void Function(LatLng point)? onTap;
  final bool centerOnUser;
  final bool showAttribution;

  @override
  State<YusrMapView> createState() => _YusrMapViewState();
}

class YusrMapZone {
  const YusrMapZone({
    required this.center,
    required this.radiusMeters,
    this.label,
    this.color = const Color(0x33125D73),
    this.borderColor = const Color(0xFF125D73),
  });

  final LatLng center;
  final double radiusMeters;
  final String? label;
  final Color color;
  final Color borderColor;
}

class _YusrMapViewState extends State<YusrMapView> {
  final MapController _controller = MapController();
  bool _tilesFailed = false;

  bool get _hasFix => widget.latitude != null && widget.longitude != null;

  LatLng get _center {
    if (_hasFix) {
      return LatLng(widget.latitude!, widget.longitude!);
    }
    if (widget.zones.isNotEmpty) {
      return widget.zones.first.center;
    }
    // Neutral default (Sana'a) only for empty map framing — not a live GPS claim.
    return const LatLng(15.3694, 44.1910);
  }

  @override
  void didUpdateWidget(covariant YusrMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.centerOnUser &&
        _hasFix &&
        (oldWidget.latitude != widget.latitude ||
            oldWidget.longitude != widget.longitude)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _controller.move(_center, _controller.camera.zoom);
        } catch (_) {}
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: widget.height,
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorderColor, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: _hasFix ? 15 : 12,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onTap: widget.onTap == null
                    ? null
                    : (tap, point) => widget.onTap!(point),
                onMapReady: () {
                  // Attribution / tile URL configured via OsmTileProvider.
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: OsmTileProvider.urlTemplate,
                  userAgentPackageName: OsmTileProvider.userAgentPackageName,
                  maxZoom: 19,
                  errorTileCallback: (tile, error, stackTrace) {
                    if (mounted && !_tilesFailed) {
                      setState(() => _tilesFailed = true);
                    }
                  },
                ),
                if (widget.zones.isNotEmpty)
                  CircleLayer(
                    circles: [
                      for (final z in widget.zones)
                        CircleMarker(
                          point: z.center,
                          radius: z.radiusMeters,
                          useRadiusInMeter: true,
                          color: z.color,
                          borderStrokeWidth: 2,
                          borderColor: z.borderColor,
                        ),
                    ],
                  ),
                if (_hasFix &&
                    widget.accuracyMeters != null &&
                    widget.accuracyMeters! > 0)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _center,
                        radius: widget.accuracyMeters!,
                        useRadiusInMeter: true,
                        color: const Color(0x332E7D32),
                        borderStrokeWidth: 1,
                        borderColor: const Color(0xFF2E7D32),
                      ),
                    ],
                  ),
                if (_hasFix)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _center,
                        width: 44,
                        height: 44,
                        child: const Icon(
                          Icons.location_on,
                          color: Color(0xFFC62828),
                          size: 40,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            if (!_hasFix)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'الموقع غير معروف حالياً',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            if (_tilesFailed)
              Positioned(
                left: 8,
                right: 8,
                top: 8,
                child: Material(
                  color: Colors.orange.shade800,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      'تعذّر تحميل بلاطات الخريطة — تحقق من الاتصال',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            if (widget.showAttribution)
              Positioned(
                left: 6,
                bottom: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  color: Colors.white.withValues(alpha: 0.85),
                  child: Text(
                    OsmTileProvider.attributionText,
                    style: GoogleFonts.cairo(fontSize: 10, color: Colors.black87),
                  ),
                ),
              ),
            Positioned(
              top: 10,
              left: 10,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 2,
                child: IconButton(
                  tooltip: 'توسيط على الموقع',
                  icon: const Icon(Icons.my_location, color: AppColors.mainColor),
                  onPressed: _hasFix
                      ? () => _controller.move(_center, 16)
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
