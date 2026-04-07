# Gospel Acclamation Display Fix - Summary

## Problem
Gospel Acclamations were showing as duplicate 'Responsorial Psalm' or Psalm Alternative in the app.

## Root Cause Analysis

### Data Structure
- Gospel Acclamations are stored as a **field** (`gospelAcclamation`) on the Gospel reading object, NOT as a separate reading entry
- Psalm Responses are stored as a **field** (`psalmResponse`) on Psalm reading objects
- Position labels like "Alleluia Psalm", "Responsorial Psalm", "Gospel" are used to identify the type of reading

### The Bug
In `reading_detail_screen.dart`, the display logic used imprecise string matching on position labels:
```dart
final isPsalm = (reading.position?.toLowerCase() ?? '').contains('psalm');
final isGospel = (reading.position?.toLowerCase() ?? '').contains('gospel');
```

This caused issues:
1. "Alleluia Psalm" contains "psalm" → triggered PsalmResponseWidget even when it should show GospelAcclamationWidget
2. Position label matching is imprecise and can misclassify readings
3. The logic didn't check if the actual data fields had values

### Secondary Issue
In `reading_title_formatter.dart`, "Alleluia Psalm" positions were being mislabeled as "Responsorial Psalm" due to the `shortBook == 'Ps'` check taking precedence before checking for the specific "alleluia psalm" label.

## Fixes Applied

### 1. reading_detail_screen.dart (Lines 28-29, 115-130)
**Changed from position label matching to field-based checking:**
```dart
// Before (WRONG)
final isPsalm = (reading.position?.toLowerCase() ?? '').contains('psalm');
final isGospel = (reading.position?.toLowerCase() ?? '').contains('gospel');

if (isPsalm) ...[
  PsalmResponseWidget(...),
],
if (isGospel) ...[
  GospelAcclamationWidget(...),
],

// After (CORRECT)
final hasPsalmResponse = reading.psalmResponse != null && reading.psalmResponse!.trim().isNotEmpty;
final hasGospelAcclamation = reading.gospelAcclamation != null && reading.gospelAcclamation!.trim().isNotEmpty;

if (hasPsalmResponse) ...[
  PsalmResponseWidget(...),
],
if (hasGospelAcclamation) ...[
  GospelAcclamationWidget(...),
],
```

### 2. reading_title_formatter.dart (Lines 13-19)
**Added explicit handling for "Alleluia Psalm" before generic Psalm check:**
```dart
// Check for alleluia psalm BEFORE generic psalm check
if (positionLabel == 'alleluia psalm' || positionLabel == 'alleluia psalm (alternative)') {
  return positionLabel.contains('(alternative)') ? 'Alleluia Psalm (Alternative)' : 'Alleluia Psalm';
}

if (positionLabel == 'responsorial psalm' || positionLabel == 'responsorial psalm (alternative)' || shortBook == 'Ps') {
  return positionLabel.contains('(alternative)') ? 'Responsorial Psalm (Alternative)' : 'Responsorial Psalm';
}
```

## Verification

### reading_screen.dart
Already correctly uses field-based checking (lines 591-604):
```dart
if (widget.readingData?.psalmResponse != null)
  PsalmResponseWidget(...),
if (widget.readingData?.gospelAcclamation != null)
  GospelAcclamationWidget(...),
```

### Data Services
Position label matching in services (psalm_resolver_service.dart, csv_readings_resolver_service.dart, etc.) is appropriate for:
- Resolving missing data
- Filtering entries
- Determining reading types for navigation

These are NOT display logic and should continue using position labels.

## Data Flow

1. **CSV/Standard Lectionary Sources** → `csv_readings_resolver_service.dart`
   - Creates DailyReading objects with `gospelAcclamation` field set on Gospel readings
   - Creates DailyReading objects with `psalmResponse` field set on Psalm readings
   - Uses position labels like "Gospel", "Responsorial Psalm", "Alleluia Psalm"

2. **Display Layer** → UI Screens
   - `reading_screen.dart`: Checks field values to show widgets ✓
   - `reading_detail_screen.dart`: NOW checks field values to show widgets ✓ (FIXED)
   - `reading_title_formatter.dart`: NOW correctly labels "Alleluia Psalm" ✓ (FIXED)

## Key Principle

**Display widgets should be based on data field presence, not position label string matching.**

- Gospel Acclamation Widget → Show when `gospelAcclamation` field has value
- Psalm Response Widget → Show when `psalmResponse` field has value
- Position labels → Used for title formatting and data service logic, NOT widget display

## Affected Files
- `lib/ui/screens/reading_detail_screen.dart` - Fixed widget display logic
- `lib/ui/utils/reading_title_formatter.dart` - Fixed position label formatting

## No Changes Needed
- `lib/ui/screens/reading_screen.dart` - Already correct
- `lib/ui/widgets/gospel_acclamation_widget.dart` - Widget logic is correct
- `lib/ui/widgets/psalm_response_widget.dart` - Widget logic is correct
- Data services - Position label matching is appropriate for their use cases
