import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:larga/widgets/lakwa_map_view.dart';

/// One pin + optional "my location" (blue dot) for a destination or itinerary stop.
class SingleLocationMapScreen extends StatelessWidget {
  const SingleLocationMapScreen({
    super.key,
    required this.title,
    this.subtitle,
    required this.latitude,
    required this.longitude,
  });

  final String title;
  final String? subtitle;
  final double latitude;
  final double longitude;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location'),
      ),
      body: kIsWeb
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Maps are available in the iOS and Android app.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : LakwaMapView(
              pins: [
                LakwaMapMarker(
                  id: 'place',
                  latitude: latitude,
                  longitude: longitude,
                  title: title,
                  snippet: subtitle,
                ),
              ],
              showMyLocation: true,
              initialZoom: 15,
            ),
    );
  }
}
