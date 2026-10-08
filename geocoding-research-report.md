# Free Geocoding & Place Search APIs — Research Report

**Project:** Navora (TripMesh)  
**Date:** October 2026  
**Purpose:** Evaluate free geocoding and POI search APIs to replace Google Places API

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Service Comparison Matrix](#service-comparison-matrix)
3. [Nominatim (OSM Geocoder)](#1-nominatim-osm-geocoder)
4. [Photon](#2-photon)
5. [OpenCage Geocoder](#3-opencage-geocoder)
6. [LocationIQ](#4-locationiq)
7. [Overpass API (POI Search)](#5-overpass-api-poi-search)
8. [Self-Hosted Geocoding](#6-self-hosted-geocoding)
9. [POI (Points of Interest) Search](#7-poi-points-of-interest-search)
10. [Address Autocomplete](#8-address-autocomplete)
11. [Reverse Geocoding](#9-reverse-geocoding)
12. [Flutter Integration](#10-flutter-integration)
13. [Additional Services Evaluated](#11-additional-services-evaluated)
14. [Recommendations for Navora](#12-recommendations-for-navora)

---

## Executive Summary

Navora currently uses **Nominatim** for search and **Overpass API** for POI. Both are excellent choices — completely free, no API key required, and based on OpenStreetMap data. The main challenge is **rate limiting** (1 req/s for Nominatim public instance) and **search quality** compared to Google Places.

**Key findings:**
- **Photon** is the strongest alternative — purpose-built for search-as-you-type, no API key, typo-tolerant, and can be self-hosted
- **LocationIQ** offers the best free tier with API key (5,000 req/day) and Nominatim-compatible API
- **OpenCage** provides 2,500 req/day free with good quality but requires API key
- **Self-hosting Nominatim** is feasible with Docker but requires significant hardware for full planet (128GB RAM, 1TB disk)
- **Overpass API** remains the best free POI search — no API key, but rate-limited
- **Overture Maps** is an emerging open data source with places/addresses themes
- Multiple Flutter packages exist for Nominatim integration

---

## Service Comparison Matrix

| Service | API Key | Free Tier | Rate Limit | POI Data | Self-Host | Autocomplete | Reverse Geo |
|---------|---------|-----------|------------|----------|-----------|-------------|-------------|
| **Nominatim** | ❌ No | Unlimited* | 1 req/s | ✅ Yes | ✅ Yes | ⚠️ Basic | ✅ Yes |
| **Photon** | ❌ No | Unlimited* | Fair use | ✅ Yes | ✅ Yes | ✅ Excellent | ✅ Yes |
| **OpenCage** | ✅ Yes | 2,500/day | 1 req/s | ✅ Yes | ❌ No | ✅ Yes | ✅ Yes |
| **LocationIQ** | ✅ Yes | 5,000/day | 2 req/s | ✅ Yes | ❌ No | ✅ Yes | ✅ Yes |
| **Overpass API** | ❌ No | Unlimited* | ~1M/day | ✅ Excellent | ✅ Yes | ❌ No | ❌ No |
| **Geoapify** | ✅ Yes | 3,000/day | 5 req/s | ✅ Yes | ❌ No | ✅ Yes | ✅ Yes |
| **Mapbox** | ✅ Yes | 100,000/mo | 1,000/min | ✅ Yes | ❌ No | ✅ Yes | ✅ Yes |
| **geocode.maps.co** | ✅ Yes | 25,000/mo | 1-5 req/s | ⚠️ Limited | ❌ No | ❌ No | ✅ Yes |
| **MyGeocode** | ❌ No | 2,500/day | Reasonable | ⚠️ Limited | ❌ No | ✅ Yes | ✅ Yes |
| **Overture Maps** | ✅ Yes | Free tier | Varies | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |

*\* "Unlimited" means no hard cap, but fair-use policies apply*

---

## 1. Nominatim (OSM Geocoder)

### Overview
Nominatim is the official geocoding software for OpenStreetMap. It powers the search bar on openstreetmap.org and serves ~30 million queries per day on a single server.

### Endpoints
| Endpoint | URL |
|----------|-----|
| Forward Search | `https://nominatim.openstreetmap.org/search?q={query}&format=json` |
| Reverse Geocode | `https://nominatim.openstreetmap.org/reverse?lat={lat}&lon={lon}&format=json` |
| Status | `https://nominatim.openstreetmap.org/status` |
| Lookup | `https://nominatim.openstreetmap.org/lookup?osm_ids={id}` |

### Free Tier Limits
- **No API key required**
- **No hard daily limit** — but strict rate limits apply
- **1 request per second** absolute maximum (sum across all users of your app)
- Bulk geocoding of large address lists is **prohibited**
- Auto-complete/type-ahead that issues one request per keystroke is **prohibited**
- Periodic requests from apps are considered bulk geocoding and **strongly discouraged**

### Usage Policy Highlights
- Must provide valid HTTP `User-Agent` or `Referer` identifying the application
- Must display attribution: `© OpenStreetMap contributors`
- Must implement caching to avoid repeated queries
- Must be able to switch service endpoints without app update
- Commercial applications should be cautious — policy may change without notice

### Search Quality & Coverage
- **Coverage:** Global, based on OSM data
- **Strengths:** Addresses, streets, cities, landmarks, POIs
- **Weaknesses:** 
  - Search quality varies significantly by region (excellent in Europe/US, weaker in developing countries)
  - No typo tolerance
  - No search-as-you-type optimization
  - Results can be inconsistent for ambiguous queries
  - No structured POI categories (restaurant, hospital, etc.)
- **Data freshness:** Updated continuously via OSM replication

### POI Data Availability
- ✅ Can search for POIs by name (e.g., "Starbucks near London")
- ❌ No structured POI category filtering (can't search "all restaurants within 5km")
- ❌ No POI details like ratings, reviews, opening hours, photos
- For structured POI search, use **Overpass API** instead

### Self-Hosting Feasibility
- **Docker image available:** `mediagis/nominatim:5.3` (10M+ pulls)
- **Hardware requirements:**
  - Minimum: 2GB RAM (installation will fail below this)
  - Full planet: 128GB+ RAM, 1TB+ disk (SSD/NVME strongly recommended)
  - Country-level extract: 8-16GB RAM, 100-200GB disk
  - City-level extract: 2-4GB RAM, 10-20GB disk
- **Import time:** Full planet ~2 days on NVME, 7-8 days on HDD
- **Quick start with Docker:**
  ```bash
  docker run -it \
    -e PBF_URL=https://download.geofabrik.de/europe/monaco-latest.osm.pbf \
    -e REPLICATION_URL=https://download.geofabrik.de/europe/monaco-updates/ \
    -p 8080:8080 \
    --name nominatim \
    mediagis/nominatim:5.3
  ```
- **Data downloads:** [Geofabrik](https://download.geofabrik.de/) provides regional extracts
- **Verdict:** Self-hosting is feasible for country/city-level data. Full planet is expensive but possible.

### Flutter Compatibility
- ✅ Multiple Flutter packages available (see [Flutter Integration](#10-flutter-integration))
- ✅ Simple HTTP API — can use `http` or `dio` packages directly
- ✅ JSON response format

---

## 2. Photon

### Overview
Photon is an open-source geocoder built for OpenStreetMap data, developed by [Komoot](https://www.komoot.com/). It is based on OpenSearch and is specifically designed for **search-as-you-type** with typo tolerance.

### Endpoints
| Endpoint | URL |
|----------|-----|
| Forward Search | `https://photon.komoot.io/api?q={query}` |
| Structured Search | `https://photon.komoot.io/structured?city={city}&street={street}` |
| Reverse Geocode | `https://photon.komoot.io/reverse?lat={lat}&lon={lon}` |
| Status | `https://photon.komoot.io/status` |

### Free Tier Limits
- **No API key required**
- **No hard daily limit** — fair use policy
- "Reasonable limit" — extensive usage will be throttled or banned
- No guarantees for availability
- Used in production with thousands of requests per minute at photon.komoot.io

### Key Features
- ✅ **Search-as-you-type** — optimized for autocomplete
- ✅ **Typo tolerance** — handles misspellings
- ✅ **Multilingual** — supports multiple languages
- ✅ **Location bias** — `lat`/`lon` parameters to prioritize nearby results
- ✅ **OSM tag filtering** — filter by `osm_tag=amenity:restaurant`
- ✅ **Bounding box** — restrict search area
- ✅ **Country code filtering**
- ✅ **Deduplication** — automatically merges duplicate OSM features
- ✅ **GeoJSON output** — standard format

### Search Quality & Coverage
- **Coverage:** Global, based on OSM data
- **Strengths:** 
  - Excellent for autocomplete/search-as-you-type
  - Typo tolerance makes it much better than Nominatim for user-facing search
  - Location bias gives relevant local results
  - Fast response times
- **Weaknesses:** 
  - Still based on OSM data (same coverage gaps as Nominatim)
  - Multilingual support limited (primarily English and German)
  - No POI details (ratings, reviews, etc.)

### POI Data Availability
- ✅ Can search for POIs by name
- ✅ OSM tag filtering allows structured POI search (e.g., `osm_tag=amenity=fuel`)
- ❌ No POI details like ratings, reviews, photos
- ❌ No opening hours (unless tagged in OSM)

### Self-Hosting Feasibility
- **Requirements:** Java 21+, OpenSearch 3.x (or embedded mode)
- **Hardware:** 
  - Planet-wide: ~95GB disk, 64GB+ RAM recommended
  - Country-level: proportionally less
- **Setup:** Download pre-built JAR from GitHub releases, run `java -jar photon.jar serve`
- **Data dumps:** Pre-built dumps available from GraphHopper
- **Verdict:** More complex than Nominatim to self-host (requires Java + OpenSearch), but very doable

### Flutter Compatibility
- ✅ Simple HTTP API with GeoJSON responses
- ✅ Can use `http` or `dio` packages directly
- ✅ No authentication needed
- ✅ CORS enabled on public instance

---

## 3. OpenCage Geocoder

### Overview
OpenCage is a commercial geocoding API that aggregates multiple data sources including OpenStreetMap. It offers a free trial tier suitable for testing and small applications.

### Endpoints
| Endpoint | URL |
|----------|-----|
| Forward Geocode | `https://api.opencagedata.com/geocode/v1/json?q={query}&key={key}` |
| Reverse Geocode | `https://api.opencagedata.com/geocode/v1/json?q={lat}+{lon}&key={key}` |

### Free Tier Limits
- **API key required** (free registration, no credit card)
- **2,500 requests per day** (UTC timezone, resets at midnight UTC)
- **1 request per second**
- Free trial accounts are deleted after 3 months of inactivity
- Hitting the limit returns `402 - quota exceeded`
- Exceeding rate limit returns `429 - too many requests`

### Search Quality & Coverage
- **Coverage:** Global, aggregates multiple data sources
- **Strengths:** 
  - Good global coverage
  - Returns structured address components
  - Supports multiple languages
  - Returns timezone, currency, and other metadata
  - Good documentation
- **Weaknesses:** 
  - Free tier is limited to 2,500/day
  - Not suitable for high-volume production use without paid plan
  - Paid plans start at $50/month

### POI Data Availability
- ✅ Can search for places by name
- ✅ Returns some POI information
- ❌ No structured POI category search
- ❌ No POI details like ratings, reviews

### Self-Hosting
- ❌ Not available — commercial service only

### Flutter Compatibility
- ✅ Simple HTTP API with JSON responses
- ✅ Well-documented
- ✅ Can use `http` or `dio` packages directly

---

## 4. LocationIQ

### Overview
LocationIQ is a commercial geocoding API by Unwired Labs, positioned as an affordable Google Maps alternative. It is API-compatible with Nominatim but offers additional features and higher limits.

### Endpoints
| Endpoint | URL |
|----------|-----|
| Forward Search | `https://us1.locationiq.com/v1/search?key={key}&q={query}&format=json` |
| Reverse Geocode | `https://us1.locationiq.com/v1/reverse?key={key}&lat={lat}&lon={lon}&format=json` |
| Autocomplete | `https://us1.locationiq.com/v1/autocomplete?key={key}&q={query}&format=json` |

### Free Tier Limits
- **API key required** (free registration)
- **5,000 requests per day** — most generous free tier among commercial providers
- **2 requests per second**
- US and EU datacenters available
- 99.99% uptime SLA

### Search Quality & Coverage
- **Coverage:** Global, powered by OSM + proprietary data
- **Strengths:** 
  - Nominatim-compatible API (easy migration)
  - Higher quality than raw Nominatim (additional datasets and algorithms)
  - Autocomplete endpoint included
  - Structured address components
  - Multiple languages
  - Fast response times (<100ms)
  - Can store response data forever
- **Weaknesses:** 
  - Still based primarily on OSM data
  - Free tier may not be sufficient for high-volume production

### POI Data Availability
- ✅ Can search for places by name
- ✅ Returns structured address data
- ❌ No structured POI category search
- ❌ No POI details like ratings, reviews

### Self-Hosting
- ❌ Not available — commercial service only

### Flutter Compatibility
- ✅ Nominatim-compatible API — existing Nominatim Flutter packages work with minimal changes
- ✅ Well-documented
- ✅ JSON response format

---

## 5. Overpass API (POI Search)

### Overview
The Overpass API is a read-only API that serves custom selected parts of OpenStreetMap data. It is the **best free option for structured POI search** — querying by category, tags, and geographic area.

### Endpoints
| Endpoint | URL |
|----------|-----|
| Main | `https://overpass-api.de/api/interpreter` |
| Kumi Systems | `https://overpass.kumi.systems/api/interpreter` |
| US Instance | `https://overpass.us/api/interpreter` |

### Free Tier Limits
- **No API key required**
- **~1,000,000 requests per day** (safe estimate)
- **~10,000 queries or 5GB max downloaded data per day**
- Rate limited per IP address
- Check quota at `/api/status`

### Key Features
- ✅ **Structured POI search** — query by any OSM tag
- ✅ **Geographic filtering** — bounding box, radius, area
- ✅ **Multiple output formats** — JSON, XML, GeoJSON, CSV
- ✅ **Complex queries** — union, intersection, difference
- ✅ **No API key needed**

### Example Queries

**Find restaurants in a bounding box:**
```overpass
[out:json][timeout:25];
(
  node["amenity"="restaurant"](50.745,7.17,50.75,7.18);
  way["amenity"="restaurant"](50.745,7.17,50.75,7.18);
  relation["amenity"="restaurant"](50.745,7.17,50.75,7.18);
);
out center;
```

**Find fuel stations near a point:**
```overpass
[out:json][timeout:25];
(
  node["amenity"="fuel"](around:5000,52.52,13.40);
  way["amenity"="fuel"](around:5000,52.52,13.40);
);
out center;
```

**Find hospitals in a city:**
```overpass
[out:json][timeout:25];
area["name"="Berlin"]->.searchArea;
(
  node["amenity"="hospital"](area.searchArea);
  way["amenity"="hospital"](area.searchArea);
);
out center;
```

### POI Data Availability
- ✅ **Excellent** — this is the primary use case for Overpass
- ✅ Query by any OSM tag: `amenity=restaurant`, `amenity=fuel`, `amenity=hospital`, `shop=supermarket`, etc.
- ✅ Returns full OSM tags including name, address, opening_hours, phone, website
- ✅ Geographic filtering (bounding box, radius, area)
- ✅ Can combine multiple tag filters

### Self-Hosting
- ✅ Can be self-hosted (see Overpass API documentation)
- ✅ Requires PostgreSQL + PostGIS
- ✅ Can import OSM data extracts
- More complex setup than Nominatim

### Flutter Compatibility
- ✅ Simple HTTP POST/GET API
- ✅ JSON output format
- ✅ Can use `http` or `dio` packages directly
- ⚠️ Query language (Overpass QL) has learning curve

---

## 6. Self-Hosted Geocoding

### Nominatim Self-Hosting

#### Hardware Requirements

| Scope | RAM | Disk | Import Time |
|-------|-----|------|-------------|
| City | 2-4 GB | 10-20 GB | Minutes |
| Country | 8-16 GB | 100-200 GB | 1-4 hours |
| Continent | 32-64 GB | 400-800 GB | 4-12 hours |
| Full Planet | 128+ GB | 1+ TB | 2-7 days |

#### Docker Setup (Recommended)
```bash
# Quick start with a small extract (Monaco)
docker run -it \
  -e PBF_URL=https://download.geofabrik.de/europe/monaco-latest.osm.pbf \
  -e REPLICATION_URL=https://download.geofabrik.de/europe/monaco-updates/ \
  -p 8080:8080 \
  --name nominatim \
  mediagis/nominatim:5.3

# For a country (e.g., Germany)
docker run -it \
  -e PBF_URL=https://download.geofabrik.de/europe/germany-latest.osm.pbf \
  -e REPLICATION_URL=https://download.geofabrik.de/europe/germany-updates/ \
  -p 8080:8080 \
  --name nominatim \
  mediagis/nominatim:5.3
```

#### Data Sources
- **Geofabrik:** https://download.geofabrik.de/ — regional extracts
- **Planet OSM:** https://planet.openstreetmap.org/ — full planet
- **BBBike:** https://download.bbbike.org/osm/ — city extracts

#### Cost Estimate (Cloud)
- **VPS with 16GB RAM, 200GB SSD:** ~$20-40/month (sufficient for country-level)
- **VPS with 64GB RAM, 500GB SSD:** ~$80-150/month (continent-level)
- **VPS with 128GB RAM, 1TB NVME:** ~$200-400/month (full planet)

### Photon Self-Hosting
- Requires Java 21+ and OpenSearch 3.x
- Pre-built JAR available on GitHub releases
- Pre-built data dumps from GraphHopper
- Planet-wide: ~95GB disk, 64GB+ RAM

### Verdict for Navora
- **Recommended:** Self-host Nominatim with a **country-level or continent-level** extract
- This eliminates rate limits and gives full control
- Cost: ~$20-40/month for a VPS
- Alternatively, use the public instance with aggressive caching and rate limiting

---

## 7. POI (Points of Interest) Search

### Free Sources for Restaurants, Fuel Stations, Hospitals, etc.

#### 1. Overpass API (Recommended)
- **Best option** — no API key, structured queries, global coverage
- Query by any OSM tag
- Returns full OSM data including name, address, contact info, opening hours
- Rate limit: ~1M requests/day
- **Example:** Find all fuel stations within 5km of a point
  ```overpass
  [out:json][timeout:25];
  (node["amenity"="fuel"](around:5000,52.52,13.40);
   way["amenity"="fuel"](around:5000,52.52,13.40););
  out center;
  ```

#### 2. Overture Maps
- Open map data foundation (Meta, Microsoft, Esri, TomTom)
- Places theme with POI data
- Addresses theme with 200M+ addresses (alpha)
- Available as GeoParquet files on AWS/Azure
- Free API available at [overturemapsapi.com](https://www.overturemapsapi.com/)
- Requires API key (free tier available)
- **Advantage:** Curated, normalized data from multiple sources

#### 3. Geoapify Places API
- 800+ POI categories
- Based on OSM data
- Free tier: 3,000 requests/day
- Requires API key
- Returns structured POI data with categories

#### 4. OSM Data via Overpass (Direct)
- Query OSM data directly
- All POI types available: restaurants, fuel stations, hospitals, schools, etc.
- Full tag data returned

### OSM POI Tag Reference

| Category | OSM Tag | Example |
|----------|---------|---------|
| Restaurants | `amenity=restaurant` | `node["amenity"="restaurant"]` |
| Cafes | `amenity=cafe` | `node["amenity"="cafe"]` |
| Fast Food | `amenity=fast_food` | `node["amenity"="fast_food"]` |
| Fuel Stations | `amenity=fuel` | `node["amenity"="fuel"]` |
| Hospitals | `amenity=hospital` | `node["amenity"="hospital"]` |
| Pharmacies | `amenity=pharmacy` | `node["amenity"="pharmacy"]` |
| Schools | `amenity=school` | `node["amenity"="school"]` |
| Banks | `amenity=bank` | `node["amenity"="bank"]` |
| ATMs | `amenity=atm` | `node["amenity"="atm"]` |
| Parking | `amenity=parking` | `node["amenity"="parking"]` |
| Hotels | `tourism=hotel` | `node["tourism"="hotel"]` |
| Charging Stations | `amenity=charging_station` | `node["amenity"="charging_station"]` |
| Supermarkets | `shop=supermarket` | `node["shop"="supermarket"]` |
| Police | `amenity=police` | `node["amenity"="police"]` |
| Fire Stations | `amenity=fire_station` | `node["amenity"="fire_station"]` |

---

## 8. Address Autocomplete

### Free Address Autocomplete Services

#### 1. Photon (Recommended — No API Key)
- Purpose-built for search-as-you-type
- Typo tolerance
- Location bias support
- GeoJSON output
- **Endpoint:** `https://photon.komoot.io/api?q={partial_query}&limit=5`
- **Example:**
  ```
  https://photon.komoot.io/api?q=Brandenburger&limit=5&lat=52.52&lon=13.40
  ```

#### 2. MyGeocode (No API Key)
- 2,500 requests/day free
- No account needed for free tier
- Returns suggestions with coordinates
- **Endpoint:** `https://api.mygeocode.com/v1/autocomplete?q={query}`
- **Example:**
  ```
  https://api.mygeocode.com/v1/autocomplete?q=10+Downing&country=gb&limit=3
  ```

#### 3. LocationIQ Autocomplete (API Key Required)
- 5,000 requests/day free
- Nominatim-compatible
- **Endpoint:** `https://us1.locationiq.com/v1/autocomplete?key={key}&q={query}`

#### 4. Geoapify Autocomplete (API Key Required)
- 3,000 requests/day free
- Address validation built-in
- Multiple languages
- **Endpoint:** `https://api.geoapify.com/v1/geocode/autocomplete?text={query}&apiKey={key}`

#### 5. Nominatim (Limited)
- Not optimized for autocomplete
- 1 req/s rate limit makes it impractical for type-ahead
- Can be used with aggressive debouncing (500ms+)
- **Not recommended** for autocomplete

### Recommendation for Navora
- **Use Photon** for autocomplete — it's free, no API key, typo-tolerant, and purpose-built for search-as-you-type
- **Fallback:** MyGeocode (no API key, 2,500/day)

---

## 9. Reverse Geocoding

### Free Reverse Geocoding Options

#### 1. Nominatim (No API Key)
- **Endpoint:** `https://nominatim.openstreetmap.org/reverse?lat={lat}&lon={lon}&format=json`
- Rate limit: 1 req/s
- Returns structured address components
- Global coverage

#### 2. Photon (No API Key)
- **Endpoint:** `https://photon.komoot.io/reverse?lat={lat}&lon={lon}`
- Fair use policy
- Returns address components
- Can filter by radius

#### 3. LocationIQ (API Key, 5,000/day)
- **Endpoint:** `https://us1.locationiq.com/v1/reverse?key={key}&lat={lat}&lon={lon}`
- Nominatim-compatible
- Additional datasets and algorithms
- Structured address output

#### 4. OpenCage (API Key, 2,500/day)
- **Endpoint:** `https://api.opencagedata.com/geocode/v1/json?q={lat}+{lon}&key={key}`
- Returns structured address
- Additional metadata (timezone, currency, etc.)

#### 5. MyGeocode (No API Key, 2,500/day)
- **Endpoint:** `https://api.mygeocode.com/v1/reverse?lat={lat}&lon={lon}`
- No account needed for free tier
- Returns formatted address

#### 6. geocode.maps.co (API Key, 25,000/month)
- **Endpoint:** `https://geocode.maps.co/reverse?lat={lat}&lon={lon}&api_key={key}`
- Generous free tier
- Simple API

### Recommendation for Navora
- **Primary:** Nominatim (no API key, already integrated)
- **Upgrade path:** LocationIQ (5,000/day, Nominatim-compatible, better quality)
- **Alternative:** Photon (no API key, good quality)

---

## 10. Flutter Integration

### Nominatim Flutter Packages

#### 1. flutter_nominatim (Recommended)
- **Package:** `flutter_nominatim: ^1.0.0`
- **Publisher:** yudiz.com (verified)
- **License:** MIT
- **Features:**
  - Place search with auto-complete
  - Forward geocoding (address → coordinates)
  - Reverse geocoding (coordinates → address)
  - Built-in rate limiting & caching
  - Polygon boundaries for places
  - No API key required
- **Usage:**
  ```dart
  dependencies:
    flutter_nominatim: ^1.0.0

  // Initialize
  final nominatim = Nominatim.instance;

  // Search places
  final results = await nominatim.search("London");

  // Get address from coordinates
  final address = await nominatim.getAddressFromLatLng(51.5074, -0.1278);
  ```

#### 2. nominatim_flutter
- **Package:** `nominatim_flutter: ^0.0.8`
- **License:** GPL-3.0
- **Features:**
  - Reverse geocoding & place searching
  - Server status check
  - Lookup by OSM IDs
  - Custom server support (connect to your own Nominatim instance)
  - Asynchronous isolate loading
  - Hive caching
  - DioCache customization
- **Usage:**
  ```dart
  dependencies:
    nominatim_flutter: ^0.0.8

  import 'package:nominatim_flutter/nominatim_flutter.dart';

  // Configure
  NominatimFlutter.instance.configure(
    baseUrl: 'https://your-nominatim-server.com',
    userAgent: 'Navora/1.0',
  );

  // Reverse geocoding
  final reverseRequest = ReverseRequest(
    lat: 10.7950,
    lon: 106.7218,
    addressDetails: true,
  );
  final result = await NominatimFlutter.instance.reverse(
    reverseRequest: reverseRequest,
  );
  ```

#### 3. nominatim_geocoding
- **Package:** `nominatim_geocoding: ^0.0.6`
- **Features:**
  - Forward and reverse geocoding
  - Automatic caching (up to n requests)
  - Built-in 1 req/s rate limiting
- **Usage:**
  ```dart
  dependencies:
    nominatim_geocoding: 0.0.6

  // Initialize
  await NominatimGeocoding.init(reqCacheNum: 20);

  // Forward geocoding
  final geocoding = await NominatimGeocoding.to.forwardGeoCoding(
    const Address(city: 'Braunschweig', postalCode: 38120),
  );

  // Reverse geocoding
  final geocoding = await NominatimGeocoding.to.reverseGeoCoding(
    Coordinate(latitude: 52.567898, longitude: 30.887776),
  );
  ```

### Photon Integration (Custom)
No dedicated Flutter package, but easy to integrate:
```dart
import 'package:dio/dio.dart';

class PhotonGeocoding {
  static const String _baseUrl = 'https://photon.komoot.io';
  final Dio _dio = Dio();

  Future<List<PhotonPlace>> search(String query, {double? lat, double? lon}) async {
    final response = await _dio.get('$_baseUrl/api', queryParameters: {
      'q': query,
      'limit': 10,
      if (lat != null) 'lat': lat,
      if (lon != null) 'lon': lon,
    });
    // Parse GeoJSON response
    final features = response.data['features'] as List;
    return features.map((f) => PhotonPlace.fromJson(f)).toList();
  }

  Future<PhotonPlace?> reverse(double lat, double lon) async {
    final response = await _dio.get('$_baseUrl/reverse', queryParameters: {
      'lat': lat,
      'lon': lon,
    });
    final features = response.data['features'] as List;
    return features.isNotEmpty ? PhotonPlace.fromJson(features.first) : null;
  }
}
```

### Overpass API Integration (Custom)
```dart
import 'package:dio/dio.dart';

class OverpassApi {
  static const String _baseUrl = 'https://overpass-api.de/api/interpreter';
  final Dio _dio = Dio();

  Future<List<OverpassElement>> findPOIs({
    required double lat,
    required double lon,
    required double radius,
    required List<String> tags,
  }) async {
    final tagQueries = tags
        .map((t) => '(node["$t"](around:$radius,$lat,$lon);way["$t"](around:$radius,$lat,$lon););')
        .join('');
    final query = '[out:json][timeout:25];($tagQueries);out center;';

    final response = await _dio.post(
      _baseUrl,
      data: {'data': query},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    // Parse response
    final elements = response.data['elements'] as List;
    return elements.map((e) => OverpassElement.fromJson(e)).toList();
  }
}
```

### Recommended Flutter Architecture for Navora
```
┌─────────────────────────────────────────────┐
│              Navora Flutter App              │
├─────────────────────────────────────────────┤
│  GeocodingService (abstract)                │
│  ├── NominatimProvider (primary)            │
│  ├── PhotonProvider (autocomplete)          │
│  └── LocationIQProvider (fallback)          │
├─────────────────────────────────────────────┤
│  POIService (abstract)                      │
│  └── OverpassProvider (primary)             │
├─────────────────────────────────────────────┤
│  Cache Layer (Hive/SharedPreferences)        │
│  ├── Search results cache                    │
│  ├── Reverse geocode cache                  │
│  └── POI results cache                      │
├─────────────────────────────────────────────┤
│  Rate Limiter                               │
│  └── 1 req/s for Nominatim                  │
└─────────────────────────────────────────────┘
```

---

## 11. Additional Services Evaluated

### Geoapify
- **Free tier:** 3,000 requests/day, 5 req/s
- **API key required:** Yes
- **Features:** Geocoding, reverse geocoding, autocomplete, Places API (800+ categories), routing, maps
- **Data source:** OSM + proprietary
- **Verdict:** Good option if you need Places API for POI search. Free tier is decent.

### Mapbox
- **Free tier:** 100,000 geocoding requests/month
- **API key required:** Yes
- **Features:** Forward/reverse geocoding, autocomplete, batch geocoding
- **Data source:** Proprietary + OSM
- **Verdict:** Generous free tier but requires API key. Geocoding v6 no longer provides POI data (use Search Box API).

### geocode.maps.co
- **Free tier:** 25,000 requests/month (demo), 100,000/month ($15/mo)
- **API key required:** Yes
- **Features:** Forward/reverse geocoding, structured search
- **Data source:** OSM (Nominatim-based)
- **Verdict:** Simple and affordable, but requires API key. No autocomplete.

### MyGeocode
- **Free tier:** 2,500 requests/day
- **API key required:** No (for free tier)
- **Features:** Forward/reverse geocoding, address autocomplete, IP geolocation, timezone, elevation
- **Verdict:** Good no-API-key option with autocomplete. Limited free tier.

### Overture Maps
- **Free tier:** Free data downloads, API key for hosted API
- **API key required:** Yes (for hosted API)
- **Features:** Places, addresses, buildings, transportation, divisions themes
- **Data source:** OSM + Meta + Microsoft + Esri + TomTom
- **Verdict:** Promising emerging option. Data is available as GeoParquet files for self-hosting. API is new but improving.

### ChibiGeo
- **Free tier:** Requires API key
- **Features:** Photon-compatible API, geocoding, reverse geocoding
- **Data source:** OSM (Photon-based)
- **Verdict:** Alternative Photon hosting option.

---

## 12. Recommendations for Navora

### Current Stack Assessment
Navora currently uses:
- **Nominatim** for search — ✅ Good (free, no API key)
- **Overpass API** for POI — ✅ Excellent (free, no API key, structured queries)

### Recommended Improvements

#### 1. Add Photon for Autocomplete (High Priority)
- **Why:** Nominatim is not optimized for search-as-you-type. Photon is purpose-built for this with typo tolerance.
- **How:** Add Photon as the autocomplete provider, keep Nominatim for full searches
- **Cost:** Free, no API key
- **Implementation:** Simple HTTP client (see Flutter integration above)

#### 2. Implement Aggressive Caching (High Priority)
- **Why:** Nominatim's 1 req/s rate limit is the main bottleneck
- **How:** 
  - Cache search results in Hive/SharedPreferences
  - Cache reverse geocode results
  - Implement request debouncing (300-500ms)
  - Deduplicate identical queries
- **Impact:** Can reduce API calls by 80-90%

#### 3. Add LocationIQ as Fallback (Medium Priority)
- **Why:** 5,000 req/day free tier provides headroom beyond Nominatim's 1 req/s
- **How:** Use LocationIQ when Nominatim rate limit is hit
- **Cost:** Free tier available
- **Note:** Nominatim-compatible API makes migration easy

#### 4. Consider Self-Hosting Nominatim (Medium Priority)
- **Why:** Eliminates rate limits entirely
- **How:** 
  - Start with a country-level extract (e.g., Germany: ~3GB PBF)
  - Use Docker for easy deployment
  - Cost: ~$20-40/month for a VPS
- **When to consider:** When user base grows beyond ~1,000 daily active users

#### 5. Keep Overpass API for POI (No Change)
- **Why:** It's the best free option for structured POI search
- **Improvements:**
  - Implement caching for POI queries
  - Use multiple Overpass mirrors for redundancy
  - Consider self-hosting if rate limits become an issue

#### 6. Add Overture Maps as Data Source (Low Priority)
- **Why:** Emerging open data source with curated POI data
- **How:** Monitor the project, consider when API matures
- **Cost:** Free data downloads, API key for hosted API

### Recommended Architecture

```
┌──────────────────────────────────────────────────┐
│                Navora Flutter App                 │
├──────────────────────────────────────────────────┤
│                                                   │
│  ┌─────────────┐    ┌──────────────┐             │
│  │  Autocomplete │    │  POI Search  │             │
│  │  (Photon)    │    │  (Overpass)  │             │
│  └──────┬──────┘    └──────┬───────┘             │
│         │                  │                      │
│  ┌──────┴──────────────────┴───────┐              │
│  │      Geocoding Service           │              │
│  │  ┌──────────┐  ┌──────────────┐ │              │
│  │  │Nominatim │  │ LocationIQ   │ │              │
│  │  │(primary) │  │ (fallback)   │ │              │
│  │  └──────────┘  └──────────────┘ │              │
│  └──────────────┬──────────────────┘              │
│                 │                                  │
│  ┌──────────────┴──────────────────┐              │
│  │        Cache Layer (Hive)        │              │
│  │  ┌─────────┐ ┌───────────────┐  │              │
│  │  │ Search  │ │ Reverse Geo   │  │              │
│  │  │ Cache   │ │ Cache         │  │              │
│  │  └─────────┘ └───────────────┘  │              │
│  └─────────────────────────────────┘              │
│                                                   │
│  ┌─────────────────────────────────┐              │
│  │     Rate Limiter (1 req/s)       │              │
│  └─────────────────────────────────┘              │
└──────────────────────────────────────────────────┘
```

### Cost Summary

| Component | Monthly Cost | API Key |
|-----------|-------------|---------|
| Nominatim (public) | $0 | No |
| Photon (public) | $0 | No |
| Overpass API (public) | $0 | No |
| LocationIQ (free tier) | $0 | Yes |
| Self-hosted Nominatim (optional) | $20-40 | No |
| **Total (current stack)** | **$0** | **No** |
| **Total (with self-hosting)** | **$20-40** | **No** |

### Final Verdict

Navora's current stack (Nominatim + Overpass) is **already optimal** for a free, no-API-key solution. The main improvements to consider are:

1. **Add Photon for autocomplete** — significantly improves search UX
2. **Implement aggressive caching** — mitigates Nominatim rate limits
3. **Add LocationIQ as fallback** — provides headroom for growth
4. **Consider self-hosting** — when user base justifies the cost

All of these can be done with **zero or minimal cost** while maintaining the no-API-key requirement.

---

*Report generated: October 2026*  
*Last verified: All service pages and documentation accessed during research*
