/// Throttled GPS-fix gate for TripMesh P1 live tracking.
///
/// Spec (Global Constraints): accept iff (`dist > 15m` AND `dt > 5s`)
/// OR `dt > 60s`; drop `accuracy > 50m`; ignore `< 10m` jumps when
/// `speed < 2m/s`. All comparisons strict; vetoes win over the heartbeat.
bool acceptFix({
  required double distM,
  required double dtSec,
  required double accuracyM,
  required double speedMps,
}) {
  // Poor fixes never update the map, not even on the heartbeat.
  if (accuracyM > 50) return false;
  // Stationary jitter: the GPS wanders a few meters while standing still.
  if (distM < 10 && speedMps < 2) return false;
  // Heartbeat: a live fix at least once a minute even when stationary.
  if (dtSec > 60) return true;
  return distM > 15 && dtSec > 5;
}
