import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../constants/app_colors.dart';
import '../map/osm_tile_provider.dart';

/// P2.4 — real interactive geographic map (CARTO Free tiles via flutter_map).
/// Never uses decorative fake painters as the map surface.
/// Tile success is independent of GPS success.
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
    this.debugForceTilesFailed = false,
  });

  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final double height;
  final List<YusrMapZone> zones;
  final void Function(LatLng point)? onTap;
  final bool centerOnUser;
  final bool showAttribution;

  /// Test-only: show Arabic tile error + retry without waiting for network.
  final bool debugForceTilesFailed;

  @override
  State<YusrMapView> createState() => _YusrMapViewState();
}

class YusrMapZone {
  const YusrMapZone({
    required this.center,
    required this.radiusMeters,
    this.label,
    // Stronger fill/border so EMA screenshots show a clear geographic circle.
    this.color = const Color(0x55125D73),
    this.borderColor = const Color(0xFF0D47A1),
    this.borderStrokeWidth = 3,
  });

  final LatLng center;
  final double radiusMeters;
  final String? label;
  final Color color;
  final Color borderColor;
  final double borderStrokeWidth;
}

class _YusrMapViewState extends State<YusrMapView> {
  final MapController _controller = MapController();
  bool _tilesFailed = false;
  int _tileRetryGeneration = 0;
  late final NetworkTileProvider _tileProvider =
      OsmTileProvider.createNetworkTileProvider();

  bool get _missingKey => !OsmTileProvider.hasApiKey;

  @override
  void initState() {
    super.initState();
    _tilesFailed = widget.debugForceTilesFailed;
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitContent());
  }

  void _fitContent() {
    try {
      if (widget.zones.isNotEmpty && !_hasFix) {
        final z = widget.zones.first;
        // ~14–15 keeps a typical 100–200 m radius readable on phone.
        _controller.move(z.center, 15);
      } else if (_hasFix) {
        _controller.move(_center, _controller.camera.zoom);
      }
    } catch (_) {}
  }

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
  void dispose() {
    unawaited(_tileProvider.dispose());
    super.dispose();
  }

  void _retryTiles() {
    setState(() {
      _tilesFailed = false;
      _tileRetryGeneration++;
    });
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
            if (!_missingKey)
              FlutterMap(
                key: ValueKey('yusr-map-tiles-$_tileRetryGeneration'),
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
                ),
                children: [
                  TileLayer(
                    urlTemplate: OsmTileProvider.urlTemplate,
                    fallbackUrl: OsmTileProvider.fallbackUrl,
                    subdomains: OsmTileProvider.subdomains,
                    userAgentPackageName: OsmTileProvider.userAgentPackageName,
                    tileProvider: _tileProvider,
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
                            borderStrokeWidth: z.borderStrokeWidth,
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
            if (_missingKey)
              Positioned.fill(
                child: Container(
                  color: const Color(0xFF37474F),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    OsmTileProvider.missingKeyErrorArabic,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            if (!_missingKey && !_hasFix)
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
            if (!_missingKey && _tilesFailed)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.55),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        OsmTileProvider.tileLoadErrorArabic,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _retryTiles,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.mainColor,
                        ),
                        icon: const Icon(Icons.refresh),
                        label: Text(
                          'إعادة المحاولة',
                          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (widget.showAttribution && !_missingKey && !_tilesFailed)
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
            if (!_missingKey)
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
