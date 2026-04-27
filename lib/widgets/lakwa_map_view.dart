import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Map marker for [LakwaMapView] (id must be unique per map).
class LakwaMapMarker {
  const LakwaMapMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.title,
    this.snippet,
    this.hue,
  });

  final String id;
  final double latitude;
  final double longitude;
  final String title;
  final String? snippet;
  final double? hue;

  LatLng get position => LatLng(latitude, longitude);
}

/// Center of Philippines — used when there are no pins to show.
const LatLng kDefaultMapCenter = LatLng(12.8797, 121.7740);

/// Delay before attaching the native map view so route transitions / layout settle.
/// Helps avoid crashes when opening maps immediately after navigation.
const Duration _kDefaultMapAttachDelay = Duration(milliseconds: 320);

class LakwaMapView extends StatefulWidget {
  const LakwaMapView({
    super.key,
    required this.pins,
    this.showMyLocation = true,
    this.height,
    this.initialZoom = 12,
    this.attachDelay,
  });

  final List<LakwaMapMarker> pins;
  final bool showMyLocation;
  final double? height;
  final double initialZoom;

  /// Override default [_mapAttachDelay] for embedded previews if needed.
  final Duration? attachDelay;

  @override
  State<LakwaMapView> createState() => _LakwaMapViewState();
}

class _LakwaMapViewState extends State<LakwaMapView> {
  GoogleMapController? _controller;
  bool _surfaceReady = false;

  /// Marker IDs must be unique; duplicate IDs crash on some platforms.
  String _markerId(LakwaMapMarker p, int index) => '${index}_${p.id}';

  static const _hues = <double>[
    BitmapDescriptor.hueRed,
    BitmapDescriptor.hueBlue,
    BitmapDescriptor.hueGreen,
    BitmapDescriptor.hueOrange,
    BitmapDescriptor.hueViolet,
    BitmapDescriptor.hueRose,
    BitmapDescriptor.hueCyan,
    BitmapDescriptor.hueMagenta,
  ];

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    final delay = widget.attachDelay ?? _kDefaultMapAttachDelay;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(delay, () {
        if (mounted) setState(() => _surfaceReady = true);
      });
    });
  }

  @override
  void didUpdateWidget(LakwaMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_pinsChanged(oldWidget.pins, widget.pins)) {
      unawaited(_fitCamera());
    }
  }

  bool _pinsChanged(List<LakwaMapMarker> a, List<LakwaMapMarker> b) {
    if (a.length != b.length) return true;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].latitude != b[i].latitude ||
          a[i].longitude != b[i].longitude) {
        return true;
      }
    }
    return false;
  }

  void _onMapCreated(GoogleMapController c) {
    _controller = c;
    unawaited(_fitCamera());
  }

  Future<void> _fitCamera() async {
    final c = _controller;
    if (c == null || !mounted) return;
    final pins = widget.pins;
    try {
      if (pins.isEmpty) {
        await c.animateCamera(CameraUpdate.newLatLngZoom(kDefaultMapCenter, 5));
        return;
      }
      if (pins.length == 1) {
        await c.animateCamera(
          CameraUpdate.newLatLngZoom(pins.first.position, widget.initialZoom),
        );
        return;
      }
      await c.animateCamera(
        CameraUpdate.newLatLngBounds(_boundsForPins(pins), 56),
      );
    } catch (e, st) {
      debugPrint('LakwaMapView: camera update failed: $e\n$st');
    }
  }

  LatLngBounds _boundsForPins(List<LakwaMapMarker> pins) {
    var minLat = pins.first.latitude;
    var maxLat = minLat;
    var minLng = pins.first.longitude;
    var maxLng = minLng;
    for (final p in pins) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    var latPad = math.max(0.01, (maxLat - minLat) * 0.15);
    var lngPad = math.max(0.01, (maxLng - minLng) * 0.15);
    if (maxLat - minLat < 1e-9) latPad = 0.01;
    if (maxLng - minLng < 1e-9) lngPad = 0.01;
    return LatLngBounds(
      southwest: LatLng(minLat - latPad, minLng - lngPad),
      northeast: LatLng(maxLat + latPad, maxLng + lngPad),
    );
  }

  Widget _loadingPlaceholder() {
    final child = const Center(child: CircularProgressIndicator.adaptive());
    final h = widget.height;
    if (h != null) {
      return SizedBox(height: h, width: double.infinity, child: child);
    }
    return SizedBox.expand(child: child);
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return SizedBox(
        height: widget.height ?? 200,
        child: ColoredBox(
          color: Colors.grey.shade200,
          child: const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Interactive maps are available in the iOS and Android app.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    if (!_surfaceReady) {
      return _loadingPlaceholder();
    }

    final markers = <Marker>{};
    for (var i = 0; i < widget.pins.length; i++) {
      final p = widget.pins[i];
      final hue = p.hue ?? _hues[i % _hues.length];
      markers.add(
        Marker(
          markerId: MarkerId(_markerId(p, i)),
          position: p.position,
          infoWindow: InfoWindow(
            title: p.title,
            snippet: p.snippet,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        ),
      );
    }

    final first = widget.pins.isNotEmpty ? widget.pins.first.position : kDefaultMapCenter;

    /// Location permission is handled by the Maps SDK when this layer is enabled — do not use
    /// [permission_handler] here; overlapping permission flows caused crashes on some devices.
    final map = GoogleMap(
      initialCameraPosition: CameraPosition(
        target: first,
        zoom: widget.pins.length <= 1 ? widget.initialZoom : 9,
      ),
      markers: markers,
      onMapCreated: _onMapCreated,
      myLocationEnabled: widget.showMyLocation,
      myLocationButtonEnabled: widget.showMyLocation,
      mapToolbarEnabled: false,
      compassEnabled: true,
    );

    if (widget.height != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(height: widget.height, child: map),
      );
    }
    return map;
  }
}
