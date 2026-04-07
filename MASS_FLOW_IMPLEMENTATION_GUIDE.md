# Mass Flow Implementation Guide

## Overview

This document explains the complete functional Mass structure implementation that allows users to follow the entire Mass from beginning to end, integrated with the liturgical calendar.

## What Was Implemented

### 1. Complete Mass Structure (order_of_mass.json)

Expanded from 7 items to 30+ items covering the entire Mass:

**Introductory Rites**
- Sign of the Cross
- Greeting (dialogue)
- Penitential Act (Confiteor or Have Mercy - alternatives)
- Kyrie Eleison
- Gloria (with seasonal conditions)
- Collect (variable from calendar)

**Liturgy of the Word**
- First Reading (variable from readings)
- Responsorial Psalm (variable from readings, responsive)
- Second Reading (variable from readings, Sundays/solemnities only)
- Gospel Acclamation (variable from readings)
- Gospel (variable from readings, with dialogue)
- Creed (Sundays/solemnities only)
- Prayer of the Faithful (variable from calendar, responsive)

**Liturgy of the Eucharist**
- Presentation of the Gifts (dialogue)
- Prayer over the Offerings (variable from calendar)
- Preface Dialogue (dialogue)
- Preface (variable from calendar)
- Sanctus
- Mystery of Faith Acclamation (dialogue)
- Final Doxology (dialogue)
- Our Father
- Embolism (dialogue)
- Sign of Peace (dialogue)
- Lamb of God
- Communion Invitation (dialogue)
- Communion Antiphon (variable from calendar)
- Prayer after Communion (variable from calendar)

**Concluding Rites**
- Final Blessing (dialogue)
- Dismissal (dialogue)

### 2. Enhanced Data Models

**OrderOfMassItem** - Added fields:
- `type`: "fixed" or "variable"
- `source`: "liturgical_calendar" or "readings"
- `sourceField`: Field name in source data
- `role`: Who speaks (priest, deacon, lector, cantor, choir, all)
- `isDialogue`: True for priest/people exchanges
- `isResponsive`: True for congregational responses
- `alternativeGroup`: For alternative forms (e.g., penitential act options)

**ResolvedOrderOfMassItem** - Same fields passed through for UI use

### 3. Enhanced OrderOfMassService

**New Insertion Points** (15 total):
- introductory_rites
- before_first_reading
- between_readings
- before_gospel
- after_gospel
- offertory
- preface
- sanctus
- acclamation
- lords_prayer
- sign_of_peace
- fraction
- communion
- after_communion
- concluding_rites

**New Condition Logic** (AND-based):
- `always`: Always shown
- `sunday_only`: Only on Sundays
- `solemnity`: Only on solemnities
- `sunday_or_solemnity`: Sundays or solemnities
- `not_advent`: Not during Advent
- `not_lent`: Not during Lent
- `lent`: Only during Lent
- `easter_vigil`: Only on Easter Vigil

**Variable Item Handling**: Items marked as `type: "variable"` are resolved as placeholders that will be populated from external data sources (liturgical calendar or readings service).

## How to Use

### For Displaying Mass Flow

The `OrderOfMassService.getSectionsForDate(date)` method returns a list of sections with items. Each section corresponds to a part of the Mass:

```dart
final service = OrderOfMassService();
final sections = await service.getSectionsForDate(DateTime.now());

for (final section in sections) {
  print('Section: ${section.title}');
  for (final item in section.items) {
    print('  - ${item.title}');
    print('    Role: ${item.role}');
    print('    Dialogue: ${item.isDialogue}');
    print('    Responsive: ${item.isResponsive}');
  }
}
```

### For Displaying Dialogue

Items with `isDialogue: true` have alternating priest/people lines. The content is structured as an array where:
- Even indices (0, 2, 4...): Priest/deacon speaks
- Odd indices (1, 3, 5...): People respond

```dart
if (item.isDialogue) {
  final content = item.contentByLanguage[languageCode]!;
  for (var i = 0; i < content.length; i++) {
    final speaker = i % 2 == 0 ? 'Priest' : 'People';
    print('$speaker: ${content[i]}');
  }
}
```

### For Variable Items

Items with `type: "variable"` need to be populated from external sources:

```dart
if (item.type == 'variable') {
  if (item.source == 'readings') {
    // Fetch from readings service based on sourceField
    final reading = await readingsService.getReading(item.sourceField, date);
    // Update item content with reading data
  } else if (item.source == 'liturgical_calendar') {
    // Fetch from calendar service based on sourceField
    final prayer = await calendarService.getPrayer(item.sourceField, date);
    // Update item content with prayer data
  }
}
```

### For Alternative Groups

Items with the same `alternativeGroup` are alternatives (e.g., Confiteor vs Have Mercy for penitential act). The UI should allow users to choose which alternative to display.

### For Responsive Items

Items with `isResponsive: true` (e.g., Responsorial Psalm, Prayer of the Faithful) have a call-and-response structure. The UI should highlight the response portions.

## Integration with Existing Reading Screen

The existing `reading_screen.dart` already has navigation support through `navigableItems`. To integrate the complete Mass flow:

1. **Extend NavigableItem model** to include order of mass items
2. **Update ReadingFlowService** to generate navigable items from OrderOfMassService sections
3. **Update ReadingScreen** to display dialogue format and role indicators
4. **Add data fetching** for variable items from calendar/readings services

## Data Source Requirements

### Liturgical Calendar Service

Must provide the following fields for variable items:
- `collect`: Collect prayer text
- `prayers_of_the_faithful`: Universal prayer intentions
- `prayer_over_offerings`: Prayer over the offerings
- `preface`: Preface text
- `communion_antiphon`: Communion antiphon
- `prayer_after_communion`: Post-communion prayer

### Readings Service

Must provide the following fields:
- `first_reading`: First reading text and reference
- `psalm`: Responsorial psalm with response
- `second_reading`: Second reading text and reference
- `gospel_acclamation`: Gospel acclamation verse
- `gospel`: Gospel reading text and reference

## Seasonal Behavior

The condition logic automatically handles seasonal variations:

- **Gloria**: Shown on Sundays/solemnities, omitted during Advent and Lent
- **Creed**: Shown on Sundays/solemnities
- **Second Reading**: Shown on Sundays/solemnities only
- **Penitential Act**: Always shown (Confiteor or Have Mercy alternatives)

## Next Steps

1. **Implement data fetching** for variable items from calendar and readings services
2. **Create UI components** for dialogue display with role indicators
3. **Add alternative selection** UI for items with alternativeGroup
4. **Test with various dates** to verify condition logic works correctly
5. **Add language switching** support for all dialogue items
6. **Create a dedicated Mass flow screen** or integrate into existing reading screen

## Testing

Test with these scenarios:
- Sunday in Ordinary Time (Gloria, Creed, Second Reading should show)
- Sunday in Advent (Gloria should NOT show, Creed should show)
- Sunday in Lent (Gloria should NOT show, Creed should show)
- Weekday in Ordinary Time (Gloria, Creed, Second Reading should NOT show)
- Solemnity (Gloria, Creed, Second Reading should show regardless of season)
- Easter Vigil (special condition)
