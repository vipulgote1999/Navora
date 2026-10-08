# Free Routing & Navigation APIs Research Report

**Project:** Navora (TripMesh) — Flutter App  
**Date:** October 2026  
**Purpose:** Evaluate free alternatives to Google Maps Directions API

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [OSRM (Open Source Routing Machine)](#1-osrm-open-source-routing-machine)
3. [Valhalla](#2-valhalla)
4. [GraphHopper](#3-graphhopper)
5. [OpenRouteService](#4-openrouteservice)
6. [Free Routing APIs with No API Key Required](#5-free-routing-apis-with-no-api-key-required)
7. [Self-Hosting Routing Engines](#6-self-hosting-routing-engines)
8. [Turn-by-Turn Navigation](#7-turn-by-turn-navigation)
9. [Real-Time Traffic](#8-real-time-traffic)
10. [Alternative Routes](#9-alternative-routes)
11. [Flutter Integration](#10-flutter-integration)
12. [Comparison Matrix](#comparison-matrix)
13. [Recommendations](#recommendations)

---

## Executive Summary

| Service | API Key | Free Tier | Turn-by-Turn | Alternatives | Self-Host | Best For |
|---------|---------|-----------|-------------|-------------|-----------|----------|
| **OSRM Demo** | None | ~1 req/sec | Good (maneuver types) | Yes (up to N) | Yes | Light use, prototyping |
| **Valhalla Demo** | None | Fair use | Excellent (narrative + voice) | Yes (up to 3) | Yes | Best turn-by-turn quality |
| **GraphHopper** | Required | 500 credits/day | Good | Yes | Yes (open source) | Flexible routing, custom models |
| **OpenRouteService** | Required | 2000 directions/day | Good | Yes (up to 3) | Yes | Generous free tier, many profiles |

**Key Finding:** For a production Flutter app, the best approach is a **hybrid strategy**: use the free FOSSGIS-hosted OSRM/Valhalla servers for development and light production use, with the option to self-host as you scale. Valhalla provides the best turn-by-turn narrative instructions and voice guidance support.

---

## 1. OSRM (Open Source Routing Machine)

### Overview
OSRM is the most mature open-source routing engine, originally developed by the OpenStreetMap community. It is written in C++ and uses OpenStreetMap data. The project is actively maintained (v5.27.1 as of 2025).

### Public Demo Servers

| Server | URL | Profiles | Rate Limit |
|--------|-----|----------|------------|
| **FOSSGIS (Primary)** | `https://routing.openstreetmap.de` | car, bike, foot | ~1 req/sec |
| **Project OSRM** | `https://router.project-osrm.org` | car (default) | ~1 req/sec |

**Important:** The FOSSGIS server uses path prefixes to select profiles:
- `https://routing.openstreetmap.de/routed-car/...`
- `https://routing.openstreetmap.de/routed-bike/...`
- `https://routing.openstreetmap.de/routed-foot/...`

The `router.project-osrm.org` server ignores the profile segment in the URL and always returns car routes.

### API Key Required
**None** — completely open for reasonable, non-commercial use.

### API Endpoint Format

```
GET /route/v1/{profile}/{coordinates}?alternatives={n}&steps={true|false}&geometries={polyline|polyline6|geojson}&overview={full|simplified|false}&annotations={true|false}
```

**Example:**
```
https://routing.openstreetmap.de/routed-car/route/v1/driving/13.388860,52.517037;13.397634,52.529407?steps=true&alternatives=3&geometries=polyline6&overview=full
```

### Available Services
| Service | Endpoint | Description |
|---------|----------|-------------|
| Route | `/route/v1/{profile}/{coords}` | Turn-by-turn routing |
| Table | `/table/v1/{profile}/{coords}` | Distance/time matrix |
| Match | `/match/v1/{profile}/{coords}` | Map matching (snap GPS to roads) |
| Trip | `/trip/v1/{profile}/{coords}` | Traveling Salesman optimization |
| Nearest | `/nearest/v1/{profile}/{coords}` | Snap to nearest road |
| Tile | `/tile/v1/{profile}/{z}/{x}/{y}.mvt` | Vector tiles |

### Turn-by-Turn Quality

**Maneuver Types (complete list):**

| Type | Description |
|------|-------------|
| `turn` | Basic turn into direction of modifier |
| `new name` | Road name changes, no turn taken |
| `depart` | Departure of the leg |
| `arrive` | Destination of the leg |
| `merge` | Merge onto a street (e.g., highway ramp) |
| `on ramp` | Take a ramp to enter a highway |
| `off ramp` | Take a ramp to exit a highway |
| `fork` | Take left/right side at a fork |
| `end of road` | Road ends in T-intersection |
| `continue` | Stay on same road |
| `roundabout` | Traverse roundabout (has `exit` property) |
| `rotary` | Traffic circle (larger than roundabout) |
| `roundabout turn` | Turn at small roundabout |
| `notification` | Change in driving conditions |
| `exit roundabout` | Exiting a roundabout |
| `exit rotary` | Exiting a rotary |

**Modifiers:** `uturn`, `sharp right`, `right`, `slight right`, `straight`, `slight left`, `left`, `sharp left`

**Turn-by-Turn Quality Assessment:**
- Provides structured maneuver types with modifiers
- Includes intersection data with bearings and lane information
- Does NOT include human-readable narrative instructions (unlike Valhalla)
- You must generate your own instruction text from maneuver types
- Supports multiple languages via the `language` parameter (limited)

### Alternative Routes
**Yes** — supports `alternatives=true` or `alternatives=n` (up to n alternative routes). The response includes multiple route objects when alternatives are requested.

### Self-Hosting Feasibility

| Aspect | Details |
|--------|---------|
| **License** | BSD 2-Clause (very permissive) |
| **Docker Image** | `osrm/osrm-backend` (official) |
| **Setup Complexity** | Moderate — requires OSM data download and preprocessing |
| **RAM (metro area)** | 2–6 GB |
| **RAM (country)** | 8–20 GB |
| **RAM (full planet)** | 512–768 GB |
| **Disk** | 2-3x PBF file size for preprocessing |
| **Preprocessing Time** | 2–5 min (metro), 45–90 min (country) |

**Quick Start:**
```bash
# Download OSM data
wget https://download.geofabrik.de/europe/germany/berlin-latest.osm.pbf

# Preprocess (MLD algorithm - recommended)
docker run -t -v $(pwd):/data osrm/osrm-backend osrm-extract -p /opt/car.lua /data/berlin-latest.osm.pbf
docker run -t -v $(pwd):/data osrm/osrm-backend osrm-partition /data/berlin-latest.osrm
docker run -t -v $(pwd):/data osrm/osrm-backend osrm-customize /data/berlin-latest.osrm

# Run server
docker run -t -i -p 5000:5000 -v $(pwd):/data osrm/osrm-backend osrm-routed --algorithm mld /data/berlin-latest.osrm
```

### Flutter Compatibility
- REST API with JSON responses — works with any HTTP client
- Polyline encoding (precision 5 or 6) — needs decoding
- Multiple Dart packages available (see Flutter Integration section)

---

## 2. Valhalla

### Overview
Valhalla is an open-source routing engine developed by Mapbox and now maintained by the Valhalla community. It is written in C++ and uses OpenStreetMap data. It is the feature-richest open-source routing engine.

### Public Demo Servers

| Server | URL | Coverage |
|--------|-----|----------|
| **FOSSGIS Valhalla** | `https://valhalla1.openstreetmap.de` | Full planet |
| **Web App** | `https://valhalla.openstreetmap.de` | Full planet (UI) |

**Rate Limit:** Fair use policy, similar to OSRM (~1 req/sec). If publishing apps to end users, you should include an `X-Client-Id` header.

### API Key Required
**None** — open for public use with fair-use policy.

### API Endpoint Format

Valhalla uses a **POST** with JSON body:

```
POST /route
Content-Type: application/json

{
  "locations": [
    {"lat": 48.137215, "lng": 11.575628},
    {"lat": 47.437963, "lng": 11.271206}
  ],
  "costing": "auto",
  "directions_type": "instructions",
  "language": "en-US",
  "alternates": 2
}
```

**Example:**
```bash
curl -X POST https://valhalla1.openstreetmap.de/route \
  -H "Content-Type: application/json" \
  -H "X-Client-Id: navora-app" \
  -d '{
    "locations": [
      {"lat": 52.517037, "lng": 13.388860},
      {"lat": 52.529407, "lng": 13.397634}
    ],
    "costing": "auto",
    "directions_type": "instructions",
    "language": "en-US"
  }'
```

### Available Services
| Service | Endpoint | Description |
|---------|----------|-------------|
| Route | `/route` | Turn-by-turn routing |
| Matrix | `/matrix` | Distance/time matrix |
| Isochrone | `/isochrone` | Reachability polygons |
| Optimized Route | `/optimized_route` | Traveling Salesman |
| Trace Route | `/trace_route` | Map matching |
| Trace Attributes | `/trace_attributes` | Edge attributes along path |
| Expansion | `/expansion` | Edge expansion |
| Status | `/status` | Server status |
| Locate | `/locate` | Nearest road info |
| Elevation | `/elevation` | Elevation sampling |

### Turn-by-Turn Quality

**Valhalla has the BEST turn-by-turn quality among open-source routing engines:**

- **Narrative instructions**: Human-readable text like "Turn right onto Main Street"
- **Voice instructions**: Verbal transition alerts, pre/post transition instructions
- **Banner instructions**: For navigation SDKs
- **Multiple languages**: Supports many languages via IETF BCP 47 codes
- **Lane guidance**: Turn lanes with possible directions
- **Roundabout exits**: Exit numbering for roundabouts
- **Maneuver penalties**: Configurable to reduce unnecessary maneuvers

**Maneuver Types:**
| Type | Description |
|------|-------------|
| `kTurn` | Basic turn |
| `kStraight` | Continue straight |
| `kLocation` | Location arrival |
| `kStart` | Start of route |
| `kDestination` | Destination reached |
| `kBecomes` | Road name change |
| `kSlightRight/Left` | Slight turn |
| `kRight/Left` | Normal turn |
| `kSharpRight/Left` | Sharp turn |
| `kUTurn` | U-turn |
| `kRampRight/Left` | Ramp turn |
| `kExitRight/Left` | Exit ramp |
| `kStayRight/Left` | Stay on side |
| `kMerge` | Merge |
| `kRoundaboutEnter` | Enter roundabout |
| `kRoundaboutExit` | Exit roundabout |
| `kFerry` | Ferry |
| `kTransit` | Transit connection |
| `kTransitTransfer` | Transit transfer |
| `kTransitRemainOn` | Stay on transit |
| `kTransitConnectionStart` | Transit connection start |
| `kTransitConnectionTransfer` | Transit connection transfer |
| `kTransitConnectionDestination` | Transit connection destination |
| `kPostTransitConnectionDestination` | Post-transit destination |

**Voice Instruction Fields:**
- `verbal_transition_alert_instruction` — "In 500 feet, turn right onto Main Street"
- `verbal_pre_transition_instruction` — "Turn right onto Main Street"
- `verbal_post_transition_instruction` — "Continue on Main Street for 2.3 miles"
- `verbal_depart_instruction` — "Depart at 8:04 AM from..."
- `verbal_arrive_instruction` — "Arrive at 34 St - Herald Sq"

### Alternative Routes
**Yes** — supports `alternates` parameter (0-3). Note: Alternates are not supported on multipoint routes (more than 2 locations) or time-dependent routes.

### Self-Hosting Feasibility

| Aspect | Details |
|--------|---------|
| **License** | MIT (very permissive) |
| **Docker Image** | `ghcr.io/gis-ops/docker-valhalla/valhalla:latest` |
| **Setup Complexity** | Easy with Docker |
| **RAM (metro area)** | 3–6 GB |
| **RAM (regional)** | 8–16 GB |
| **RAM (full planet)** | 16–64 GB |
| **Disk (planet tiles)** | ~90–150 GB |
| **Tile Build Time** | 4–12 hours (planet, 32-core) |

**Quick Start:**
```bash
# Download OSM data
wget https://download.geofabrik.de/europe/germany/berlin-latest.osm.pbf

# Run with Docker (auto-builds tiles)
docker run -p 8002:8002 \
  -v $(pwd)/custom_files:/custom_files \
  ghcr.io/gis-ops/docker-valhalla/valhalla:latest
```

### Flutter Compatibility
- REST API with JSON responses
- Supports OSRM-compatible output format (`format: "osrm"`)
- Supports GPX output format
- Multiple Dart packages available

---

## 3. GraphHopper

### Overview
GraphHopper is an open-source routing engine written in Java. It is Apache 2.0 licensed and can be used as a library or standalone web server. The cloud API is a commercial product, but the core engine is fully open source.

### Free Tier (Cloud API)

| Plan | Credits/Day | Credits/Min | Requests/Sec | Max Locations | Commercial |
|------|-------------|-------------|--------------|---------------|------------|
| **Free** | 500 | Limited | Limited | 5 | No |
| Basic (€69/mo) | 5,000 | 100 | 1 | 30 | Yes |
| Standard (€199/mo) | 15,000 | 400 | 2 | 80 | Yes |
| Premium (€479/mo) | 50,000 | 1,000 | 10 | 200 | Yes |

**Credit Costs:**
- Routing: 1 credit for 2-10 locations; locations/10 above that
- Alternative routes: +1 credit per alternative
- Matrix: (origins x destinations) / 2

### API Key Required
**Yes** — required for the cloud API. Free tier available for non-commercial use only.

### API Endpoint Format

```
GET /route?point={lat},{lng}&point={lat},{lng}&profile=car&key={API_KEY}&instructions=true&alternative_route.max=3
```

### Turn-by-Turn Quality
- Provides turn-by-turn instructions
- Supports multiple languages
- Good maneuver type coverage
- Not as rich as Valhalla's narrative instructions

### Alternative Routes
**Yes** — supports `alternative_route.max` parameter (up to 3 on free tier).

### Self-Hosting Feasibility

| Aspect | Details |
|--------|---------|
| **License** | Apache 2.0 (fully open source) |
| **Docker Image** | `ghcr.io/graphhopper/graphhopper:latest` |
| **Setup Complexity** | Easy with Docker |
| **RAM (metro area)** | 5–9 GB |
| **RAM (full planet)** | 60–120 GB (import), 31 GB (MMAP mode) |
| **Disk** | 20+ GB for regional data |
| **Import Time** | ~3 hours (planet, 60GB RAM) |

**Quick Start:**
```bash
# Download OSM data
wget https://download.geofabrik.de/europe/germany/berlin-latest.osm.pbf

# Run with Docker
docker run -p 8989:8989 \
  -v $(pwd)/graph-data:/graphhopper/data \
  ghcr.io/graphhopper/graphhopper:latest
```

### Flutter Compatibility
- REST API with JSON responses
- Standard HTTP client works well

---

## 4. OpenRouteService

### Overview
OpenRouteService (ORS) is developed by HeiGIT (Heidelberg Institute for Geoinformation Technology). It provides a generous free tier and is fully open source for self-hosting.

### Free Tier (Standard Plan)

| Endpoint | Daily Limit | Per Minute |
|----------|-------------|------------|
| Directions V2 | 2,000 | 40 |
| Isochrones V2 | 500 | 20 |
| Matrix V2 | 500 | 40 |
| Snap V2 | 2,000 | 100 |
| Elevation | 2,000 | 40 |
| Geocoding | 3,000 | 100 |
| Optimization | 500 | 40 |
| POIs | 500 | 60 |

### API Key Required
**Yes** — free registration required. Standard plan is free for everyone.

### API Endpoint Format

```
GET /v2/directions/{profile}?api_key={API_KEY}&start={lng},{lat}&end={lng},{lat}&alternative_routes.count=3
```

**Profiles:** `driving-car`, `driving-hgv`, `cycling-regular`, `cycling-road`, `cycling-mountain`, `cycling-electric`, `foot-walking`, `foot-hiking`, `wheelchair`

### Turn-by-Turn Quality
- Provides turn-by-turn instructions
- Supports multiple languages
- Good maneuver type coverage
- Includes elevation data

### Alternative Routes
**Yes** — supports up to 3 alternative routes.

### Self-Hosting Feasibility

| Aspect | Details |
|--------|---------|
| **License** | Fully open source |
| **Docker** | Available via Docker Compose |
| **Setup Complexity** | Moderate |
| **Limits** | Unlimited when self-hosted |

### Flutter Compatibility
- REST API with JSON responses
- Well-documented API

---

## 5. Free Routing APIs with No API Key Required

### Public OSRM Instances

| Instance | URL | Profiles | Rate Limit | Notes |
|----------|-----|----------|------------|-------|
| **FOSSGIS** | `https://routing.openstreetmap.de` | car, bike, foot | ~1 req/sec | Best option, 3 separate instances |
| **Project OSRM** | `https://router.project-osrm.org` | car only | ~1 req/sec | Ignores profile in URL |

### Public Valhalla Instances

| Instance | URL | Coverage | Rate Limit |
|----------|-----|----------|------------|
| **FOSSGIS Valhalla** | `https://valhalla1.openstreetmap.de` | Full planet | Fair use |

### Other Free Services (No API Key)

| Service | URL | Notes |
|---------|-----|-------|
| **FOSSGIS Routing** | `https://routing.openstreetmap.de` | OSRM with car/bike/foot |
| **OpenStreetMap Nominatim** | `https://nominatim.openstreetmap.org` | Geocoding (1 req/sec) |
| **Photon** | `https://photon.komoot.io` | Geocoding (fair use) |

### Important Note on FOSSGIS OSRM Profiles
The FOSSGIS server runs three separate OSRM instances. You **must** use the correct path prefix:
- `/routed-car/...` for driving
- `/routed-bike/...` for cycling
- `/routed-foot/...` for walking

Using the wrong prefix or no prefix will silently return car routes.

---

## 6. Self-Hosting Routing Engines

### Can We Self-Host for Free?

**Yes!** All three major routing engines (OSRM, Valhalla, GraphHopper) are open source and can be self-hosted at no software cost. You only pay for infrastructure.

### Hardware Requirements Comparison

| Engine | Metro Area | Regional | Country | Full Planet |
|--------|-----------|----------|---------|-------------|
| **OSRM** | 2-6 GB RAM | 8-20 GB | 32-64 GB | 512-768 GB |
| **Valhalla** | 3-6 GB RAM | 8-16 GB | 16-32 GB | 16-64 GB |
| **GraphHopper** | 5-9 GB RAM | 16-32 GB | 32-60 GB | 60-120 GB |

### Setup Complexity

| Engine | Docker Support | Setup Time | Difficulty |
|--------|---------------|------------|------------|
| **OSRM** | Excellent | 30-90 min | Moderate |
| **Valhalla** | Excellent | 15-60 min | Easy |
| **GraphHopper** | Excellent | 30-120 min | Easy-Moderate |

### Recommended Self-Hosting Approach

For a Flutter app like Navora, the recommended approach is:

1. **Start with regional extracts** (e.g., your country or service area)
2. **Use Valhalla** for best turn-by-turn quality
3. **Use Docker** for easy deployment
4. **Update OSM data weekly/monthly**

**Minimal Viable Self-Hosted Setup:**
```bash
# 1. Download regional OSM data
wget https://download.geofabrik.de/asia/india-latest.osm.pbf

# 2. Run Valhalla with Docker
docker run -p 8002:8002 \
  -v $(pwd)/custom_files:/custom_files \
  ghcr.io/gis-ops/docker-valhalla/valhalla:latest

# 3. API available at http://localhost:8002
```

### Free Hosting Options for Self-Hosted Routing

| Platform | Free Tier | Notes |
|----------|-----------|-------|
| **Oracle Cloud Free Tier** | 4 ARM cores, 24 GB RAM | Best free tier for routing |
| **Google Cloud** | $300 credit (90 days) | Good for initial setup |
| **AWS** | 750 hours t2.micro (12 months) | Too small for routing |
| **Azure** | $200 credit (30 days) | Good for initial setup |
| **Hetzner** | €20/month (CX41) | Cheap dedicated servers |

---

## 7. Turn-by-Turn Navigation

### Comparison of Turn-by-Turn Quality

| Feature | OSRM | Valhalla | GraphHopper | ORS |
|---------|------|----------|-------------|-----|
| Maneuver types | 18 types | 20+ types | Good | Good |
| Narrative instructions | No (build your own) | Yes (excellent) | Yes | Yes |
| Voice instructions | No | Yes (excellent) | No | No |
| Banner instructions | No | Yes | No | No |
| Lane guidance | Yes (intersection data) | Yes (turn_lanes) | No | No |
| Roundabout exits | Yes | Yes | Yes | Yes |
| Multiple languages | Limited | Yes (BCP 47) | Yes | Yes |
| Verbal alerts | No | Yes | No | No |

### Valhalla's Superior Turn-by-Turn

Valhalla is the clear winner for turn-by-turn navigation:

1. **Narrative Instructions**: "Turn right onto Main Street"
2. **Voice Instructions**: 
   - `verbal_transition_alert_instruction`: "In 500 feet, turn right"
   - `verbal_pre_transition_instruction`: "Turn right onto Main Street"
   - `verbal_post_transition_instruction`: "Continue for 2.3 miles"
3. **OSRM-compatible output**: Can output in OSRM format for SDK compatibility
4. **Navigation SDK compatible**: Works with MapLibre Navigation SDK

### OSRM Turn-by-Turn Workaround

OSRM does not provide narrative instructions, but you can build them from maneuver types:

```dart
String getInstruction(OSRMManeuver maneuver) {
  final type = maneuver.type;
  final modifier = maneuver.modifier;
  final name = maneuver.name;
  
  switch (type) {
    case 'depart':
      return 'Head ${modifier} on $name';
    case 'turn':
      return 'Turn $modifier onto $name';
    case 'merge':
      return 'Merge $modifier onto $name';
    case 'roundabout':
      return 'At the roundabout, take exit ${maneuver.exit}';
    case 'arrive':
      return 'Arrive at destination';
    // ... etc
  }
}
```

---

## 8. Real-Time Traffic

### Free Traffic Data Sources

| Source | URL | Coverage | API Key | Notes |
|--------|-----|----------|---------|-------|
| **TomTom Traffic** | `https://api.tomtom.com` | Global | Yes (free tier) | 2,500 transactions/day free |
| **HERE Traffic** | `https://traffic.ls.hereapi.com` | Global | Yes (free tier) | 100,000 events/month free |
| **EU SRTI (TomTom)** | EU only | EU | No | EU Regulation 886/2013 |
| **EU SRTI (HERE)** | EU only | EU | No | EU Regulation 886/2013 |

### Integrating Traffic with Routing

**Valhalla** supports traffic through:
- Predicted speed buckets baked into tiles at build time
- Real-time speed extension (requires additional setup)
- Historical traffic patterns

**OSRM** supports traffic through:
- `osrm-customize` to update edge weights
- Custom speed data in the Lua profile
- No built-in real-time traffic support

**GraphHopper** supports traffic through:
- `custom_model` per-request speed adjustments
- Live traffic data integration

### Recommendation for Navora

For a free solution, **real-time traffic is the hardest problem**. Options:
1. **Use TomTom/HERE free tiers** for traffic data, feed into routing engine
2. **Use historical traffic patterns** (baked into Valhalla tiles)
3. **Skip real-time traffic** initially, add later as a premium feature

---

## 9. Alternative Routes

### Support Across Services

| Service | Alternatives | Parameter | Max Alternatives |
|---------|-------------|-----------|-----------------|
| **OSRM** | Yes | `alternatives=n` | Unlimited (practical limit ~10) |
| **Valhalla** | Yes | `alternates=n` | 3 |
| **GraphHopper** | Yes | `alternative_route.max=n` | 3 (free tier) |
| **ORS** | Yes | `alternative_routes.count=n` | 3 |

### OSRM Alternative Routes Example

```
GET /route/v1/driving/13.388,52.517;13.397,52.529?alternatives=3&steps=true
```

Response contains array of routes:
```json
{
  "routes": [
    {"distance": 1000, "duration": 120, "legs": [...]},
    {"distance": 1100, "duration": 130, "legs": [...]},
    {"distance": 1200, "duration": 140, "legs": [...]}
  ]
}
```

### Valhalla Alternative Routes Example

```json
POST /route
{
  "locations": [...],
  "costing": "auto",
  "alternates": 2
}
```

---

## 10. Flutter Integration

### Dart/Flutter Packages

| Package | URL | Features |
|---------|-----|----------|
| **routing_client_dart** | `pub.dev/packages/routing_client_dart` | OSRM + Valhalla client, trip service, instructions |
| **valhalla_routing_client** | `pub.dev/packages/valhalla_routing_client` | Valhalla API wrapper (unofficial) |
| **routing_engine** | `pub.dev/packages/routing_engine` | Multi-backend (OSRM + Valhalla), engine-agnostic |
| **flutter_map** | `pub.dev/packages/flutter_map` | Map rendering with route polylines |
| **latlong2** | `pub.dev/packages/latlong2` | Coordinate types |

### Example: OSRM Integration with Flutter

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class OSRMRoutingService {
  static const String baseUrl = 'https://routing.openstreetmap.de';
  
  Future<OSRMRoute> getRoute({
    required LatLng origin,
    required LatLng destination,
    String profile = 'routed-car',
    bool alternatives = true,
    bool steps = true,
  }) async {
    final coords = '${origin.longitude},${origin.latitude};'
                 '${destination.longitude},${destination.latitude}';
    
    final url = Uri.parse(
      '$baseUrl/$profile/route/v1/driving/$coords'
      '?alternatives=$alternatives&steps=$steps&geometries=polyline6&overview=full'
    );
    
    final response = await http.get(url, headers: {
      'User-Agent': 'Navora/1.0 (your@email.com)',
    });
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return OSRMRoute.fromJson(data);
    } else {
      throw Exception('Routing failed: ${response.statusCode}');
    }
  }
}
```

### Example: Valhalla Integration with Flutter

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class ValhallaRoutingService {
  static const String baseUrl = 'https://valhalla1.openstreetmap.de';
  
  Future<ValhallaRoute> getRoute({
    required LatLng origin,
    required LatLng destination,
    String costing = 'auto',
    int alternates = 0,
  }) async {
    final url = Uri.parse('$baseUrl/route');
    
    final body = jsonEncode({
      'locations': [
        {'lat': origin.latitude, 'lng': origin.longitude},
        {'lat': destination.latitude, 'lng': destination.longitude},
      ],
      'costing': costing,
      'directions_type': 'instructions',
      'language': 'en-US',
      'alternates': alternates,
    });
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-Client-Id': 'navora-app',
      },
      body: body,
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return ValhallaRoute.fromJson(data);
    } else {
      throw Exception('Routing failed: ${response.statusCode}');
    }
  }
}
```

### Polyline Decoding

Both OSRM and Valhalla return encoded polylines. Use the `google_polyline` package or implement decoding:

```dart
// Add to pubspec.yaml: google_polyline: ^1.0.0
import 'package:google_polyline/google_polyline.dart';

List<LatLng> decodePolyline(String encoded) {
  final points = Polyline.Decode(encodedString: encoded, precision: 6);
  return points.map((p) => LatLng(p.latitude, p.longitude)).toList();
}
```

### Recommended Flutter Architecture

```
lib/
├── services/
│   ├── routing_service.dart       # Abstract interface
│   ├── osrm_routing_service.dart  # OSRM implementation
│   └── valhalla_routing_service.dart # Valhalla implementation
├── models/
│   ├── route.dart                 # Route model
│   ├── maneuver.dart              # Maneuver model
│   └── leg.dart                   # Leg model
└── widgets/
    ├── route_polyline.dart        # Route display
    └── navigation_panel.dart      # Turn-by-turn UI
```

---

## Comparison Matrix

| Criteria | OSRM Demo | Valhalla Demo | GraphHopper Free | ORS Free |
|----------|-----------|---------------|------------------|----------|
| **API Key** | None | None | Required | Required |
| **Free Tier** | Unlimited (fair use) | Unlimited (fair use) | 500 credits/day | 2000 directions/day |
| **Rate Limit** | ~1 req/sec | ~1 req/sec | Limited | 40/min |
| **Turn-by-Turn** | Good (types only) | Excellent (narrative + voice) | Good | Good |
| **Alternatives** | Yes (unlimited) | Yes (up to 3) | Yes (up to 3) | Yes (up to 3) |
| **Self-Host** | Yes | Yes | Yes | Yes |
| **Profiles** | car, bike, foot | auto, pedestrian, bicycle, transit, truck | car, bike, foot, motorcycle | 8+ profiles |
| **Languages** | Limited | Yes (BCP 47) | Yes | Yes |
| **Traffic** | No | Predicted (tiles) | No | No |
| **Best For** | Prototyping, light use | Production navigation | Flexible routing | Generous free tier |

---

## Recommendations

### For Navora (TripMesh) Flutter App

#### Short Term (Development + Light Production)
1. **Use FOSSGIS OSRM** (`routing.openstreetmap.de`) for routing
   - No API key needed
   - Use correct path prefixes (`/routed-car/`, `/routed-bike/`, `/routed-foot/`)
   - Implement custom instruction generation from maneuver types
   - Rate limit: ~1 req/sec

2. **Use FOSSGIS Valhalla** (`valhalla1.openstreetmap.de`) for turn-by-turn
   - Best narrative instructions
   - Voice instruction support
   - Include `X-Client-Id: navora-app` header

#### Medium Term (Production)
3. **Self-host Valhalla** on a regional extract
   - Use Docker for easy deployment
   - Start with your service area (country/region)
   - Update OSM data weekly
   - No rate limits, no API keys

4. **Implement multi-engine fallback**
   - Try Valhalla first (best quality)
   - Fall back to OSRM if Valhalla fails
   - Cache routes to reduce API calls

#### Long Term (Scale)
5. **Self-host both OSRM and Valhalla**
   - OSRM for fast routing (lower latency)
   - Valhalla for turn-by-turn navigation
   - Use a load balancer

6. **Add traffic data**
   - Integrate TomTom/HERE free tier
   - Feed traffic speeds into routing engine
   - Consider as premium feature

### Architecture Recommendation

```
┌─────────────────────────────────────────────┐
│              Navora Flutter App              │
├─────────────────────────────────────────────┤
│         Routing Service (Abstract)           │
├──────────────┬──────────────┬───────────────┤
│   OSRM       │   Valhalla   │   Fallback    │
│  (Fast)      │  (Best TBT)  │  (Cache)      │
├──────────────┴──────────────┴───────────────┤
│         HTTP Client + Polyline Decoder       │
├─────────────────────────────────────────────┤
│  FOSSGIS Servers  │  Self-Hosted (future)   │
└─────────────────────────────────────────────┘
```

### Key Implementation Notes

1. **Always set User-Agent** header identifying your app
2. **Respect rate limits** — implement request throttling
3. **Cache routes** to reduce API calls
4. **Handle errors gracefully** — servers can be down
5. **Monitor usage** — track request counts
6. **Plan for self-hosting** — design for easy endpoint switching

---

## Appendix: API Response Examples

### OSRM Route Response (Simplified)

```json
{
  "code": "Ok",
  "routes": [
    {
      "distance": 1000.5,
      "duration": 120.3,
      "geometry": "encoded_polyline_string",
      "legs": [
        {
          "distance": 1000.5,
          "duration": 120.3,
          "steps": [
            {
              "distance": 50.0,
              "duration": 10.0,
              "name": "Main Street",
              "maneuver": {
                "type": "depart",
                "modifier": "straight",
                "location": [13.388860, 52.517037]
              }
            },
            {
              "distance": 100.0,
              "duration": 20.0,
              "name": "Oak Avenue",
              "maneuver": {
                "type": "turn",
                "modifier": "right",
                "location": [13.390000, 52.518000]
              }
            }
          ]
        }
      ]
    }
  ]
}
```

### Valhalla Route Response (Simplified)

```json
{
  "trip": {
    "summary": {
      "length": 1.0,
      "time": 120
    },
    "legs": [
      {
        "summary": {
          "length": 1.0,
          "time": 120
        },
        "shape": "encoded_polyline_string",
        "maneuvers": [
          {
            "type": 2,
            "instruction": "Head east on Main Street.",
            "verbal_transition_alert_instruction": "In 500 feet, head east on Main Street.",
            "verbal_pre_transition_instruction": "Head east on Main Street.",
            "verbal_post_transition_instruction": "Continue on Main Street for 0.5 miles.",
            "street_names": ["Main Street"],
            "length": 0.5,
            "time": 60
          },
          {
            "type": 10,
            "instruction": "Turn right onto Oak Avenue.",
            "verbal_transition_alert_instruction": "In 200 feet, turn right onto Oak Avenue.",
            "verbal_pre_transition_instruction": "Turn right onto Oak Avenue.",
            "verbal_post_transition_instruction": "Continue on Oak Avenue for 0.5 miles.",
            "street_names": ["Oak Avenue"],
            "length": 0.5,
            "time": 60
          }
        ]
      }
    ]
  }
}
```

---

*Report generated: October 2026*  
*Last updated: Based on current public information*
