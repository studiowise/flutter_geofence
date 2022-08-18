class Geolocation {
  final double latitude;
  final double longitude;
  final double radius; // in meters
  final String id;

  const Geolocation({required this.latitude,
    required this.longitude,
    required this.radius,
    required this.id});

  static Geolocation fromMap(Map<String, dynamic> json) {
    return Geolocation(
      latitude: json["latitude"] as double,
      longitude: json["longitude"] as double,
      radius: json["radius"] as double,
      id: json["id"] as String,
    );
  }

  @override
  String toString() {
    return 'Geolocation{latitude: $latitude, longitude: $longitude, radius: $radius, id: $id}';
  }

}

enum GeolocationEvent { entry, exit }
