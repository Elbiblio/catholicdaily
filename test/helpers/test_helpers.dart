import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

/// Sets up Flutter test environment with SQLite FFI
void setupFlutterTestEnvironment() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

/// Mocks method channels commonly needed in tests
/// Returns cleanup function to remove mocks
void Function() mockMethodChannels({String? tempDocsPath}) {
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  const sharedPreferencesChannel = MethodChannel('plugins.flutter.io/shared_preferences');
  
  // Set up mocks
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(pathProviderChannel, (call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return tempDocsPath ?? Directory.systemTemp.path;
        }
        return null;
      });
      
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(sharedPreferencesChannel, (call) async {
        if (call.method == 'getAll') {
          return <String, Object>{};
        }
        return true;
      });
  
  // Return cleanup function
  return () {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(sharedPreferencesChannel, null);
  };
}

/// Creates a temporary directory for test files
/// Returns cleanup function to remove directory
Future<Directory> createTempTestDir(String prefix) async {
  final tempDir = Directory.systemTemp.createTempSync(prefix);
  
  return tempDir;
}

/// Helper to safely cleanup temp directory
void cleanupTempDir(Directory dir) {
  try {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  } catch (_) {
    // Ignore cleanup errors
  }
}
