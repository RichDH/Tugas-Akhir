import 'package:http/http.dart' as http;
import 'dart:convert';

import 'locationSuggestion.dart';

class LocationService {
  static const String _username = 'techtitan87';

  static Future<List<LocationSuggestion>> searchLocations(String query) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = Uri.parse(
          'http://api.geonames.org/searchJSON?q=$encodedQuery&country=ID&maxRows=10&username=$_username&featureClass=P'
      );

      print('Calling GeoNames API: $url'); // Debug log

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      print('Response status: ${response.statusCode}'); // Debug log
      print('Response body: ${response.body}'); // Debug log

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Cek apakah ada error dari GeoNames API
        if (data.containsKey('status')) {
          final status = data['status'];
          throw Exception('GeoNames API Error: ${status['message']}');
        }

        if (data.containsKey('geonames')) {
          final geonames = data['geonames'] as List<dynamic>;
          return geonames.map((e) => LocationSuggestion.fromJson(e)).toList();
        } else {
          return [];
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } catch (e) {
      print('LocationService Error: $e'); // Debug log
      rethrow;
    }
  }
}
