import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:locode/features/heatmap/data/seed/savannah_parking_data.dart';

class ThreatMarkerBuilder {

  /// Generates a set of markers from parking location data
  static Future<Set<Marker>> buildMarkers({
    required List<ParkingLocation> locations,
    required Function(ParkingLocation) onTap,
    BitmapDescriptor? redPin,
    BitmapDescriptor? greenPin,
    BitmapDescriptor? grayPin,
  }) async {
    final markers = <Marker>{};

    for (final location in locations) {
      final icon = _getPinForStatus(location.status, redPin, greenPin, grayPin);

      markers.add(Marker(
        markerId: MarkerId(location.name),
        position: LatLng(location.latitude, location.longitude),
        icon: icon,
        infoWindow: InfoWindow.noText,
        onTap: () => onTap(location),
      ));
    }

    return markers;
  }

  static BitmapDescriptor _getPinForStatus(
    ThreatStatus status,
    BitmapDescriptor? redPin,
    BitmapDescriptor? greenPin,
    BitmapDescriptor? grayPin,
  ) {
    return switch (status) {
      ThreatStatus.reported => redPin ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ThreatStatus.suspicious => grayPin ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ThreatStatus.unknown => grayPin ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
      ThreatStatus.safe => greenPin ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    };
  }
}