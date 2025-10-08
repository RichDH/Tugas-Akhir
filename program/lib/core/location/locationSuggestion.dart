class LocationSuggestion {
  final String name;
  final String country;
  final double lat;
  final double lng;

  LocationSuggestion({
    required this.name,
    required this.country,
    required this.lat,
    required this.lng,
  });

  factory LocationSuggestion.fromJson(Map<String, dynamic> json) {
    return LocationSuggestion(
      name: json['name'] as String,
      country: json['countryName'] as String,
      lat: json['lat'] as double,
      lng: json['lng'] as double,
    );
  }
}