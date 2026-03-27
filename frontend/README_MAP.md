# 🗺️ City Explorer — Maintainability Guide

## Architecture

The City Explorer uses a **static hub model** — no Google Maps API key required. Cities are hardcoded constants with fixed coordinates.

```
lib/
├── config/
│   └── city_hubs.dart        ← City data (coordinates, names, icons)
└── screens/
    └── explore/
        └── city_explorer_screen.dart  ← UI + SearchProvider integration
```

## How to Add a New City

### Step 1: Get Coordinates
Search the city on [Google Maps](https://maps.google.com), right-click → "What's here?" to get lat/lng.

### Step 2: Add to `city_hubs.dart`

```dart
const List<CityHub> kyrgyzstanHubs = [
  // ... existing cities ...
  CityHub(
    name: 'NewCity',           // English name (used in API ?city= filter)
    nameRu: 'НовыйГород',     // Russian name (shown when locale is 'ru')
    latitude: 42.1234,         // From Google Maps
    longitude: 74.5678,        // From Google Maps
    icon: Icons.location_city, // Any Material icon
    region: 'RegionName',      // Oblast/province label
  ),
];
```

### Step 3: Done
No route changes, no screen changes, no backend changes. The `GridView.builder` auto-renders all hubs from the list.

## How It Works

1. User taps a city card → `HapticFeedback.lightImpact()` fires
2. Glassmorphism bottom card slides up with city info
3. User taps "View Listings" → `SearchProvider.performSearch({city: 'CityName'})` is called
4. Navigator pops back to Home, Search tab now shows filtered results

## 2GIS Integration (Listing Detail)

The `_openInMaps(city)` method in `listing_detail_screen.dart`:
1. Tries `dgis://` deep link (opens 2GIS app if installed)
2. Falls back to `https://google.com/maps/search/...`
3. Shows a SnackBar error if both fail

## Dependencies

| Package | Purpose |
|---------|---------|
| `url_launcher` | 2GIS/Google Maps deep linking |
| `flutter/services.dart` | HapticFeedback for premium feel |

No `google_maps_flutter` or `geolocator` needed for this implementation.
