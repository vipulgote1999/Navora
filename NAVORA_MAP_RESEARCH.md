# Navora (TripMesh) — Google Maps-Like UI/UX Research Report
## Free Tools & Flutter Implementation Guide

**Date:** October 2026  
**Purpose:** Replicate Google Maps UI/UX in Flutter using only free/open-source tools

---

## Table of Contents

1. [Google Maps Core UI Features](#1-google-maps-core-ui-features)
2. [Flutter Map UI Libraries & Packages](#2-flutter-map-ui-libraries--packages)
3. [Free Street View Alternatives](#3-free-street-view-alternatives)
4. [Free Traffic Data](#4-free-traffic-data)
5. [Free Transit Data](#5-free-transit-data)
6. [Offline Maps](#6-offline-maps)
7. [Map Styling](#7-map-styling)
8. [Accessibility](#8-accessibility)
9. [Recommended Architecture for Navora](#9-recommended-architecture-for-navora)

---

## 1. Google Maps Core UI Features

### 1.1 What Makes Google Maps Feel Like Google Maps

| Feature | Description | Free Feasibility |
|---------|-------------|-----------------|
| Smooth map gestures | Pinch-to-zoom, pan, rotate, tilt with 60fps | ✅ Fully achievable with flutter_map |
| Bottom sheet with place details | Draggable, snap-to-position sheet with place info | ✅ Flutter `DraggableScrollableSheet` |
| Search bar with autocomplete | Real-time suggestions as you type | ✅ Nominatim + debounced HTTP |
| Navigation UI | Turn-by-turn banner, route overview, ETA | ✅ OSRM + custom Flutter widgets |
| My location button | FAB with accuracy circle, heading indicator | ✅ flutter_map_location_marker |
| Street View | 360° street-level imagery | ⚠️ Mapillary/KartaView (limited coverage) |
| Satellite view toggle | Aerial imagery layer | ✅ Esri World Imagery (free tile server) |
| Traffic overlay | Color-coded road congestion | ⚠️ TomTom free tier (20K requests/month) |
| Transit layers | Bus/train routes and stops | ✅ GTFS data (free, agency-dependent) |

### 1.2 Feature-by-Feature Implementation

#### Smooth Map Gestures
- **flutter_map** handles all gestures natively: pinch-to-zoom, pan, rotate (with `MapOptions.interactionOptions`), tilt (pitch)
- Uses Flutter's gesture arena — no platform views needed
- Performance: 60fps achievable with proper `MapController` usage and `ValueNotifier` pattern for markers

#### Bottom Sheet with Place Details
```dart
// Flutter's built-in DraggableScrollableSheet
DraggableScrollableSheet(
  initialChildSize: 0.3,
  minChildSize: 0.1,
  maxChildSize: 0.9,
  builder: (context, scrollController) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: ListView(
        controller: scrollController,
        children: [/* Place details */],
      ),
    );
  },
)
```

#### Search Bar with Autocomplete
- Use **Nominatim** (OpenStreetMap's free geocoding service)
- Package: `flutter_nominatim` (no API key required)
- Debounce input at 300-500ms to respect Nominatim's usage policy (1 req/sec)
- Alternative: **OpenCage Geocoder** (free tier: 2,500 requests/day)

#### Navigation UI
- **OSRM** (Open Source Routing Machine) — free, open-source, turn-by-turn
- Public demo server: `https://router.project-osrm.org`
- Returns: route geometry (polyline), turn-by-turn instructions, distance, duration
- Custom Flutter widgets for the navigation banner

#### My Location Button with Accuracy Circle
- Package: `flutter_map_location_marker`
- Provides: customizable location marker, accuracy circle, heading sector, FAB to follow location
- Works with `geolocator` package for GPS

#### Street View
- See Section 3 for detailed analysis
- **Mapillary** is the primary option (owned by Meta since 2020)
- **KartaView** is a fully open-source alternative

#### Satellite View
- **Esri World Imagery** — free tile server, no API key required
- URL: `https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}`
- Attribution not legally required for OSM-centered apps

#### Traffic Overlay
- See Section 4 for detailed analysis
- **TomTom Traffic API** — free tier: 20,000 requests/month
- No truly free/open real-time traffic API exists

#### Transit Layers
- See Section 5 for detailed analysis
- **GTFS** feeds — free, publicly available per transit agency
- **OpenTripPlanner** — open-source trip planning engine

---

## 2. Flutter Map UI Libraries & Packages

### 2.1 flutter_map (Recommended Core Library)

**Package:** `flutter_map` (v7.0.2+)  
**Pub.dev:** https://pub.dev/packages/flutter_map  
**License:** BSD-3-Clause  
**Publisher:** Fleaflet (community-maintained)

#### Capabilities
| Feature | Support | Notes |
|---------|---------|-------|
| Markers | ✅ Full | Widget children — any Flutter widget as marker |
| Polylines | ✅ Full | Multi-color, gradient, tap handlers (via plugin) |
| Polygons | ✅ Full | Fill, stroke, labels |
| Circles | ✅ Full | Real radius in meters |
| Tile layers | ✅ Full | Any raster tile server |
| Gestures | ✅ Full | Pinch, pan, rotate, tilt |
| Camera control | ✅ Full | Programmatic move, animate (via plugin) |
| Custom tile providers | ✅ Full | Network, asset, file-based |
| Dark mode | ✅ Built-in | Color filter on tile layer |
| Offline caching | ✅ Built-in (v8.2+) | Automatic long-term caching |
| Vector tiles | ⚠️ Planned | Not yet stable |

#### Limitations
- **No built-in routing/navigation** — must use external API (OSRM, GraphHopper, etc.)
- **No built-in geocoding** — must use Nominatim or other service
- **No built-in location marker** — use `flutter_map_location_marker` plugin
- **No built-in animations** — use `flutter_map_animations` plugin
- **Cannot modify tile content** — raster tiles are images from 3rd-party servers
- **No 3D buildings** — not supported
- **No Street View** — not supported natively

#### Basic Setup
```dart
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

FlutterMap(
  options: MapOptions(
    initialCenter: LatLng(51.5074, -0.1278), // London
    initialZoom: 13,
    maxZoom: 19,
    minZoom: 3,
    interactionOptions: InteractionOptions(
      flags: InteractiveFlag.all, // Enable all gestures
    ),
  ),
  children: [
    TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.navora.app',
      maxZoom: 19,
    ),
    MarkerLayer(
      markers: [
        Marker(
          point: LatLng(51.5074, -0.1278),
          width: 40,
          height: 40,
          child: Icon(Icons.location_pin, color: Colors.red, size: 40),
        ),
      ],
    ),
  ],
)
```

### 2.2 flutter_map Plugin Ecosystem

| Plugin | Purpose | Pub.dev |
|--------|---------|---------|
| `flutter_map_animations` | Animated camera movements | https://pub.dev/packages/flutter_map_animations |
| `flutter_map_location_marker` | My location marker + accuracy circle | https://pub.dev/packages/flutter_map_location_marker |
| `flutter_map_marker_popup` | Popup on marker tap | https://pub.dev/packages/flutter_map_marker_popup |
| `flutter_map_tappable_polyline` | Tap events on polylines | https://pub.dev/packages/flutter_map_tappable_polyline |
| `flutter_map_tile_caching` (FMTC) | Advanced offline tile caching + bulk download | https://pub.dev/packages/flutter_map_tile_caching |
| `latlong2` | LatLng math, distance calculations | https://pub.dev/packages/latlong2 |

### 2.3 Other Map Libraries for Flutter

| Library | Tile Source | API Key | Offline | Styling | Notes |
|---------|-------------|---------|---------|---------|-------|
| **flutter_map** | Any (OSM, Esri, etc.) | ❌ No | ✅ Yes | ⚠️ Tile-dependent | **Recommended** — most flexible |
| `google_maps_flutter` | Google | ✅ Yes | ⚠️ Limited | ✅ JSON styles | Requires billing account |
| `mapbox_maps_flutter` | Mapbox | ✅ Yes | ✅ Excellent | ✅ Full (Studio) | Free tier: 25K mobile MAU |
| `maplibre_gl` | Any vector tiles | ❌ No | ✅ Yes | ✅ Full (GL styles) | Newer, vector-first |
| `flutter_osm_plugin` | OSM | ❌ No | ✅ Yes | ⚠️ Limited | All-in-one OSM solution |

### 2.4 Map Animations and Transitions

**Package:** `flutter_map_animations`

```dart
import 'package:flutter_map_animations/flutter_map_animations.dart';

final animatedMapController = AnimatedMapController(
  vsync: this,
  duration: Duration(milliseconds: 500),
  curve: Curves.easeInOut,
);

FlutterMap(
  mapController: animatedMapController.mapController,
  // ...
)

// Animate to a location
await animatedMapController.animateTo(
  dest: LatLng(51.5074, -0.1278),
  zoom: 15,
  rotation: 0,
);
```

### 2.5 Custom Marker Rendering

flutter_map supports **any Flutter widget** as a marker:

```dart
MarkerLayer(
  markers: [
    Marker(
      point: LatLng(51.5074, -0.1278),
      width: 80,
      height: 80,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: Icon(Icons.restaurant, color: Colors.white),
      ),
    ),
  ],
)
```

**Performance tip:** Use `ValueNotifier<Set<Marker>>` + `ValueListenableBuilder` to avoid rebuilding the entire map when markers change.

---

## 3. Free Street View Alternatives

### 3.1 Mapillary

| Aspect | Details |
|--------|---------|
| **Owner** | Meta (Facebook) since 2020 |
| **Cost** | Free |
| **API Key** | Required (free tier available) |
| **Coverage** | 3+ billion images, 190+ countries |
| **License** | Open licenses (CC BY-SA for imagery) |
| **API** | GraphQL API v4 |
| **Flutter Integration** | Via REST/GraphQL API + custom viewer |

**API Endpoints:**
- Image tiles: `https://tiles.mapillary.com/maps/vtp/mly1_public/2/{z}/{x}/{y}`
- Coverage tiles: Available as vector tiles
- Street-level viewer: MapillaryJS (JavaScript, can be embedded in WebView)

**Implementation Approach:**
1. Register for free API key at https://www.mapillary.com/developer
2. Query GraphQL API for images near a location
3. Display images in a custom panorama viewer (Flutter `photo_view` package)
4. Show coverage as a polyline overlay on flutter_map

**Limitations:**
- Owned by Meta (privacy concerns for some users)
- Coverage is community-driven — sparse in rural/developing areas
- No true 360° panorama support in Flutter (requires custom viewer)
- API rate limits apply

### 3.2 KartaView (OpenStreetCam)

| Aspect | Details |
|--------|---------|
| **Owner** | OpenStreetMap community |
| **Cost** | Free |
| **API Key** | Not required for basic use |
| **Coverage** | Global (community-driven) |
| **License** | Open licenses |
| **Flutter Integration** | Via API + custom viewer |

**Website:** https://kartaview.org

**Limitations:**
- Smaller coverage than Mapillary
- Less polished API
- Community-driven (variable quality)

### 3.3 Other Alternatives

| Service | Cost | Coverage | Notes |
|---------|------|----------|-------|
| **Panoramax** | Free | Growing | Open-source, Wikimedia-backed |
| **Mapillary** | Free | 3B+ images | Best coverage, Meta-owned |
| **KartaView** | Free | Moderate | Fully open-source |
| **Trek View** | Free | Limited | Outdoor/trail focused |

### 3.4 Flutter Implementation Strategy

```dart
// 1. Fetch Mapillary coverage via GraphQL
// 2. Display coverage as polyline on flutter_map
// 3. On tap, fetch nearest image
// 4. Display in photo_view package

import 'package:photo_view/photo_view.dart';

// Street view viewer
PhotoView(
  imageProvider: NetworkImage(imageUrl),
  minScale: PhotoViewComputedScale.contained,
  maxScale: PhotoViewComputedScale.covered * 2,
)
```

**Recommendation:** Use Mapillary for coverage + KartaView as fallback. Implement a custom panorama viewer using `photo_view` or a WebGL-based solution in a WebView.

---

## 4. Free Traffic Data

### 4.1 TomTom Traffic API (Free Tier)

| Aspect | Details |
|--------|---------|
| **Free Tier** | 20,000 requests/month |
| **API Key** | Required (free) |
| **Data Type** | Real-time traffic flow + incidents |
| **Coverage** | Global |
| **Flutter Integration** | REST API + HTTP |

**Endpoints:**
- Traffic Flow: `https://api.tomtom.com/traffic/services/4/flowSegmentData/absolute/10/json`
- Traffic Incidents: `https://api.tomtom.com/traffic/services/4/incidentDetails`

**Limitations:**
- 20K requests/month is limited for production
- No historical traffic on free tier
- Requires API key and attribution

### 4.2 OpenTraffic

| Aspect | Details |
|--------|---------|
| **Status** | ⚠️ Effectively defunct |
| **Notes** | OpenTraffic project was discontinued; no reliable free alternative exists |

### 4.3 Other Options

| Service | Free Tier | Notes |
|---------|-----------|-------|
| **TomTom** | 20K req/month | Best free option |
| **HERE Traffic** | Freemium | Limited free tier |
| **Google Maps** | $200 credit/month | Not truly free |
| **OSM** | No traffic data | OSM doesn't collect real-time traffic |

### 4.4 Implementation Approach

```dart
// Fetch traffic flow from TomTom
final response = await http.get(Uri.parse(
  'https://api.tomtom.com/traffic/services/4/flowSegmentData/absolute/10/json'
  '?key=$TOMTOM_API_KEY&point=$lat,$lon',
));

// Parse and color-code route segments
// Green = free flow, Yellow = moderate, Red = heavy, Dark Red = severe
```

**Recommendation:** Use TomTom free tier for development. For production, consider:
1. Caching traffic data aggressively (refresh every 5 minutes)
2. Using traffic data only on active routes (not whole map)
3. Falling back to no traffic overlay when limit reached

---

## 5. Free Transit Data

### 5.1 GTFS (General Transit Feed Specification)

| Aspect | Details |
|--------|---------|
| **Cost** | Free |
| **Availability** | Per transit agency (varies widely) |
| **Format** | ZIP file with CSV files |
| **Real-time** | GTFS-RT (separate protocol, protobuf) |
| **Flutter Integration** | Parse CSV + display on map |

**Key GTFS Files:**
- `routes.txt` — Transit routes
- `trips.txt` — Trips for each route
- `stop_times.txt` — Stop times for each trip
- `stops.txt` — Transit stops
- `shapes.txt` — Route geometries

**Finding GTFS Feeds:**
- https://transitfeeds.com (aggregator)
- https://mobilitydata.org (Mobility Database)
- Individual transit agency websites

### 5.2 OpenTripPlanner (OTP)

| Aspect | Details |
|--------|---------|
| **Cost** | Free (open-source) |
| **License** | LGPL |
| **Input** | GTFS + OSM data |
| **Output** | REST/GraphQL API for trip planning |
| **Flutter Integration** | HTTP API calls |

**Implementation:**
1. Set up OTP server (Java-based, runs on any cloud)
2. Load GTFS feeds + OSM data
3. Query OTP API from Flutter for trip plans
4. Display routes on flutter_map

**OTP API Endpoints:**
- `otp/routers/{routerId}/plan` — Trip planning
- `otp/routers/{routerId}/index/routes` — Route listing
- `otp/routers/{routerId}/index/stops` — Stop listing

### 5.3 Other Free Transit Tools

| Tool | Purpose | Link |
|------|---------|------|
| **Transitland** | Transit data aggregator | https://transit.land |
| **Transitous** | Free transit routing | https://transitous.org |
| **OneBusAway** | GTFS → REST API | https://onebusaway.org |
| **Trufi App** | Flutter transit app (uses OTP) | Open-source |

### 5.4 Flutter Implementation

```dart
// Parse GTFS data
// Display routes as polylines
PolylineLayer(
  polylines: [
    Polyline(
      points: routePoints,
      color: Colors.blue,
      strokeWidth: 4,
    ),
  ],
)

// Display stops as markers
MarkerLayer(
  markers: stops.map((stop) => Marker(
    point: LatLng(stop.lat, stop.lon),
    child: Icon(Icons.directions_bus, size: 20),
  )).toList(),
)
```

**Recommendation:** Use GTFS for static transit data + OpenTripPlanner for trip planning. Cache GTFS data locally and update periodically.

---

## 6. Offline Maps

### 6.1 MBTiles Format

| Aspect | Details |
|--------|---------|
| **Format** | SQLite database containing map tiles |
| **Standard** | OGC MBTiles specification |
| **Content** | Raster tiles (PNG/JPG) or vector tiles (MVT) |
| **Creation** | TileMill, QGIS, tippecanoe, mb-util |

### 6.2 flutter_map Built-in Caching (v8.2+)

flutter_map now includes **built-in tile caching**:

```dart
TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  tileProvider: NetworkTileProvider(),
  // Built-in caching is automatically enabled on non-web platforms
)
```

**Limitations of built-in caching:**
- No guarantees on tile persistence
- May be cleared by system
- Not suitable for guaranteed offline use

### 6.3 flutter_map_tile_caching (FMTC)

| Aspect | Details |
|--------|---------|
| **Package** | `flutter_map_tile_caching` |
| **License** | GPL (⚠️ copyleft — may affect commercial use) |
| **Features** | Bulk download, import/export, sea tile skipping, rate limiting |
| **Pub.dev** | https://pub.dev/packages/flutter_map_tile_caching |

**Implementation:**
```dart
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

// Download a region for offline use
await FMTCStore('offline_map').downloadArea(
  LatLngBounds(
    LatLng(51.0, -0.5),
    LatLng(52.0, 0.5),
  ),
  minZoom: 10,
  maxZoom: 16,
);

// Use offline tiles
TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  tileProvider: FMTCStore('offline_map').getTileProvider(),
)
```

### 6.4 Downloading OSM Data for Offline Use

**Tools:**
| Tool | Purpose | Output |
|------|---------|--------|
| **Osmium** | Extract OSM data by region | .osm.pbf |
| **Osm2pgsql** | Import OSM into PostGIS | PostgreSQL DB |
| **TileMill** | Generate MBTiles from OSM | .mbtiles |
| **tippecanoe** | Generate vector MBTiles | .mbtiles |

**Workflow:**
1. Download OSM data for your region (Geofabrik: https://download.geofabrik.de)
2. Process with TileMill or tippecanoe to generate MBTiles
3. Bundle MBTiles with app or download on-demand
4. Use with flutter_map's MBTiles support

### 6.5 Offline Map Strategy for Navora

1. **Built-in caching** for automatic tile caching as users browse
2. **FMTC** for explicit offline region downloads (⚠️ GPL license — check compliance)
3. **MBTiles** for pre-packaged offline maps (e.g., city-level bundles)
4. **Sea tile skipping** to reduce download size
5. **Rate limiting** to respect tile server policies

---

## 7. Map Styling

### 7.1 Free Tile Servers (No API Key Required)

| Provider | URL Template | Attribution |
|----------|-------------|-------------|
| **OpenStreetMap** | `https://tile.openstreetmap.org/{z}/{x}/{y}.png` | © OpenStreetMap contributors |
| **Esri World Imagery** | `https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}` | Not required (OSM context) |
| **OpenTopoMap** | `https://a.tile.opentopomap.org/{z}/{x}/{y}.png` | © OpenStreetMap contributors |
| **CartoDB Dark** | `https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png` | © OpenStreetMap, © CARTO |
| **CartoDB Light** | `https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png` | © OpenStreetMap, © CARTO |
| **Stadia Maps** | `https://tiles.stadiamaps.com/tiles/alidade_smooth/{z}/{x}/{y}.png` | Free tier available |

### 7.2 Mapbox GL Free Tier

| Aspect | Details |
|--------|---------|
| **Free Tier** | 25,000 mobile MAU, 50,000 web map loads |
| **API Key** | Required (free) |
| **Styling** | Full control via Mapbox Studio |
| **Flutter Package** | `mapbox_maps_flutter` |
| **Offline** | Excellent (vector tiles) |

**Mapbox Studio:** https://studio.mapbox.com — visual style editor, no code needed

### 7.3 Custom Vector Tile Styling with MapLibre

| Aspect | Details |
|--------|---------|
| **Package** | `maplibre_gl` (Flutter) |
| **Cost** | Free, open-source |
| **Styling** | Full GL style JSON support |
| **Tile Source** | Any vector tile server |

**MapLibre is the open-source fork of Mapbox GL** — no API key required, full styling control.

### 7.4 flutter_map Tile Styling Options

```dart
// Dark mode via color filter
TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  tileProvider: NetworkTileProvider(),
  // Apply color filter for dark mode
  colorFilter: ColorFilter.matrix([
    -0.2, -0.7, -0.1, 0, 255,  // R
    -0.2, -0.7, -0.1, 0, 255,  // G
    -0.2, -0.7, -0.1, 0, 255,  // B
    0, 0, 0, 1, 0,              // A
  ]),
)
```

**Note:** flutter_map cannot style individual map features (roads, buildings, etc.) — that requires vector tiles (MapLibre/Mapbox).

### 7.5 Recommended Styling Approach for Navora

1. **Base map:** CartoDB Dark/Light for built-in dark mode aesthetic
2. **Satellite:** Esri World Imagery (free, no key)
3. **Custom branding:** Use MapLibre GL for full style control
4. **Dark mode:** CartoDB Dark tiles or color filter matrix
5. **Offline:** Pre-styled MBTiles

---

## 8. Accessibility

### 8.1 Flutter Accessibility Framework

Flutter provides first-class accessibility support:

| Feature | Implementation |
|---------|---------------|
| Screen reader | `Semantics` widget, `semanticLabel` |
| Touch targets | Minimum 48x48 dp (Material), 44x44 (iOS) |
| Color contrast | WCAG AA: 4.5:1 normal text, 3:1 large text |
| Keyboard navigation | `Focus` widget, `Shortcuts` |
| Text scaling | `MediaQuery.textScaler` |
| Disable animations | `MediaQuery.disableAnimations` |

### 8.2 Map-Specific Accessibility

```dart
// Wrap map in Semantics
Semantics(
  label: 'Interactive map showing route from A to B',
  hint: 'Double tap to zoom, drag to pan',
  child: FlutterMap(/* ... */),
)

// Accessible markers
Marker(
  point: location,
  child: Semantics(
    label: 'Restaurant: Name, Rating 4.5 stars',
    button: true,
    child: Icon(Icons.restaurant),
  ),
)

// Accessible buttons
FloatingActionButton(
  onPressed: _goToCurrentLocation,
  tooltip: 'Go to current location', // Auto-generates Semantics
  child: Icon(Icons.my_location),
)
```

### 8.3 WCAG Compliance for Maps

| WCAG Criterion | Implementation |
|----------------|---------------|
| 1.1.1 Text Alternatives | Provide text list of places as alternative to map |
| 1.4.1 Use of Color | Don't use color alone — add icons/labels |
| 1.4.3 Contrast | Ensure UI elements meet 4.5:1 contrast |
| 2.1.1 Keyboard | Provide keyboard alternatives for map gestures |
| 2.4.3 Focus Order | Logical tab order for map controls |
| 4.1.2 Name, Role, Value | All interactive elements have accessible names |

### 8.4 Testing Accessibility

```dart
// In widget tests
await expect(
  tester,
  meetsGuideline(textContrast),
);
await expect(
  tester,
  meetsGuideline(androidTapTarget),
);
await expect(
  tester,
  meetsGuideline(labeledTapTarget),
);
```

### 8.5 Recommendations for Navora

1. **Provide text alternative** — list view of places/routes
2. **Accessible markers** — semantic labels with place name, category, rating
3. **Keyboard navigation** — arrow keys to pan, +/- to zoom
4. **Screen reader support** — announce map state changes
5. **High contrast mode** — ensure UI works in high contrast
6. **Reduce motion** — respect `MediaQuery.disableAnimations`

---

## 9. Recommended Architecture for Navora

### 9.1 Recommended Tech Stack

| Component | Recommendation | Alternative |
|-----------|---------------|-------------|
| **Map rendering** | `flutter_map` | `maplibre_gl` (for vector styling) |
| **Map tiles** | CartoDB (dark/light) + Esri (satellite) | OSM standard |
| **Geocoding/Search** | Nominatim (`flutter_nominatim`) | OpenCage (2.5K/day free) |
| **Routing/Navigation** | OSRM (free demo server) | GraphHopper (self-hosted) |
| **Location** | `geolocator` + `flutter_map_location_marker` | — |
| **Animations** | `flutter_map_animations` | — |
| **Offline maps** | Built-in caching + FMTC | MBTiles |
| **Street View** | Mapillary API + `photo_view` | KartaView |
| **Traffic** | TomTom (20K/month free) | — |
| **Transit** | GTFS + OpenTripPlanner | Transitland API |
| **State management** | `Riverpod` or `Bloc` | — |
| **HTTP** | `dio` or `http` | — |

### 9.2 Architecture Diagram

```
┌─────────────────────────────────────────────────┐
│                  Navora App                      │
├─────────────────────────────────────────────────┤
│  UI Layer (Flutter Widgets)                     │
│  ├── MapScreen (flutter_map)                    │
│  ├── SearchBar (Nominatim API)                  │
│  ├── BottomSheet (DraggableScrollableSheet)     │
│  ├── NavigationBanner (custom widget)           │
│  └── LayerToggle (satellite/transit/traffic)   │
├─────────────────────────────────────────────────┤
│  Service Layer                                  │
│  ├── MapService (tile management, caching)      │
│  ├── GeocodingService (Nominatim)               │
│  ├── RoutingService (OSRM)                      │
│  ├── LocationService (geolocator)               │
│  ├── TrafficService (TomTom)                    │
│  ├── TransitService (GTFS/OTP)                  │
│  └── StreetViewService (Mapillary)              │
├─────────────────────────────────────────────────┤
│  Data Layer                                     │
│  ├── Tile Cache (flutter_map built-in + FMTC)   │
│  ├── GTFS Cache (local SQLite)                  │
│  └── Route Cache (temporary)                    │
└─────────────────────────────────────────────────┘
```

### 9.3 Implementation Priority

| Phase | Features | Effort |
|-------|----------|--------|
| **Phase 1** | Map display, markers, basic gestures, my location | 1-2 weeks |
| **Phase 2** | Search with autocomplete, place details bottom sheet | 1-2 weeks |
| **Phase 3** | Routing with OSRM, turn-by-turn navigation UI | 2-3 weeks |
| **Phase 4** | Satellite view, custom styling, dark mode | 1 week |
| **Phase 5** | Offline maps, tile caching | 1-2 weeks |
| **Phase 6** | Street View (Mapillary), traffic overlay | 2-3 weeks |
| **Phase 7** | Transit layers (GTFS), accessibility | 2-3 weeks |

### 9.4 Key Packages Summary

```yaml
dependencies:
  # Core map
  flutter_map: ^7.0.2
  latlong2: ^0.9.0
  
  # Map plugins
  flutter_map_animations: ^0.8.0
  flutter_map_location_marker: ^8.0.0
  flutter_map_marker_popup: ^6.0.0
  flutter_map_tappable_polyline: ^4.0.0
  flutter_map_tile_caching: ^10.1.1  # GPL license!
  
  # Location
  geolocator: ^13.0.0
  
  # Geocoding
  flutter_nominatim: ^0.0.1  # Or use http directly
  
  # Routing
  osrm: ^1.0.0  # Or use http directly
  
  # Street View
  photo_view: ^0.15.0
  
  # HTTP
  dio: ^5.4.0
  
  # State management
  flutter_riverpod: ^2.5.0
```

### 9.5 Cost Summary

| Service | Cost | Monthly Limit |
|---------|------|---------------|
| OpenStreetMap tiles | Free | None (respect usage policy) |
| CartoDB tiles | Free | None |
| Esri World Imagery | Free | None |
| Nominatim geocoding | Free | 1 req/sec |
| OSRM routing | Free | None (demo server) |
| TomTom traffic | Free | 20,000 requests |
| Mapillary API | Free | Rate-limited |
| GTFS data | Free | N/A |
| **Total** | **$0** | — |

---

## Conclusion

It is **entirely feasible** to build a Google Maps-like experience in Flutter using only free tools. The key trade-offs are:

1. **Map data quality** — OSM is good but not as comprehensive as Google
2. **Traffic data** — TomTom free tier is limited (20K/month)
3. **Street View** — Mapillary coverage is community-driven and sparse in some areas
4. **Transit data** — GTFS availability varies by city/agency
5. **Routing** — OSRM is excellent but requires self-hosting for production scale

The recommended stack (`flutter_map` + Nominatim + OSRM + CartoDB/Esri tiles) provides a solid foundation with zero cost. As Navora grows, consider self-hosting OSRM and using MapLibre GL for advanced vector styling.

---

*Report generated for Navora (TripMesh) — October 2026*
