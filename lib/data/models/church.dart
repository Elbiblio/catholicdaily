class Church {
  final String id;
  final String name;
  final String address;
  final String? phoneNumber;
  final String? website;
  final double latitude;
  final double longitude;
  final double? distance; // Distance from user in km
  final String? massTimes;
  final String? notes;
  final bool isUserAdded;
  final DateTime? createdAt;

  Church({
    required this.id,
    required this.name,
    required this.address,
    this.phoneNumber,
    this.website,
    required this.latitude,
    required this.longitude,
    this.distance,
    this.massTimes,
    this.notes,
    this.isUserAdded = false,
    this.createdAt,
  });

  factory Church.fromGooglePlaces(Map<String, dynamic> place, {double? userDistance}) {
    final location = place['geometry']?['location'];
    final address = place['formatted_address'] ?? '';
    
    return Church(
      id: place['place_id'] ?? place['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: place['name'] ?? 'Unknown Church',
      address: address,
      phoneNumber: place['formatted_phone_number'],
      website: place['website'],
      latitude: location?['lat']?.toDouble() ?? 0.0,
      longitude: location?['lng']?.toDouble() ?? 0.0,
      distance: userDistance,
      isUserAdded: false,
    );
  }

  factory Church.fromDatabase(Map<String, dynamic> row) {
    return Church(
      id: row['id'] as String,
      name: row['name'] as String,
      address: row['address'] as String,
      phoneNumber: row['phone_number'] as String?,
      website: row['website'] as String?,
      latitude: (row['latitude'] as num).toDouble(),
      longitude: (row['longitude'] as num).toDouble(),
      massTimes: row['mass_times'] as String?,
      notes: row['notes'] as String?,
      isUserAdded: (row['is_user_added'] as int) == 1,
      createdAt: row['created_at'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int)
          : null,
    );
  }

  Map<String, dynamic> toDatabase() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone_number': phoneNumber,
      'website': website,
      'latitude': latitude,
      'longitude': longitude,
      'mass_times': massTimes,
      'notes': notes,
      'is_user_added': isUserAdded ? 1 : 0,
      'created_at': createdAt?.millisecondsSinceEpoch,
    };
  }

  Church copyWith({
    String? id,
    String? name,
    String? address,
    String? phoneNumber,
    String? website,
    double? latitude,
    double? longitude,
    double? distance,
    String? massTimes,
    String? notes,
    bool? isUserAdded,
    DateTime? createdAt,
  }) {
    return Church(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      website: website ?? this.website,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distance: distance ?? this.distance,
      massTimes: massTimes ?? this.massTimes,
      notes: notes ?? this.notes,
      isUserAdded: isUserAdded ?? this.isUserAdded,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get distanceDisplay {
    if (distance == null) return '';
    if (distance! < 1) {
      return '${(distance! * 1000).round()}m';
    }
    return '${distance!.toStringAsFixed(1)}km';
  }

  String get shortAddress {
    final parts = address.split(',');
    if (parts.length <= 2) return address;
    return '${parts[0]}, ${parts[1]}';
  }
}
