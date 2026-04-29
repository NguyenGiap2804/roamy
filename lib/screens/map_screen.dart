import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';
import '../models/place.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key, required this.place});

  final Place place;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(place.name),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: place.hasCoordinates
          ? _PlaceMap(place: place)
          : const _MissingLocationState(),
    );
  }
}

class _PlaceMap extends StatelessWidget {
  const _PlaceMap({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context) {
    final target = LatLng(place.latitude!, place.longitude!);

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: target, zoom: 15),
      markers: {
        Marker(
          markerId: MarkerId(place.id),
          position: target,
          infoWindow: InfoWindow(title: place.name, snippet: place.address),
        ),
      },
      myLocationEnabled: true,
    );
  }
}

class _MissingLocationState extends StatelessWidget {
  const _MissingLocationState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_off_rounded,
              size: 56,
              color: AppColors.primary,
            ),
            const SizedBox(height: 14),
            Text('Location not available', style: AppTextStyles.title),
            const SizedBox(height: 6),
            Text(
              'This place does not have coordinates yet.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
