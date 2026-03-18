import 'dart:convert';
import 'dart:io';

void main() {
  final path = 'assets/data/readings_rows.json';
  final data = jsonDecode(File(path).readAsStringSync()) as List;
  final interesting = <Map<String,dynamic>>[];
  for (final raw in data) {
    final row = Map<String,dynamic>.from(raw as Map);
    final reading = (row['reading'] ?? '').toString();
    if (reading.contains('Luke 1:67-79') || reading.contains('2 Sam 7:1-5') || reading.contains('Gen 1:1-2:2') || reading.contains('Matt 28:1-10') || reading.contains('Mark 16:1-7') || reading.contains('Luke 24:1-12')) {
      interesting.add(row);
    }
  }
  interesting.sort((a,b) => a['timestamp'].toString().compareTo(b['timestamp'].toString()));
  for (final row in interesting) {
    print(row);
  }
}
