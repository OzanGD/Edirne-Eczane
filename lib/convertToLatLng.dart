//Converts a given list of points into a list of LatLng values

import 'package:google_maps_flutter/google_maps_flutter.dart';

List<LatLng> convertToLatLng(List points) {
  List<LatLng> result = <LatLng>[];
  for (int i = 0; i < points.length; i++) {
    if (i % 2 != 0) {
      result.add(LatLng(points[i - 1], points[i]));
    }
  }
  return result;
}
