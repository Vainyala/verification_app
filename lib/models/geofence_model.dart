enum GeofenceType { home, office, client }

class GeofenceModel {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radius;
  final GeofenceType type;
  final bool isActive;
  final DateTime createdAt;

  GeofenceModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.type,
    required this.isActive,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'type': type.index,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory GeofenceModel.fromJson(Map<String, dynamic> json) {
    return GeofenceModel(
      id: json['id'],
      name: json['name'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      radius: json['radius'],
      type: GeofenceType.values[json['type']],
      isActive: json['isActive'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  GeofenceModel copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    double? radius,
    GeofenceType? type,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return GeofenceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radius: radius ?? this.radius,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}