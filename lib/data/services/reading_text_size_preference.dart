import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ReadingTextSize {
  small(label: 'Small', scale: 0.9),
  standard(label: 'Standard', scale: 1.0),
  comfortable(label: 'Comfortable', scale: 1.15),
  large(label: 'Large', scale: 1.3),
  extraLarge(label: 'Extra large', scale: 1.5);

  const ReadingTextSize({required this.label, required this.scale});

  final String label;
  final double scale;

  String get percentageLabel => '${(scale * 100).round()}%';

  static ReadingTextSize fromStorage(String? value) {
    return ReadingTextSize.values.firstWhere(
      (size) => size.name == value,
      orElse: () => ReadingTextSize.standard,
    );
  }
}

class ReadingTextSizePreference extends ChangeNotifier {
  static const String storageKey = 'reading_text_size';
  static ReadingTextSizePreference? _instance;
  static Future<ReadingTextSizePreference>? _loading;

  ReadingTextSizePreference._(this._preferences)
    : _currentSize = ReadingTextSize.fromStorage(
        _preferences.getString(storageKey),
      );

  final SharedPreferences _preferences;
  ReadingTextSize _currentSize;

  static Future<ReadingTextSizePreference> getInstance() {
    final instance = _instance;
    if (instance != null) return Future.value(instance);
    return _loading ??= _create();
  }

  static Future<ReadingTextSizePreference> _create() async {
    final preferences = await SharedPreferences.getInstance();
    return _instance ??= ReadingTextSizePreference._(preferences);
  }

  @visibleForTesting
  static void resetForTest() {
    _instance = null;
    _loading = null;
  }

  ReadingTextSize get currentSize => _currentSize;
  double get scale => _currentSize.scale;

  Future<void> setSize(ReadingTextSize size) async {
    if (size == _currentSize) return;
    final saved = await _preferences.setString(storageKey, size.name);
    if (!saved) {
      throw StateError('Unable to save the reading text size.');
    }
    _currentSize = size;
    notifyListeners();
  }
}
