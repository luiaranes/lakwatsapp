import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:larga/services/trip_destination_service.dart';
import 'package:larga/widgets/lakwa_map_view.dart';

/// Full-screen map of all trip destinations that have coordinates.
class TripMapScreen extends StatelessWidget {
  const TripMapScreen({
    super.key,
    required this.tripTitle,
    required this.destinations,
  });

  final String tripTitle;
  final List<TripDestinationWithDetails> destinations;

  @override
  Widget build(BuildContext context) {
    final onMap = destinations
        .where((d) => d.hasMapPin)
        .toList();

    final pins = onMap
        .asMap()
        .entries
        .map(
          (e) => LakwaMapMarker(
            id: e.value.tripDestination.id,
            latitude: e.value.latitude!,
            longitude: e.value.longitude!,
            title: e.value.name,
            snippet: e.value.fullLocation.isNotEmpty ? e.value.fullLocation : null,
            hue: null,
          ),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Map · $tripTitle'),
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
          : (pins.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map_outlined, size: 56, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No mappable stops yet',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add destinations to this trip that include map coordinates (from Explore).',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600], height: 1.4),
                        ),
                      ],
                    ),
                  ),
                )
              : LakwaMapView(
                  pins: pins,
                  showMyLocation: true,
                )),
    );
  }
}
