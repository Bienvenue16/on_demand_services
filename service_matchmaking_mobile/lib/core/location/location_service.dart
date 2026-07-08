import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationResult {
  const LocationResult({
    required this.latitude,
    required this.longitude,
    this.address,
    this.city,
  });

  final double latitude;
  final double longitude;
  final String? address;
  final String? city;
}

class LocationException implements Exception {
  const LocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Capture la position GPS de l'utilisateur et la convertit en adresse lisible
/// via le geocodage inverse natif du telephone (gratuit, sans cle API).
class LocationService {
  const LocationService();

  Future<LocationResult> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationException(
        'La localisation est desactivee sur cet appareil. Activez-la dans les reglages.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationException('Permission de localisation refusee.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Permission de localisation refusee definitivement. '
        'Autorisez-la dans les reglages de l\'application.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    String? address;
    String? city;
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        city = (placemark.locality?.trim().isNotEmpty ?? false)
            ? placemark.locality
            : placemark.subAdministrativeArea;
        final parts = <String>{
          for (final part in [
            placemark.street,
            placemark.subLocality,
            city,
            placemark.country,
          ])
            if (part != null && part.trim().isNotEmpty) part.trim(),
        };
        address = parts.join(', ');
      }
    } catch (_) {
      // Le geocodage inverse est un bonus best-effort : on garde au minimum lat/lng.
    }

    return LocationResult(
      latitude: position.latitude,
      longitude: position.longitude,
      address: address,
      city: city,
    );
  }
}
