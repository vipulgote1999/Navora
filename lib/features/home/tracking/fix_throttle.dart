/// Throttled GPS-fix gate for TripMesh P1 live tracking.
///
/// Ruling: accuracy veto → heartbeat (`dt > 60s` accepts regardless of
/// distance/jitter) → `dist > 15m` AND `dt > 5s` gate with `< 10m` jumps
/// ignored when `speed < 2m/s`. Drop `accuracy > 50m`. All comparisons
/// strict.
bool acceptFix({
  required double distM,
  required double dtSec,
  required double accuracyM,
  required double speedMps,
}) {
  // Poor fixes never update the map, not even on the heartbeat.
  if (accuracyM > 50) return false;
  // Heartbeat: a live fix at least once a minute even when stationary.
  if (dtSec > 60) return true;
  // Stationary jitter: the GPS wanders a few meters while standing still.
  if (distM < 10 && speedMps < 2) return false;
  return distM > 15 && dtSec > 5;
}
