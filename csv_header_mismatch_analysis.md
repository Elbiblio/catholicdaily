# CSV Header Mismatch Analysis

## Problem Identified

There are significant structural differences between `memorial_feasts.csv` and `standard_lectionary_complete.csv` that affect how incipits are processed.

## Header Comparison

### memorial_feasts.csv (21 columns)
```
id,title,rank,color,month,day,dateRule,commonType,
firstReading,alternativeFirstReading,firstReadingIncipit,alternativeFirstReadingIncipit,
psalmReference,psalmResponse,
secondReading,secondReadingIncipit,
gospel,gospelIncipit,alternativeGospel,alternativeGospelIncipit,gospelAcclamation
```

### standard_lectionary_complete.csv (21+ columns)
```
season,week,day,weekday_cycle,sunday_cycle,reading_cycle,
first_reading,second_reading,
psalm_reference,psalm_response,
gospel,acclamation_ref,acclamation_text,
lectionary_number,first_reading_incipit,gospel_incipit,
source_file,source_page,source_title,reference_status,parser_warnings
```

## Key Differences

### 1. **Purpose & Structure**
- **memorial_feasts.csv**: Fixed calendar feasts (saints' days, solemnities)
- **standard_lectionary_complete.csv**: Sunday/weekday cycles (A, B, C years)

### 2. **Column Naming Convention**
| Memorial Feasts | Standard Lectionary | Purpose |
|-----------------|-------------------|---------|
| `firstReading` | `first_reading` | First reading reference |
| `firstReadingIncipit` | `first_reading_incipit` | First reading incipit |
| `gospel` | `gospel` | Gospel reference |
| `gospelIncipit` | `gospel_incipit` | Gospel incipit |
| `psalmReference` | `psalm_reference` | Psalm reference |
| `psalmResponse` | `psalm_response` | Psalm response |

### 3. **Unique Columns**

#### Memorial Feasts Only:
- `id`, `title`, `rank`, `color`, `month`, `day`, `dateRule`, `commonType`
- `alternativeFirstReading`, `alternativeFirstReadingIncipit`
- `alternativeGospel`, `alternativeGospelIncipit`, `gospelAcclamation`

#### Standard Lectionary Only:
- `season`, `week`, `day`, `weekday_cycle`, `sunday_cycle`, `reading_cycle`
- `acclamation_ref`, `acclamation_text`, `lectionary_number`
- `source_file`, `source_page`, `source_title`, `reference_status`, `parser_warnings`

## Loading Code Analysis

### Memorial Feasts Loading
```dart
// Expected: 22 columns minimum
if (columns.length < 22) continue;

firstReadingIncipit: columns[10].trim(),     // Column 10
gospelIncipit: columns[17].trim(),           // Column 17
```

### Standard Lectionary Loading  
```dart
// Expected: 14 columns minimum
if (columns.length < 14) continue;

firstReadingIncipit: columns.length > 14 ? columns[14].trim() : '',
gospelIncipit: columns.length > 15 ? columns[15].trim() : '',
```

## Issues Identified

### 1. **Inconsistent Incipit Availability**
- **Memorial Feasts**: Many entries have empty incipit columns
- **Standard Lectionary**: More consistent incipit coverage

### 2. **Alternative Readings Handling**
- **Memorial Feasts**: Supports alternative first/gospel readings
- **Standard Lectionary**: No alternative readings structure

### 3. **Data Validation**
- **Memorial Feasts**: Fixed 22-column requirement
- **Standard Lectionary**: Flexible 14+ column requirement with optional incipits

## Usage in App

### Primary Usage Flow
1. **Date-based lookup** → `standard_lectionary_complete.csv` (Sunday/weekday cycles)
2. **Feast day lookup** → `memorial_feasts.csv` (Saints' feast days)
3. **Fallback** → Generate incipits via `IncipitProcessingService`

### Service Integration
Both files feed into the same `IncipitProcessingService.process()` method:
```dart
final processed = _incipitService.process(
  reference,
  fullText,
  csvIncipit: incipit,  // From either CSV file
);
```

## Recommendations

### 1. **Standardize Column Naming**
Consider standardizing to snake_case for consistency:
- `firstReading` → `first_reading`
- `gospelIncipit` → `gospel_incipit`
- etc.

### 2. **Improve Data Validation**
Add better validation for missing incipits:
```dart
// Check for empty or placeholder values
if (csvIncipit?.isEmpty ?? true) {
  // Generate derived incipit
}
```

### 3. **Unified Data Model**
Consider creating a unified interface for both CSV types to handle:
- Consistent incipit extraction
- Alternative readings
- Validation rules

### 4. **Data Quality Audit**
- Audit memorial_feasts.csv for missing incipits
- Cross-reference with standard_lectionary_complete.csv
- Fill gaps using derived incipits

## Impact on Current Implementation

The current implementation correctly handles both CSV formats, but the header mismatch creates:
- **Maintenance complexity** (different column indices)
- **Data inconsistency** (varying incipit coverage)
- **Potential for errors** (column index misalignment)

The app works despite this mismatch, but standardizing would improve maintainability and data quality.
