import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/place.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key, required this.place});

  final Place place;

  @override
  Widget build(BuildContext context) {
    final target = LatLng(place.latitude ?? 0, place.longitude ?? 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(place.name),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: target, zoom: 15),
        markers: {
          Marker(
            markerId: MarkerId(place.id),
            position: target,
            infoWindow: InfoWindow(title: place.name, snippet: place.address),
          ),
        },
        myLocationEnabled: true,
      ),
    );
  }
}
