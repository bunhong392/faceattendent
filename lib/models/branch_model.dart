/// A company branch/site (e.g. "Head Office", "Warehouse 2"). Each branch
/// has its own map location + allowed check-in radius, since a company can
/// have several physical locations that each need their own geofence.
class Branch {
  final String id;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  Branch({
    required this.id,
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'radiusMeters': radiusMeters,
      };

  factory Branch.fromJson(Map<String, dynamic> json) => Branch(
        id: json['id'],
        name: json['name'],
        address: json['address'],
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        radiusMeters: (json['radiusMeters'] as num).toDouble(),
      );
}
