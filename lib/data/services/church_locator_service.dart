import 'package:http/http.dart' as http;
import '../models/church.dart';
import 'location_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class ChurchLocatorService {
  static const String _baseUrl = 'https://api.elbiblio.com'; // Your API base URL
  static const String _tableName = 'churches';
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'churches.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute('''
          CREATE TABLE $_tableName (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            address TEXT NOT NULL,
            phone_number TEXT,
            website TEXT,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            mass_times TEXT,
            notes TEXT,
            is_user_added INTEGER DEFAULT 0,
            created_at INTEGER
          )
        ''');
      },
    );
  }

  Future<List<Church>> findNearbyChurches({
    double? userLatitude,
    double? userLongitude,
    double radius = 10.0, // 10km radius
  }) async {
    // Get user location if not provided
    if (userLatitude == null || userLongitude == null) {
      final position = await LocationService.getCurrentLocation();
      if (position != null) {
        userLatitude = position.latitude;
        userLongitude = position.longitude;
      } else {
        throw Exception('Could not get user location');
      }
    }

    final List<Church> allChurches = [];

    try {
      // Search elbiblio API for nearby churches
      final response = await http.get(
        Uri.parse('$_baseUrl/churches/nearby?lat=$userLatitude&lng=$userLongitude&radius=$radius'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        for (final churchData in data) {
          final church = Church.fromDatabase({
            'id': churchData['id']?.toString() ?? '',
            'name': churchData['name'] ?? '',
            'address': churchData['address'] ?? '',
            'phone_number': churchData['phone_number'],
            'website': churchData['website'],
            'latitude': churchData['latitude']?.toDouble() ?? 0.0,
            'longitude': churchData['longitude']?.toDouble() ?? 0.0,
            'mass_times': churchData['mass_times'],
            'notes': churchData['notes'],
            'is_user_added': churchData['is_user_added'] ?? 0,
            'created_at': churchData['created_at'],
          });

          // Calculate distance from user
          final distance = LocationService.calculateDistance(
            userLatitude,
            userLongitude,
            church.latitude,
            church.longitude,
          );

          allChurches.add(church.copyWith(distance: distance));
        }
      }
    } catch (e) {
      // If API fails, continue with cached churches only
      print('elbiblio API error: $e');
    }

    // Get cached churches from database
    final cachedChurches = await _getCachedChurches(
      userLatitude,
      userLongitude,
      radius,
    );

    // Merge results, avoiding duplicates
    final Map<String, Church> mergedChurches = {};
    for (final church in allChurches) {
      mergedChurches[church.id] = church;
    }
    for (final church in cachedChurches) {
      if (!mergedChurches.containsKey(church.id)) {
        mergedChurches[church.id] = church;
      }
    }

    // Sort by distance
    final churchList = mergedChurches.values.toList();
    churchList.sort((a, b) {
      if (a.distance == null && b.distance == null) return 0;
      if (a.distance == null) return 1;
      if (b.distance == null) return -1;
      return a.distance!.compareTo(b.distance!);
    });

    // Cache the results
    await _cacheChurches(churchList);

    return churchList;
  }

  Future<List<Church>> _getCachedChurches(
    double userLatitude,
    double userLongitude,
    double radius,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(_tableName);

    final churches = <Church>[];
    for (final map in maps) {
      final church = Church.fromDatabase(map);
      final distance = LocationService.calculateDistance(
        userLatitude,
        userLongitude,
        church.latitude,
        church.longitude,
      );

      if (distance <= radius) {
        churches.add(church.copyWith(distance: distance));
      }
    }

    return churches;
  }

  Future<void> _cacheChurches(List<Church> churches) async {
    final db = await database;
    final batch = db.batch();

    for (final church in churches) {
      batch.insert(
        _tableName,
        church.toDatabase(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<Church> addCustomChurch({
    required String name,
    required String address,
    String? phoneNumber,
    String? website,
    required double latitude,
    required double longitude,
    String? massTimes,
    String? notes,
  }) async {
    var church = Church(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      address: address,
      phoneNumber: phoneNumber,
      website: website,
      latitude: latitude,
      longitude: longitude,
      massTimes: massTimes,
      notes: notes,
      isUserAdded: true,
      createdAt: DateTime.now(),
    );

    // Submit to elbiblio API
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/churches'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          'address': address,
          'phone_number': phoneNumber,
          'website': website,
          'latitude': latitude,
          'longitude': longitude,
          'mass_times': massTimes,
          'notes': notes,
        }),
      );

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        // Update church ID with server-generated ID
        church = church.copyWith(id: responseData['id'].toString());
      }
    } catch (e) {
      print('Failed to submit church to API: $e');
      // Continue with local storage even if API fails
    }

    // Store locally regardless of API success
    final db = await database;
    await db.insert(
      _tableName,
      church.toDatabase(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return church;
  }

  Future<void> deleteCustomChurch(String churchId) async {
    // Delete from elbiblio API if it's a user-added church
    try {
      await http.delete(
        Uri.parse('$_baseUrl/churches/$churchId'),
        headers: {'Content-Type': 'application/json'},
      );
      // API response doesn't need to be successful for local deletion
    } catch (e) {
      print('Failed to delete church from API: $e');
    }

    // Delete from local database
    final db = await database;
    await db.delete(
      _tableName,
      where: 'id = ? AND is_user_added = 1',
      whereArgs: [churchId],
    );
  }

  Future<List<Church>> getUserAddedChurches() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'is_user_added = 1',
      orderBy: 'created_at DESC',
    );

    return maps.map((map) => Church.fromDatabase(map)).toList();
  }

  Future<Church?> getChurchById(String churchId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [churchId],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return Church.fromDatabase(maps.first);
    }

    return null;
  }

  Future<void> updateChurch(Church church) async {
    final db = await database;
    await db.update(
      _tableName,
      church.toDatabase(),
      where: 'id = ?',
      whereArgs: [church.id],
    );
  }

  Future<void> clearCache() async {
    final db = await database;
    await db.delete(_tableName, where: 'is_user_added = 0');
  }
}
