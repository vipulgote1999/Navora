import 'package:flutter/material.dart';

/// Maneuver icon for an OSRM step. Falls back to [Icons.straight].
///
/// Shared by the route card and the navigation header banner so both speak
/// the same visual language (Maps-style turn arrows).
IconData maneuverIcon(String maneuverType, String modifier) {
  final type = maneuverType.toLowerCase();
  final mod = modifier.toLowerCase();
  if (type == 'arrive') return Icons.flag;
  if (type == 'depart') return Icons.navigation;
  if (type.contains('roundabout') || type.contains('rotary')) {
    return Icons.loop;
  }
  if (type.contains('ramp')) return Icons.call_merge;
  if (type == 'merge' || type == 'fork') return Icons.merge;
  if (type.contains('turn') || type == 'end of road') {
    if (mod.contains('left')) {
      return mod.contains('slight')
          ? Icons.turn_slight_left
          : Icons.turn_left;
    }
    if (mod.contains('u')) return Icons.u_turn_left;
    return mod.contains('slight')
        ? Icons.turn_slight_right
        : Icons.turn_right;
  }
  return Icons.straight;
}
