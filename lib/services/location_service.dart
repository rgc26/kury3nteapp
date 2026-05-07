import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationSuggestion {
  final String name;
  final String address;
  final double lat;
  final double lng;

  LocationSuggestion({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
  });
}

class LocationService {
  static const String _nominatimUrl = 'https://nominatim.openstreetmap.org/search';

  Future<List<LocationSuggestion>> searchLocations(String query) async {
    if (query.length < 3) return [];

    try {
      final response = await http.get(
        Uri.parse('$_nominatimUrl?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&limit=5&countrycodes=ph'),
        headers: {
          'User-Agent': 'KuryenteApp/1.0', // Required by Nominatim policy
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) {
          final displayName = item['display_name'] as String;
          final parts = displayName.split(',');
          final name = parts[0].trim();
          final address = parts.skip(1).join(',').trim();
          
          return LocationSuggestion(
            name: name,
            address: address,
            lat: double.parse(item['lat']),
            lng: double.parse(item['lon']),
          );
        }).toList();
      }
    } catch (e) {
      print('Location search error: $e');
    }
    return [];
  }
}
