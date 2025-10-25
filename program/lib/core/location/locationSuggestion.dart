class LocationSuggestion {
  final String name;
  final String country;
  final double lat;
  final double lng;
  final String? adminName1;
  final String? adminName2;

  LocationSuggestion({
    required this.name,
    required this.country,
    required this.lat,
    required this.lng,
    this.adminName1,
    this.adminName2,
  });

  factory LocationSuggestion.fromJson(Map<String, dynamic> json) {
    return LocationSuggestion(
      name: json['name'] as String,
      country: json['countryName'] as String,
      lat: double.parse(json['lat'].toString()),
      lng: double.parse(json['lng'].toString()),
      adminName1: json['adminName1'] as String?,
      adminName2: json['adminName2'] as String?,
    );
  }

  String get displayName {
    final parts = <String>[name];
    if (adminName2 != null && adminName2 != name) {
      parts.add(adminName2!);
    }
    if (adminName1 != null && adminName1 != adminName2) {
      parts.add(adminName1!);
    }
    return parts.join(', ');
  }
}
