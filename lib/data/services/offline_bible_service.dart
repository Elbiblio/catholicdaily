import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/bible_version.dart';

class OfflineBibleService {
  static const String _versionsUrl = 'https://api.elbiblio.com/dbs/versions.json';

  Future<List<BibleVersion>> fetchAvailableVersions() async {
    try {
      final response = await http.get(Uri.parse(_versionsUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final List<BibleVersion> versions = [];
        
        for (var json in data) {
          final dbName = json['dbFilename'] as String;
          final isDownloaded = await _isVersionDownloaded(dbName);
          
          versions.add(BibleVersion(
            id: json['tableName'],
            name: json['englishName'],
            abbreviation: json['shortName'],
            downloadUrl: json['downloadUrl'],
            isDownloaded: json['preinstalled'] == true || isDownloaded,
          ));
        }
        return versions;
      }
    } catch (e) {
      developer.log('Error fetching Bible versions', error: e, name: 'OfflineBibleService');
    }
    return [];
  }

  Future<bool> _isVersionDownloaded(String dbName) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final file = File(path.join(docsDir.path, dbName));
    return file.exists();
  }

  Future<String?> getDatabasePath(String dbName) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final file = File(path.join(docsDir.path, dbName));
    
    if (await file.exists()) {
      return file.path;
    }
    
    // Check if it's a bundled asset (RSVCE or NABRE)
    if (dbName == 'rsvce.db' || dbName == 'nabre.db') {
      return null; // Signals to use rootBundle / asset logic
    }
    
    return null;
  }

  Future<void> downloadVersion(BibleVersion version, Function(double) onProgress) async {
    if (version.downloadUrl == null) return;

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final dbName = version.downloadUrl!.split('/').last;
      final file = File(path.join(docsDir.path, dbName));

      final request = http.Request('GET', Uri.parse(version.downloadUrl!));
      final response = await http.Client().send(request);
      
      final contentLength = response.contentLength ?? 0;
      int downloadedLength = 0;

      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloadedLength += chunk.length;
        if (contentLength > 0) {
          onProgress(downloadedLength / contentLength);
        }
      }

      await sink.close();
    } catch (e) {
      developer.log('Error downloading Bible version', error: e, name: 'OfflineBibleService');
      throw Exception('Failed to download ${version.name}');
    }
  }

  Future<void> deleteVersion(String dbName) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final file = File(path.join(docsDir.path, dbName));
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      developer.log('Error deleting Bible version', error: e, name: 'OfflineBibleService');
      throw Exception('Failed to delete version');
    }
  }
}
