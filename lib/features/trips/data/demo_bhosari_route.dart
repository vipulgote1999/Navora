import 'package:latlong2/latlong.dart';
import 'package:navora/features/navigation/route_models.dart';

/// Canned Bhosari destination for the demo convoy (and offline fallback).
const demoBhosariDestination = LatLng(18.6210, 73.8501);

/// Canned Wagholi → Bhosari route for the demo convoy.
///
/// Shaped like a real [TripRoute] (full polyline + steps with maneuver
/// locations). Used when the live OSRM fetch fails so the demo never
/// dies on stage — and by tests that need a stable route.
const demoBhosariRoute = TripRoute(
  points: [
    LatLng(18.6545, 73.9412),
    LatLng(18.6450, 73.9150),
    LatLng(18.6330, 73.8850),
    LatLng(18.6210, 73.8501),
  ],
  distanceM: 12500.0,
  durationS: 1500.0,
  steps: [
    RouteStep(
      instruction: 'Head southwest',
      maneuverType: 'depart',
      modifier: '',
      distanceM: 5200.0,
      durationS: 620.0,
      location: LatLng(18.6545, 73.9412),
    ),
    RouteStep(
      instruction: 'Turn right onto Bhosari Road',
      maneuverType: 'turn',
      modifier: 'right',
      distanceM: 4800.0,
      durationS: 580.0,
      location: LatLng(18.6450, 73.9150),
    ),
    RouteStep(
      instruction: 'Arrive at Bhosari',
      maneuverType: 'arrive',
      modifier: '',
      distanceM: 0,
      durationS: 0,
      location: LatLng(18.6210, 73.8501),
    ),
  ],
);
