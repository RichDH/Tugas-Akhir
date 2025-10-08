import 'package:http/http.dart' as http;
import 'dart:convert';

import 'locationSuggestion.dart';

class LocationService {
  static Future<List<LocationSuggestion>> searchLocations(String query) async {
    final url = Uri.parse('http://api.geonames.org/searchJSON?q=$query&country=ID&username=techtitan87');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final geonames = data['geonames'] as List<dynamic>;
      return geonames.map((e) => LocationSuggestion.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load locations');
    }
  }
}