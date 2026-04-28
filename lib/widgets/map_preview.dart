import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/place.dart';
import '../screens/map_screen.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';

class MapPreview extends StatelessWidget {
  const MapPreview({super.key, required this.place});

  final Place place;

  @override
  Widget build(BuildContext context) {
    if (place.latitude == null || place.longitude == null) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          'Location not available',
          style: AppTextStyles.body.copyWith(color: Colors.black54),
        ),
      );
    }

    final target = LatLng(place.latitude!, place.longitude!);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => MapScreen(place: place)),
        );
      },
      child: Container(
        height: 200,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: AbsorbPointer(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: target, zoom: 15),
            markers: {Marker(markerId: MarkerId(place.id), position: target)},
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            myLocationButtonEnabled: false,
            liteModeEnabled: true,
          ),
        ),
      ),
    );
  }
}
