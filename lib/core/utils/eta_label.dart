/// Straight-line ETA label for the maps-home UI.
///
/// Assumes ~30 km/h average convoy speed. Explicitly marked straight-line
/// so later tasks (map, sheet) don't imply routed navigation.
String formatEtaLabel(double kmStraightLine) {
  final mins = (kmStraightLine / 30 * 60).round();
  return '~${kmStraightLine.toStringAsFixed(1)} km · ~$mins min straight-line';
}
