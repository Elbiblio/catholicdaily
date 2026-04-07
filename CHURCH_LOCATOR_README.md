# Church Locator Feature

## Overview
The Church Locator feature allows users to find nearby Catholic churches, view their details, and add custom churches that aren't available in the database.

## Features
- **Location-based search**: Automatically finds churches near user's current location
- **Manual church addition**: Users can add churches with details like Mass times, phone numbers, and websites
- **Offline caching**: Churches are cached locally for offline access
- **API integration**: Uses elbiblio_api backend for church data
- **Distance calculation**: Shows distance from user's location to each church
- **Contact integration**: One-tap calling and website access

## Implementation Details

### Files Created/Modified:
- `lib/data/models/church.dart` - Church data model
- `lib/data/services/location_service.dart` - Location permissions and positioning
- `lib/data/services/church_locator_service.dart` - Church search and management service
- `lib/ui/screens/church_locator_screen.dart` - Main UI screen
- `lib/ui/screens/reading_screen.dart` - Updated FAB to open church locator

### API Integration:
The app integrates with `elbiblio_api` at `https://api.elbiblio.com`:

**Endpoints:**
- `GET /churches/nearby?lat={lat}&lng={lng}&radius={radius}` - Find nearby churches
- `POST /churches` - Add a new church
- `DELETE /churches/{id}` - Delete a user-added church

**Request/Response Format:**
```json
{
  "id": "church_id",
  "name": "St. Mary's Catholic Church",
  "address": "123 Main St, City, State",
  "phone_number": "(555) 123-4567",
  "website": "https://stmarys.com",
  "latitude": 40.7128,
  "longitude": -74.0060,
  "mass_times": "Sat 5:00 PM, Sun 8:00 AM, 10:00 AM",
  "notes": "Additional information",
  "is_user_added": 0,
  "created_at": 1640995200000
}
```

### Permissions Required:
**Android:**
- `ACCESS_FINE_LOCATION`
- `ACCESS_COARSE_LOCATION`
- `CALL_PHONE`

**iOS:**
- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`
- `NSLocationAlwaysUsageDescription`

### Database Schema:
```sql
CREATE TABLE churches (
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
);
```

## Usage
1. **Access**: Tap the church icon (🏛️) in the reading screen
2. **Location**: Grant location permissions for automatic church detection
3. **View**: Browse nearby churches with distance, contact info, and Mass times
4. **Add**: Tap the "+" button to add a church manually
5. **Contact**: Tap "Call" or "Website" buttons for quick access

## Backend Setup Notes
To complete the implementation, ensure your `elbiblio_api` has:

1. **Churches endpoint** with geospatial search capabilities
2. **CORS configuration** to allow Flutter app access
3. **Authentication** (if required) - currently not implemented
4. **Data validation** for church submissions
5. **Rate limiting** to prevent abuse

## Future Enhancements
- [ ] Church photos and reviews
- [ ] Mass time notifications
- [ ] Driving directions integration
- [ ] Parish event calendar
- [ ] Confession schedule tracking
- [ ] Adoration chapel information

## Troubleshooting
- **Location not working**: Check app permissions and ensure location services are enabled
- **API errors**: Verify elbiblio_api is accessible and endpoints are configured
- **Empty results**: May need to populate church database or check search radius
