import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:navora/features/home/providers/map_ui_providers.dart';
import 'package:navora/features/navigation/route_icons.dart';
import 'package:navora/features/navigation/route_models.dart';
import 'package:navora/features/navigation/route_providers.dart';

/// Maps-style primary navigation header: green banner with the next
/// maneuver icon + instruction + distance-to-maneuver.
///
/// Shown only while navigating with a loaded route and known position.
/// Pure display — reroute/arrival logic lives in the route card listener.
class NavHeaderBanner extends ConsumerWidget {
  const NavHeaderBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigating = ref.watch(navigatingProvider);
    final route = ref.watch(routeProvider).value;
    final me = ref.watch(myPositionProvider);
    if (!navigating || route == null || me == null || route.steps.isEmpty) {
      return const SizedBox.shrink();
    }
    final index = nearestStepIndex(route, me);
    final step = route.steps[index.clamp(0, route.steps.length - 1)];
    final toManeuver = const Distance().as(LengthUnit.Meter, me, step.location);

    return Semantics(
      label: 'Next maneuver',
      container: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Material(
          elevation: 4,
          color: Colors.green.shade700,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  maneuverIcon(step.maneuverType, step.modifier),
                  color: Colors.white,
                  size: 36,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        step.instruction,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'In ${formatStepDistance(toManeuver)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
