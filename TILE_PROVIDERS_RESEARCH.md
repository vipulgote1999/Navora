# Free Map Tile Providers Research Report

**Project:** Navora (TripMesh) — Flutter app using `flutter_map`  
**Date:** October 2026  
**Goal:** Replace Google Maps tiles with free alternatives — **no API key required**

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [OpenStreetMap (OSM) Standard Tiles](#1-openstreetmap-osm-standard-tiles)
3. [Free Tile Providers (No API Key Required)](#2-free-tile-providers-no-api-key-required)
   - 3.1 [CARTO Basemaps](#31-carto-basemaps)
   - 3.2 [OpenFreeMap](#32-openfreemap)
   - 3.3 [Esri World Imagery & Basemaps](#33-esri-world-imagery--basemaps)
   - 3.4 [Stadia Maps](#34-stadia-maps)
   - 3.5 [MapTiler](#35-maptiler)
   - 3.6 [Thunderforest](#36-thunderforest)
   - 3.7 [Maptoolkit.org](#37-maptoolkitorg)
   - 3.8 [Protomaps](#38-protomaps)
   - 3.9 [VersaTiles](#39-versatiles)
   - 3.10 [LFMaps](#310-lfmaps)
   - 3.11 [MIERUNE](#311-mierune)
   - 3.12 [Mella Dark Basemap](#312-mella-dark-basemap)
4. [Vector Tiles vs Raster Tiles](#4-vector-tiles-vs-raster-tiles)
5. [Self-Hosted Tile Options](#5-self-hosted-tile-options)
6. [Tile Caching Strategies for Flutter](#6-tile-caching-strategies-for-flutter)
7. [Dark Mode Tiles](#7-dark-mode-tiles)
8. [Satellite Imagery](#8-satellite-imagery)
9. [Comparison Matrix](#comparison-matrix)
10. [Recommendations for Navora](#recommendations-for-navora)

---

## Executive Summary

For Navora's use case (Flutter app with `flutter_map`, no API key), the top recommendations are:

| Rank | Provider | Type | API Key | Free Limits | Best For |
|------|----------|------|---------|-------------|----------|
| 1 | **OpenFreeMap** | Vector | None | Unlimited | Primary basemap (vector) |
| 2 | **CARTO Basemaps** | Raster + Vector | Free key (email only) | 1M-5M req/month | Raster tiles, dark mode |
| 3 | **OSM Standard** | Raster | None | Fair use (no hard limit) | Simple raster replacement |
| 4 | **EOxCloudless** | Raster (satellite) | None | Free (non-commercial) | Satellite imagery |
| 5 | **Esri World Imagery** | Raster (satellite) | None | Free (non-commercial) | High-res satellite |
| 6 | **Maptoolkit.org** | Vector | None | Unlimited | Vector + outdoor styles |
| 7 | **Protomaps** | Vector | None | 1M req/month (free tier) | Self-hostable vector |

---

## 1. OpenStreetMap (OSM) Standard Tiles

### Endpoint
```
https://tile.openstreetmap.org/{z}/{x}/{y}.png
```

### Usage Policy Highlights

- **No hard request limit** — but governed by a "fair use" policy
- **No API key required**
- **Attribution required**: `© OpenStreetMap contributors`
- **Valid User-Agent required** — must identify your app (e.g., `Navora/1.0`)
- **Caching required** — must honor HTTP caching headers or cache for at least 7 days
- **No bulk downloading** — prefetching, offline tile scraping, and "download area" features are **prohibited**
- **No SLA** — best-effort service, access can be blocked without notice
- **HTTPS only** — must use `https://` URLs
- **No-cache headers prohibited** — must not send `Cache-Control: no-cache` or `Pragma: no-cache`

### Key Restrictions

| Rule | Details |
|------|---------|
| User-Agent | Must be valid and identify your app |
| Caching | Honor HTTP headers or cache ≥ 7 days |
| Bulk download | **Prohibited** — no prefetching, no offline scraping |
| Offline use | **Not permitted** on `tile.openstreetmap.org` |
| Rate limiting | No published limit, but heavy use gets blocked |
| Commercial use | Allowed, but access may be withdrawn at any time |

### Performance

- Global CDN (Fastly) with ~97% edge cache hit ratio
- Peak load: ~70,000 requests/second
- Individual render servers have >95% local cache hit ratio
- HTTP/2 and HTTP/3 supported

### Flutter Compatibility

- Works with `flutter_map` via `TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png')`
- Must set `userAgentPackageName` parameter
- Built-in caching (v8.2+) helps comply with OSM caching requirements

### Verdict for Navora

✅ **Good as a simple raster replacement** — but the no-offline and no-prefetch rules are significant limitations for a trip planning app. The fair-use policy means you could be blocked if the app becomes popular.

---

## 2. Free Tile Providers (No API Key Required)

### 2.1 CARTO Basemaps

#### Endpoints

**Raster tiles:**
```
https://{s}.basemaps.cartocdn.com/{style}/{z}/{x}/{y}{r}.png
```
Where `{s}` = `a`|`b`|`c`|`d` and `{style}` = `light_all` | `dark_all` | `voyager` | `voyager_labels_under` | `voyager_nolabels` | `light_nolabels` | `dark_nolabels`

**Vector tiles:**
```
https://{s}.basemaps.cartocdn.com/vectortiles/{style}/{z}/{x}/{y}.mvt
```

#### Free Tier Details

| Plan | Requests/Month | Cost | Use Case |
|------|---------------|------|----------|
| Non-commercial | 5,000,000 | Free | Personal, research, teaching, non-profits |
| Commercial | 1,000,000 | Free | Business use |
| Commercial | 10,000,000 | $500/month | — |
| Commercial Plus | 50,000,000 | $1,500/month | — |

#### API Key

- **Free API key required** — obtained via email registration (no account, no credit card)
- Key is appended to tile URLs: `?apikey=YOUR_KEY`
- Without key, a watermark appears on tiles
- Keys registered before Sept 2026 keep working under old terms until Nov 2026

#### Terms of Service Highlights

- Attribution required: CARTO and OpenStreetMap must be credited
- Keys are per-customer and must not be shared across unrelated projects
- Requests counted across all keys and both raster + vector services
- Calendar months in UTC
- Automated rate-limiting above limits

#### Styles Available

- `light_all` / `light_nolabels` — Positron (light)
- `dark_all` / `dark_nolabels` — Dark Matter
- `voyager` / `voyager_labels_under` / `voyager_nolabels` — Voyager (colorful)

#### Quality/Coverage

- Based on OpenStreetMap data
- Global coverage
- Updated at least once per year (usually every 3-6 months)
- Served from global CDN

#### Flutter Compatibility

- ✅ Raster tiles work directly with `flutter_map` `TileLayer`
- ✅ Vector tiles work with `flutter_map_maplibre` plugin
- ✅ Well-known, stable service

#### Verdict for Navora

✅ **Excellent choice** — generous free tier (1M requests/month commercial), multiple styles including dark mode, both raster and vector. The only friction is needing a free API key (email registration).

---

### 2.2 OpenFreeMap

#### Endpoints

**Vector tiles:**
```
https://tiles.openfreemap.org/planet/latest/{z}/{x}/{y}.pbf
```

**Styles:**
```
https://tiles.openfreemap.org/styles/liberty
https://tiles.openfreemap.org/styles/positron
https://tiles.openfreemap.org/styles/bright
https://tiles.openfreemap.org/styles/dark
https://tiles.openfreemap.org/styles/fiord
```

#### Free Tier Details

| Feature | Details |
|---------|---------|
| **Cost** | Completely free |
| **API Key** | **None required** |
| **Registration** | None |
| **Request limits** | **Unlimited** |
| **Map views** | Unlimited |

#### Terms of Service Highlights

- Funded by donations — no SLA guarantees
- No registration, no user database, no cookies
- Attribution: `OpenFreeMap © OpenMapTiles – Data from OpenStreetMap`
- Commercial use allowed (no explicit restriction)
- No personalized support on free tier

#### Quality/Coverage

- Based on OpenStreetMap data via OpenMapTiles schema
- Global coverage
- Weekly updates
- Served from dedicated servers (not cloud) with Round-Robin DNS
- Production basemap service of MapHub since June 2024

#### Styles Available

| Style | Description |
|-------|-------------|
| Liberty | Based on OSM Liberty (detailed) |
| Positron | Light, minimal |
| Bright | Colorful, modern |
| Dark | Dark mode |
| Fiord Color | Muted, professional |

#### Flutter Compatibility

- ✅ Vector tiles — requires `flutter_map_maplibre` or `flutter-maplibre-gl` package
- ❌ Raster tiles — **not provided** (vector only)
- ✅ Style URLs work with MapLibre GL

#### Verdict for Navora

✅ **Top recommendation for vector tiles** — truly free, no key, no limits, weekly updates, dark mode style available. Best choice if you're willing to use vector tiles via MapLibre.

---

### 2.3 Esri World Imagery & Basemaps

#### Endpoints

**World Imagery (satellite):**
```
https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}
```

**World Street Map:**
```
https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}
```

**World Topographic:**
```
https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}
```

**Vector Basemap (no key):**
```
https://basemaps.arcgis.com/arcgis/rest/services/World_Basemap_v2/VectorTileServer/tile/{z}/{y}/{x}.pbf
```

#### Free Tier Details

| Feature | Details |
|---------|---------|
| **Cost** | Free |
| **API Key** | **None required** for direct tile access |
| **Request limits** | Not published (fair use) |

#### Terms of Service Highlights

- Free for **non-commercial use** only
- Commercial use requires ArcGIS Online organizational subscription or ArcGIS Enterprise license
- Attribution required: Esri + data providers (Maxar, Earthstar Geographics, USGS, etc.)
- No SLA guarantees
- Service may be discontinued at any time

#### Quality/Coverage

- **World Imagery**: 0.3m resolution (select cities), 0.5m (US + Western Europe), 1m (rest of world), 15m (global small-scale)
- **World Street Map**: Global, updated regularly
- **World Topographic**: Global, updated regularly
- High-quality, professional cartography

#### Flutter Compatibility

- ✅ Raster tiles work with `flutter_map` `TileLayer`
- ✅ Vector basemap works with MapLibre
- ⚠️ Non-commercial only — **not suitable if Navora is commercial**

#### Verdict for Navora

⚠️ **Only for non-commercial use** — if Navora is a commercial product, Esri tiles are not legally usable. For non-commercial/prototype use, the quality is excellent.

---

### 2.4 Stadia Maps

#### Endpoints

**Raster tiles:**
```
https://tiles.stadiamaps.com/tiles/{style}/{z}/{x}/{y}{r}.png?api_key=YOUR_KEY
```

**Vector tiles:**
```
https://tiles.stadiamaps.com/data/{style}/{z}/{x}/{y}.pbf?api_key=YOUR_KEY
```

#### Free Tier Details

| Feature | Details |
|---------|---------|
| **Cost** | Free |
| **API Key** | **Required** (free, no credit card) |
| **Credits** | 200,000/month |
| **Tile cost** | 1 credit/tile (standard), 4 credits/tile (satellite) |
| **Commercial use** | **Not allowed** on free plan |

#### Terms of Service Highlights

- Free plan for development, evaluation, and non-commercial use only
- Commercial use requires paid subscription ($20/month+)
- No credit card required for free tier
- Hard limit at 200,000 credits — returns HTTP 429 until next cycle
- No fixed requests-per-second limit for registered keys
- 14-day trial of Professional plan on every new account

#### Styles Available

- Alidade Smooth (light)
- Alidade Smooth Dark (dark mode)
- Alidade Satellite (satellite + vector overlay)
- Stamen Toner (minimalist)
- Stamen Watercolor (artistic)
- Stamen Terrain (topographic)
- OpenStreetMap (standard)

#### Quality/Coverage

- Based on OpenStreetMap data
- Global coverage
- High-quality cartography
- Regular updates

#### Flutter Compatibility

- ✅ Raster tiles work with `flutter_map`
- ✅ Vector tiles work with MapLibre
- ⚠️ API key required (free but mandatory)
- ⚠️ Commercial use not allowed on free plan

#### Verdict for Navora

⚠️ **Not recommended for commercial use** — the free plan explicitly prohibits commercial use. If Navora is non-commercial, it's a solid option with good styles including dark mode.

---

### 2.5 MapTiler

#### Endpoints

**Raster tiles:**
```
https://api.maptiler.com/maps/{style}/{z}/{x}/{y}{r}.png?key=YOUR_KEY
```

**Vector tiles:**
```
https://api.maptiler.com/tiles/{tileset}/{z}/{x}/{y}.pbf?key=YOUR_KEY
```

#### Free Tier Details

| Feature | Details |
|---------|---------|
| **Cost** | Free |
| **API Key** | **Required** (free) |
| **API requests** | 100,000/month |
| **Sessions** | 5,000/month |
| **Custom styles** | 5 |
| **Storage** | 5 GB |

#### Terms of Service Highlights

- Free plan for non-commercial use and R&D for commercial products
- API key always required
- Attribution required
- Bulk downloading prohibited
- Service pauses when free limit reached
- End-user device caching allowed

#### Styles Available

- Streets
- Satellite
- Hybrid (satellite + labels)
- Terrain
- Basic
- Bright
- Positron (light)
- Dark Matter (dark mode)
- Fiord Color
- Toner
- OpenStreetMap
- Winter
- Outdoor

#### Quality/Coverage

- Based on OpenStreetMap + other data sources
- Global coverage
- High-quality, professional cartography
- Regular updates

#### Flutter Compatibility

- ✅ Raster tiles work with `flutter_map`
- ✅ Vector tiles work with MapLibre
- ⚠️ API key required
- ⚠️ Free plan is non-commercial only

#### Verdict for Navora

⚠️ **Not recommended for commercial use** — free plan is non-commercial only. API key required. Good style variety including dark mode.

---

### 2.6 Thunderforest

#### Endpoints

**Raster tiles:**
```
https://tile.thunderforest.com/{style}/{z}/{x}/{y}.png?apikey=YOUR_KEY
```

#### Free Tier Details

| Feature | Details |
|---------|---------|
| **Cost** | Free |
| **API Key** | **Required** (free) |
| **Tile requests** | 150,000/month |
| **Commercial use** | Allowed (with paid plan) |

#### Terms of Service Highlights

- Free "Hobby Project" plan for testing
- Tiles may be cached in-browser and on-device for offline use
- Apps may retain tiles beyond HTTP Expiry date
- Free plan can be modified or withdrawn at any time
- Paid plans start at $125/month (1.5M requests)

#### Styles Available

- OpenCycleMap
- Transport
- Transport Dark (dark mode)
- Landscape
- Outdoors
- Pioneer
- Mobile Atlas
- Neighbourhood
- Atlas

#### Quality/Coverage

- Based on OpenStreetMap data
- Global coverage
- Specialized styles (cycling, transport, outdoors)
- Regular updates

#### Flutter Compatibility

- ✅ Raster tiles work with `flutter_map`
- ✅ Vector tiles available (count as 10 raster requests)
- ⚠️ API key required
- ⚠️ Very low free tier (150K/month)

#### Verdict for Navora

⚠️ **Not recommended** — API key required, very low free tier (150K/month), and the free plan is for testing only. The offline caching permission is nice but the quota is too low for production.

---

### 2.7 Maptoolkit.org

#### Endpoints

**Vector tiles (MapLibre style URL):**
```
https://www.maptoolkit.org/style/{style}/style.json
```

**Raster tiles (via MapLibre rendering):**
```
https://www.maptoolkit.org/tiles/{style}/{z}/{x}/{y}.png
```

#### Free Tier Details

| Feature | Details |
|---------|---------|
| **Cost** | Free |
| **API Key** | **None required** |
| **Request limits** | **Unlimited** |
| **Commercial use** | Allowed (< €1M/year revenue, < 10 FTE) |

#### Terms of Service Highlights

- Free under Maptoolkit Community License
- Commercial use allowed for small companies (< €1M annual revenue, < 10 FTE employees)
- Attribution required: © Maptoolkit © OpenStreetmap + logo
- No SLA, best-effort service
- Larger projects need Enterprise License

#### Styles Available

- Summer (general purpose)
- Light (low-contrast, for data overlays)
- Dark (dark mode)
- Street
- Hiking (outdoor with hillshading)
- Cycling (bike routes)
- Winter (ski runs, lifts)

#### Quality/Coverage

- Based on OpenStreetMap data
- Global coverage
- Weekly updates
- Includes hillshading, contour lines, water depths
- 3D terrain support
- Max zoom: 15

#### Flutter Compatibility

- ✅ Vector tiles work with MapLibre (`flutter-maplibre-gl`)
- ✅ Raster tiles work with `flutter_map`
- ✅ No API key needed
- ✅ Commercial use allowed (small companies)

#### Verdict for Navora

✅ **Excellent choice** — no API key, unlimited requests, commercial use allowed for small companies, multiple styles including dark mode and outdoor styles. Great for a trip planning app.

---

### 2.8 Protomaps

#### Endpoints

**Vector tiles (PMTiles):**
```
https://protomaps.github.io/PMTiles/protomaps(vector_v3/{z}/{x}/{y}.mvt
```

**Raster tiles (via MapLibre):**
```
https://tiles.protomaps.com/protomaps_vector_v3/{z}/{x}/{y}.png
```

#### Free Tier Details

| Feature | Details |
|---------|---------|
| **Cost** | Free |
| **API Key** | **None required** for self-hosted |
| **Request limits** | 1M tile requests/month (hosted API) |
| **Commercial use** | Allowed (downloads only) |

#### Terms of Service Highlights
- Free for non-commercial use
- Commercial use requires paid plan
- Self-hosting is free (download PMTiles and host yourself)
- Attribution: © Protomaps © OpenStreetMap
- No SLA on free tier

#### Styles Available

- Light
- Dark
- White
- Grayscale
- Black

#### Quality/Coverage

- Based on OpenStreetMap data
- Global coverage
- Daily updates (API)
- Max zoom: 15

#### Flutter Compatibility

- ✅ Vector tiles work with MapLibre + PMTiles
- ✅ Self-hosting option eliminates request limits
- ⚠️ Hosted API has 1M request limit

#### Verdict for Navora

✅ **Good for self-hosting** — if you download PMTiles and host them yourself, there are no limits. The hosted API has a 1M/month limit. Dark mode available.

---

### 2.9 VersaTiles

#### Endpoints

**Vector tiles:**
```
https://tiles.versatiles.org/versatiles/shortbread_v1/{z}/{x}/{y}.pbf
```

**Raster tiles:**
```
https://tiles.versatiles.org/versatiles/shortbread_v1/{z}/{x}/{y}.png
```

#### Free Tier Details

| Feature | Details |
|---------|---------|
| **Cost** | Free |
| **API Key** | **None required** |
| **Request limits** | **Unlimited** |
| **Commercial use** | Allowed |

#### Terms of Service Highlights
- Completely free, no restrictions
- Attribution: © OpenStreetMap contributors
- No SLA
- Data updates several times per year

#### Styles Available

- Colorful
- Eclipse (dark mode)
- Graybeard (grayscale)
- Shadow
- Neutrino

#### Quality/Coverage

- Based on OpenStreetMap data (Shortbread schema)
- Global coverage
- Max zoom: 14
- Updates several times per year

#### Flutter Compatibility

- ✅ Vector tiles work with MapLibre
- ✅ Raster tiles work with `flutter_map`
- ✅ No API key needed
- ✅ Unlimited requests

#### Verdict for Navora

✅ **Good option** — no API key, unlimited requests, dark mode available. Lower max zoom (14) and less frequent updates are minor drawbacks.

---

### 2.10 LFMaps

#### Endpoints

**Vector tiles (MapLibre style URL):**
```
https://lfmaps.fr/en/style.json
```

#### Free Tier Details

| Feature | Details |
|---------|---------|
| **Cost** | Free |
| **API Key** | **None required** |
| **Request limits** | **Unlimited** |
| **Commercial use** | Allowed |

#### Terms of Service Highlights
- Completely free, no paid tier
- No API key, no signup, no tracking
- No quotas or hard rate limits
- Only asks: don't bulk-scrape the entire tile set
- Attribution: OpenStreetMap attribution visible
- Data sourced from OpenStreetMap via OpenFreeMap

#### Quality/Coverage

- Based on OpenStreetMap data (via OpenFreeMap)
- Global coverage
- Powered by OpenFreeMap infrastructure

#### Flutter Compatibility

- ✅ Vector tiles work with MapLibre
- ✅ No API key needed
- ✅ Unlimited requests

#### Verdict for Navora

✅ **Good option** — truly free, no key, unlimited. Essentially a proxy for OpenFreeMap with a simpler interface. Commercial use allowed.

---

### 2.11 MIERUNE

#### Endpoints

**Raster tiles:**
```
https://tile.mierune.co.jp/mierune/{style}/{z}/{x}/{y}.png
```

#### Free Tier Details

| Feature | Details |
|---------|---------|
| **Cost** | Free |
| **API Key** | **None required** |
| **Request limits** | Not published |
| **Commercial use** | Allowed |

#### Terms of Service Highlights
- Free with no API key
- Attribution: MIERUNE, OpenMapTiles, OpenStreetMap
- Service may change or stop without notice
- Based in Japan

#### Styles Available

- Color (minimal line map, deep teal)
- Mono (black and white)

#### Quality/Coverage

- Based on OpenStreetMap data (OpenMapTiles)
- Global coverage
- Minimal, clean aesthetic
- No labels

#### Flutter Compatibility

- ✅ Raster tiles work with `flutter_map`
- ✅ No API key needed

#### Verdict for Navora

✅ **Good for minimal aesthetics** — no API key, free, unique minimal style. No labels might be a limitation for navigation use case.

---

### 2.12 Mella Dark Basemap

#### Endpoints

**Raster tiles:**
```
https://basemap.queeniemella.cc/tiles/countries/{z}/{x}/{y}.png
```

#### Free Tier Details

| Feature | Details |
|---------|---------|
| **Cost** | Free |
| **API Key** | **None required** |
| **Request limits** | **None** |
| **Commercial use** | Allowed (MIT license) |

#### Terms of Service Highlights
- Open source under MIT license
- No key, no signup, no tracking, no quota
- Attribution: © queeniemella.cc | © OpenStreetMap contributors
- Self-hostable (QGIS Server setup on GitHub)

#### Quality/Coverage

- Based on OpenStreetMap data
- Global coverage
- Zoom 0-20
- 256px PNG
- Dark, stylish cartography

#### Flutter Compatibility

- ✅ Raster tiles work with `flutter_map`
- ✅ No API key needed
- ✅ Dark mode by default

#### Verdict for Navora

✅ **Great for dark mode** — completely free, no key, no limits, MIT licensed, beautiful dark cartography. Single style only.

---

## 3. Vector Tiles vs Raster Tiles

### Overview

| Aspect | Raster Tiles | Vector Tiles |
|--------|-------------|--------------|
| Format | PNG/JPG/WebP images | .pbf (Protocol Buffers) |
| Rendering | Pre-rendered on server | Rendered on client device |
| Theming | Fixed style | Dynamic theming (dark mode, custom) |
| Sharpness | Fixed resolution | Scales without loss |
| File size | Larger | Smaller (~20-50% smaller) |
| Offline | Harder to cache | Easier (single file with PMTiles) |
| flutter_map support | ✅ Native | ⚠️ Via plugin |
| GPU acceleration | No | Yes (MapLibre native) |

### Can We Use Free Vector Tiles?

**Yes!** Several providers offer free vector tiles:

| Provider | Vector Tiles | API Key | Limits |
|---------|-------------|---------|--------|
| OpenFreeMap | ✅ | None | Unlimited |
| Maptoolkit.org | ✅ | None | Unlimited |
| VersaTiles | ✅ | None | Unlimited |
| LFMaps | ✅ | None | Unlimited |
| CARTO | ✅ | Free key | 1M-5M/month |
| Protomaps | ✅ | None | 1M/month (hosted) |
| Esri | ✅ | None | Fair use |

### flutter_map Vector Tile Support

- **flutter_map** does NOT natively support vector tiles
- **Option 1:** Use `flutter_map_maplibre` plugin — adds MapLibre as a layer within flutter_map
- **Option 2:** Use `flutter-maplibre-gl` package — full MapLibre native rendering with Flutter widget support
- **Option 3:** Use `vector_map_tiles` plugin — community-maintained vector tile renderer for flutter_map

### Recommendation for Navora

For the best experience:
- **Use vector tiles** if you want dark mode, smooth animations, and smaller tile sizes
- **Use raster tiles** if you want simplicity and native flutter_map support
- **Hybrid approach:** Use raster tiles for simplicity, with dark mode from CARTO or Mella

---

## 4. Self-Hosted Tile Options

### Can We Self-Host OSM Tiles for Free?

**Yes!** Self-hosting eliminates all usage limits and API key requirements. The trade-off is server costs and maintenance effort.

### Software Options

#### 4.1 TileServer GL

- **License:** BSD-3-Clause
- **GitHub:** https://github.com/maptiler/tileserver-gl
- **Stars:** 2,800+
- **Technology:** Node.js / Docker
- **Features:**
  - Serves vector tiles (.pbf) and raster tiles (PNG/JPG/WebP)
  - Server-side raster rendering from vector tiles
  - WMTS endpoint
  - TileJSON endpoint
  - Pre-configured styles
  - Docker support

**Setup:**
```bash
docker run --rm -it -v $(pwd):/data -p 8080:8080 maptiler/tileserver-gl
```

**Requirements:**
- MBTiles file (from OpenMapTiles or generated)
- ~300 GB disk for full planet (vector)
- ~500 GB SSD + 64 GB RAM for tile generation

#### 4.2 OpenMapTiles

- **License:** BSD (code), CC-BY (cartography)
- **GitHub:** https://github.com/openmaptiles/openmaptiles
- **Technology:** Docker, PostgreSQL/PostGIS
- **Features:**
  - Open tile schema based on OSM
  - Generates MBTiles from OSM data
  - Multiple styles (OSM Bright, Positron, Dark Matter, etc.)
  - Extensible layers

**Workflow:**
1. Download OSM data (Geofabrik extracts)
2. Import to PostgreSQL with OpenMapTiles tools
3. Generate MBTiles
4. Serve with TileServer GL

**Requirements:**
- Docker
- PostgreSQL with PostGIS
- Powerful CPU + fast SSD for generation
- Can take days for full planet

#### 4.3 OpenFreeMap Self-Hosting

- **GitHub:** https://github.com/hyperknot/openfreemap
- **Technology:** Python, Fabric, nginx, Btrfs
- **Features:**
  - Full planet vector tiles as Btrfs images
  - Weekly auto-updates
  - nginx serving from Btrfs partition (no tile server needed)
  - 300M+ hard-linked files

**Requirements:**
- Ubuntu 22.04+ server
- 300 GB SSD (for http-host)
- 500 GB SSD + 64 GB RAM (for tile generation, optional)
- ~€4.5/month (Contabo Storage VPS)

#### 4.4 PMTiles (Single File Hosting)

- **Format:** Single file containing all tiles
- **Hosting:** Any static file server (S3, Cloudflare R2, nginx)
- **No tile server needed** — HTTP range requests
- **Compatible with:** MapLibre GL, MapLibre Flutter

### Self-Hosting Cost Estimate

| Component | Cost |
|-----------|------|
| Server (300 GB SSD) | ~€4.5-10/month |
| Bandwidth | ~€5-20/month (depends on usage) |
| Domain (optional) | ~€10/year |
| **Total** | **~€10-30/month** |

### Verdict for Navora

✅ **Self-hosting is viable** if:
- You expect high usage (100K+ users)
- You want zero API key dependencies
- You need offline tile support
- You have DevOps capacity

❌ **Not worth it** if:
- You have low-to-moderate usage
- You want minimal maintenance
- Free tiers from providers are sufficient

---

## 5. Tile Caching Strategies for Flutter

### flutter_map Built-in Caching (v8.2+)

Since flutter_map v8.2.0, **built-in caching is automatically enabled** on non-web platforms:

```dart
TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  userAgentPackageName: 'com.yourapp.navora',
  tileProvider: NetworkTileProvider(
    cachingProvider: BuiltInMapCachingProvider.getOrCreateInstance(
      maxCacheSize: 1_000_000_000, // 1 GB default
    ),
  ),
);
```

**Features:**
- ✅ Automatic — no code changes needed
- ✅ Uses HTTP headers to determine freshness
- ✅ 1 GB default cache size (configurable)
- ✅ Reduces network requests and costs
- ✅ Improves tile loading speed
- ✅ Complies with OSM caching requirements
- ✅ No additional dependencies

**Configuration:**
```dart
// Custom cache size
BuiltInMapCachingProvider.getOrCreateInstance(
  maxCacheSize: 2_000_000_000, // 2 GB
)

// Override fresh age (ignore HTTP headers)
BuiltInMapCachingProvider.getOrCreateInstance(
  overrideFreshAge: Duration(days: 7),
)

// Custom cache directory
BuiltInMapCachingProvider.getOrCreateInstance(
  cacheDirectory: '/custom/path',
)
```

### Third-Party Caching Packages

| Package | License | Features |
|---------|---------|----------|
| `flutter_map_cache` | MIT | Lightweight, pre-built options |
| `flutter_map_tile_caching` | GPL | Advanced caching, bulk downloading |
| `cached_network_image` | MIT | General image caching |

### HTTP Client Caching

```dart
import 'package:http_cache_client/http_cache_client.dart';

TileLayer(
  urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
  subdomains: ['a', 'b', 'c', 'd'],
  tileProvider: NetworkTileProvider(
    httpClient: CacheClient(), // HTTP-level caching
  ),
);
```

### Caching Best Practices for Navora

1. **Use built-in caching** — enabled by default, no extra code needed
2. **Set appropriate cache size** — 1-2 GB for a trip planning app
3. **Honor HTTP headers** — default behavior, complies with OSM policy
4. **Use `userAgentPackageName`** — required by OSM, good practice
5. **Consider `overrideFreshAge`** — set to 7 days for OSM compliance
6. **Monitor cache hit ratio** — aim for >80% for popular areas

### Offline Maps

⚠️ **Important:** OSM's tile usage policy **prohibits** bulk downloading and offline use. If Navora needs offline maps:

- Use a provider that explicitly allows it (Thunderforest, self-hosted)
- Use vector tiles with PMTiles (single file, easier to bundle)
- Use `flutter_map_tile_caching` package (GPL licensed) for bulk downloading

---

## 6. Dark Mode Tiles

### Free Dark Mode Options (No API Key)

| Provider | Style | Type | Endpoint |
|----------|-------|------|----------|
| **CARTO** | Dark Matter | Raster | `https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png` |
| **CARTO** | Dark Matter (no labels) | Raster | `https://{s}.basemaps.cartocdn.com/dark_nolabels/{z}/{x}/{y}.png` |
| **OpenFreeMap** | Dark | Vector | `https://tiles.openfreemap.org/styles/dark` |
| **Maptoolkit.org** | Dark | Vector | `https://www.maptoolkit.org/style/dark/style.json` |
| **Maptoolkit.org** | Dark (with hillshading) | Vector | `https://www.maptoolkit.org/style/dark/style.json` |
| **Protomaps** | Dark | Vector | Via PMTiles |
| **VersaTiles** | Eclipse | Vector | `https://tiles.versatiles.org/versatiles/shortbread_v1/{z}/{x}/{y}.pbf` |
| **Mella** | Dark (default) | Raster | `https://basemap.queeniemella.cc/tiles/countries/{z}/{x}/{y}.png` |
| **Stadia Maps** | Alidade Smooth Dark | Raster | `https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}.png` |
| **MapTiler** | Dark Matter | Raster | `https://api.maptiler.com/maps/darkmatter/{z}/{x}/{y}.png` |

### Recommended Dark Mode Setup for Navora

**Option 1: Raster (Simplest)**
```dart
TileLayer(
  urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
  subdomains: ['a', 'b', 'c', 'd'],
  userAgentPackageName: 'com.navora.app',
  tileProvider: NetworkTileProvider(
    headers: {'apikey': 'YOUR_FREE_CARTO_KEY'},
  ),
);
```

**Option 2: Vector (Best Quality)**
```dart
// Using flutter-maplibre-gl
MapLibreMap(
  options: MapOptions(
    initStyle: 'https://tiles.openfreemap.org/styles/dark',
    initCenter: Geographic(lon: 0, lat: 0),
    initZoom: 3,
  ),
);
```

**Option 3: No API Key (Mella)**
```dart
TileLayer(
  urlTemplate: 'https://basemap.queeniemella.cc/tiles/countries/{z}/{x}/{y}.png',
  userAgentPackageName: 'com.navora.app',
);
```

---

## 7. Satellite Imagery

### Free Satellite Tile Sources (No API Key)

| Provider | Type | Resolution | Endpoint | License |
|----------|------|-----------|----------|---------|
| **EOxCloudless 2025** | Raster | 10m (Sentinel-2) | `https://tiles.maps.eox.at/wmts/1.0.0/s2cloudless-2025_3857/default/g/{z}/{y}/{x}.jpg` | CC BY-NC-SA 4.0 (non-commercial) |
| **Esri World Imagery** | Raster | 0.3m-15m | `https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}` | Non-commercial |
| **USGS Imagery** | Raster | Varies | Via USGS services | Public domain (US only) |

### EOxCloudless (Recommended)

- **Source:** Sentinel-2 cloud-free mosaic
- **Resolution:** 10m (Sentinel-2)
- **Coverage:** Global
- **Updates:** Annual (2016-2025 available)
- **License:** CC BY-NC-SA 4.0 (non-commercial), commercial license available
- **Attribution:** `EOxCloudless by EOX IT Services GmbH (Contains modified Copernicus Sentinel data 2025)`

**Endpoint:**
```
https://tiles.maps.eox.at/wmts/1.0.0/s2cloudless-2025_3857/default/g/{z}/{y}/{x}.jpg
```

### Esri World Imagery (High Resolution)

- **Resolution:** 0.3m (select cities), 0.5m (US + Western Europe), 1m (world), 15m (global small-scale)
- **Coverage:** Global
- **Updates:** Regular
- **License:** Non-commercial use only
- **Attribution:** Esri, Maxar, Earthstar Geographics, USGS, and the GIS User Community

**Endpoint:**
```
https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}
```

### Satellite with API Key (Free Tier)

| Provider | Free Tier | API Key |
|----------|-----------|---------|
| Stadia Maps | 200K credits/month (50K satellite tiles) | Free key required |
| MapTiler | 100K requests/month | Free key required |
| Sentinel Hub | Free tier available | Free key required |

### Verdict for Navora

- **EOxCloudless** — best free option, no key, but non-commercial only
- **Esri World Imagery** — highest quality, no key, but non-commercial only
- **Stadia Maps** — commercial use allowed with free key, but limited to 50K satellite tiles/month

---

## Comparison Matrix

### Raster Tile Providers

| Provider | API Key | Free Limits | Dark Mode | Satellite | Commercial | Offline Cache |
|----------|---------|-------------|-----------|-----------|------------|---------------|
| OSM Standard | None | Fair use | ❌ | ❌ | ✅ | ⚠️ Prohibited |
| CARTO | Free key | 1M-5M/month | ✅ | ❌ | ✅ | ✅ |
| Esri | None | Fair use | ✅ | ✅ | ❌ | ✅ |
| Stadia Maps | Free key | 200K credits/month | ✅ | ✅ | ❌ | ✅ |
| MapTiler | Free key | 100K req/month | ✅ | ✅ | ❌ | ✅ |
| Thunderforest | Free key | 150K/month | ✅ | ❌ | ✅ | ✅ |
| Mella | None | Unlimited | ✅ | ❌ | ✅ | ✅ |
| MIERUNE | None | Fair use | ❌ | ❌ | ✅ | ✅ |
| EOxCloudless | None | Fair use | ❌ | ✅ | ❌ | ✅ |

### Vector Tile Providers

| Provider | API Key | Free Limits | Dark Mode | Commercial | Self-Hostable |
|----------|---------|-------------|-----------|------------|---------------|
| OpenFreeMap | None | Unlimited | ✅ | ✅ | ✅ |
| Maptoolkit.org | None | Unlimited | ✅ | ✅ (<€1M) | ❌ |
| VersaTiles | None | Unlimited | ✅ | ✅ | ✅ |
| LFMaps | None | Unlimited | ❌ | ✅ | ❌ |
| CARTO | Free key | 1M-5M/month | ✅ | ✅ | ❌ |
| Protomaps | None | 1M/month | ✅ | ❌ | ✅ |
| Esri | None | Fair use | ✅ | ❌ | ❌ |

---

## Recommendations for Navora

### If Navora is Commercial (Most Likely)

**Primary Recommendation: CARTO Basemaps**
- ✅ 1M requests/month free (commercial)
- ✅ Both raster and vector tiles
- ✅ Dark mode available
- ✅ Global CDN, high reliability
- ✅ Simple integration with flutter_map
- ⚠️ Requires free API key (email registration only)

**Secondary Recommendation: Maptoolkit.org**
- ✅ No API key required
- ✅ Unlimited requests
- ✅ Commercial use allowed (< €1M revenue)
- ✅ Vector tiles with dark mode
- ✅ Outdoor styles (hiking, cycling) — great for trip planning
- ⚠️ Requires MapLibre for vector tiles

**Satellite: Stadia Maps (with free key)**
- ✅ Commercial use allowed
- ✅ 50K satellite tiles/month free
- ⚠️ API key required

### If Navora is Non-Commercial

**Primary Recommendation: OpenFreeMap**
- ✅ No API key, no limits, no registration
- ✅ Vector tiles with dark mode
- ✅ Weekly updates
- ✅ Commercial use allowed
- ⚠️ Vector only (requires MapLibre)

**Secondary Recommendation: OSM Standard**
- ✅ Simplest integration
- ✅ No API key
- ⚠️ No dark mode
- ⚠️ No offline/prefetch allowed

### Recommended Architecture

```
┌─────────────────────────────────────────────┐
│              Navora Flutter App              │
├─────────────────────────────────────────────┤
│                                              │
│  ┌─────────────┐    ┌──────────────────┐    │
│  │  flutter_map │    │ flutter-maplibre │    │
│  │  (Raster)   │    │    (Vector)      │    │
│  └──────┬──────┘    └────────┬─────────┘    │
│         │                    │               │
│  ┌──────▼──────┐    ┌────────▼─────────┐    │
│  │ CARTO Raster │    │ OpenFreeMap      │    │
│  │ (with key)   │    │ (no key)         │    │
│  │ Dark mode    │    │ Dark mode        │    │
│  └─────────────┘    └──────────────────┘    │
│                                              │
│  ┌─────────────────────────────────────┐    │
│  │     Built-in Tile Caching (v8.2+)   │    │
│  │     1-2 GB cache, HTTP headers      │    │
│  └─────────────────────────────────────┘    │
│                                              │
└─────────────────────────────────────────────┘
```

### Implementation Priority

1. **Start with CARTO raster tiles** — easiest migration from Google Maps, dark mode, generous free tier
2. **Add OpenFreeMap vector tiles** — for better quality, smaller size, and dark mode via MapLibre
3. **Implement built-in caching** — already automatic in flutter_map v8.2+
4. **Add satellite layer** — EOxCloudless (non-commercial) or Stadia Maps (commercial)
5. **Consider self-hosting** — if usage grows beyond free tiers

---

## Quick Reference: Tile URLs

### Raster Tiles (Direct flutter_map Compatibility)

```dart
// OSM Standard (no key)
'https://tile.openstreetmap.org/{z}/{x}/{y}.png'

// CARTO Light (free key required)
'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png'

// CARTO Dark (free key required)
'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'

// CARTO Voyager (free key required)
'https://{s}.basemaps.cartocdn.com/voyager/{z}/{x}/{y}.png'

// Esri World Imagery (no key, non-commercial)
'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'

// Esri World Street Map (no key, non-commercial)
'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}'

// Mella Dark (no key, no limits)
'https://basemap.queeniemella.cc/tiles/countries/{z}/{x}/{y}.png'

// EOxCloudless Satellite (no key, non-commercial)
'https://tiles.maps.eox.at/wmts/1.0.0/s2cloudless-2025_3857/default/g/{z}/{y}/{x}.jpg'

// MIERUNE Color (no key)
'https://tile.mierune.co.jp/mierune/color/{z}/{x}/{y}.png'
```

### Vector Tiles (MapLibre Required)

```dart
// OpenFreeMap (no key, no limits)
'https://tiles.openfreemap.org/styles/dark'

// Maptoolkit.org (no key, no limits)
'https://www.maptoolkit.org/style/dark/style.json'

// VersaTiles (no key, no limits)
'https://tiles.versatiles.org/versatiles/shortbread_v1/{z}/{x}/{y}.pbf'

// LFMaps (no key, no limits)
'https://lfmaps.fr/en/style.json'

// CARTO Vector (free key required)
'https://{s}.basemaps.cartocdn.com/vectortiles/voyager/{z}/{x}/{y}.mvt'
```

---

## Sources

- [OSM Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/)
- [CARTO Basemaps](https://carto.com/basemaps/)
- [OpenFreeMap](https://openfreemap.org/)
- [Stadia Maps Pricing](https://stadiamaps.com/pricing/)
- [MapTiler Pricing](https://www.maptiler.com/cloud/pricing/)
- [Thunderforest Pricing](https://www.thunderforest.com/pricing/)
- [Maptoolkit.org](https://www.maptoolkit.org/)
- [Protomaps](https://protomaps.com/)
- [VersaTiles](https://versatiles.org/)
- [LFMaps](https://lfmaps.fr/en/)
- [Mella Dark Basemap](https://basemap.queeniemella.cc/)
- [EOxCloudless](https://cloudless.eox.at/)
- [TileServer GL](https://github.com/maptiler/tileserver-gl)
- [OpenMapTiles](https://github.com/openmaptiles/openmaptiles)
- [flutter_map Caching Docs](https://docs.fleaflet.dev/layers/tile-layer/caching)
- [flutter_map_maplibre](https://pub.dev/packages/flutter_map_maplibre)
- [MapLibre Flutter](https://maplibre.org/flutter-maplibre-gl/)
- [Free Vector Tile Providers Compared](https://www.maptoolkit.org/compare)
