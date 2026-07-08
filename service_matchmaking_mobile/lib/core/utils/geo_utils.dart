import 'dart:math' as math;

/// Distance en kilometres entre deux points GPS (formule de Haversine).
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusKm = 6371.0;
  final phi1 = _degToRad(lat1);
  final phi2 = _degToRad(lat2);
  final dPhi = _degToRad(lat2 - lat1);
  final dLambda = _degToRad(lng2 - lng1);

  final a = math.sin(dPhi / 2) * math.sin(dPhi / 2) +
      math.cos(phi1) * math.cos(phi2) * math.sin(dLambda / 2) * math.sin(dLambda / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusKm * c;
}

double _degToRad(double deg) => deg * (math.pi / 180.0);

/// Formatte une distance en km avec une decimale et une virgule francaise (ex: "2,4 km").
String formatDistanceKm(double km) {
  return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
}
