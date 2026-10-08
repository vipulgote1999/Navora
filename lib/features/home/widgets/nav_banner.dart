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
/// Google Maps reference (Nav SDK): floating dark-green card, radius 12,
/// horizontal margin 8, left 90px column (55px maneuver icon + distance
/// below), right column road/instruction 18-22 bold. Tap expands to
/// preview the next 1-2 steps.
class NavHeaderBanner extends ConsumerStatefulWidget {
  const NavHeaderBanner({super.key});

  @override
  ConsumerState<NavHeaderBanner> createState() => _NavHeaderBannerState();
}

class _NavHeaderBannerState extends ConsumerState<NavHeaderBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final navigating = ref.watch(navigatingProvider);
    final route = ref.watch(routeProvider).value;
    final me = ref.watch(myPositionProvider);
    if (!navigating || route == null || me == null || route.steps.isEmpty) {
      return const SizedBox.shrink();
    }
    final index = nearestStepIndex(route, me);
    final current = index.clamp(0, route.steps.length - 1);
    final step = route.steps[current];
    final toManeuver = const Distance().as(LengthUnit.Meter, me, step.location);
    final upcoming = route.steps
        .skip(current + 1)
        .take(2)
        .toList(growable: false);

    return Semantics(
      label: 'Next maneuver',
      container: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: GestureDetector(
          onTap: upcoming.isEmpty
              ? null
              : () => setState(() => _expanded = !_expanded),
          child: Material(
            elevation: 4,
            color: const Color(0xFF188038),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding:
                  const EdgeInsets.only(top: 16, bottom: 8, left: 16, right: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 90,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              maneuverIcon(
                                  step.maneuverType, step.modifier),
                              color: Colors.white,
                              size: 55,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'In ${formatStepDistance(toManeuver)}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              step.instruction,
                              maxLines: _expanded ? 4 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                            ),
                            if (step.ref.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: _ShieldRow(ref: step.ref),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Tooltip(
                            message: 'Voice guidance coming soon',
                            child: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Icon(
                                Icons.mic,
                                color: Colors.white70,
                                size: 22,
                              ),
                            ),
                          ),
                          Semantics(
                            label: 'End navigation',
                            button: true,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                ref
                                    .read(navigatingProvider.notifier)
                                    .state = false;
                                ref
                                    .read(mapFollowModeProvider.notifier)
                                    .state = FollowMode.none;
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(12),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (step.lanes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _LaneStrip(lanes: step.lanes),
                    ),
                  if (_expanded)
                    for (final next in upcoming)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(
                              maneuverIcon(
                                  next.maneuverType, next.modifier),
                              color: Colors.white.withAlpha(200),
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                next.instruction,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withAlpha(200),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Text(
                              formatStepDistance(next.distanceM),
                              style: TextStyle(
                                color: Colors.white.withAlpha(200),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                  if (route.steps.length > 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0;
                            i < route.steps.length.clamp(0, 20);
                            i++)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(
                                horizontal: 2, vertical: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == current
                                  ? Colors.white
                                  : Colors.white.withAlpha(100),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Highway shield chips from an OSRM step `ref` (e.g. `A2;E35`).
///
/// Hidden by the caller when `ref` is empty.
class _ShieldRow extends StatelessWidget {
  const _ShieldRow({required this.ref});

  final String ref;

  @override
  Widget build(BuildContext context) {
    final shields = ref
        .split(';')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    if (shields.isEmpty) return const SizedBox.shrink();
    return Semantics(
      label: 'Road shields',
      container: true,
      child: Wrap(
        spacing: 6,
        children: [
          for (final shield in shields)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(36),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withAlpha(120)),
              ),
              child: Text(
                shield,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Lane-guidance arrow strip for the current maneuver.
///
/// One arrow per lane (first indication); valid lanes full white,
/// invalid dimmed. `none` (unmarked) lanes render nothing. Hidden by
/// the caller when the dataset carries no lane data.
class _LaneStrip extends StatelessWidget {
  const _LaneStrip({required this.lanes});

  final List<RouteLane> lanes;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Lane guidance',
      container: true,
      explicitChildNodes: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(36),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final lane in lanes)
              Builder(
                builder: (context) {
                  final icon = lane.indications.isEmpty
                      ? null
                      : laneIcon(lane.indications.first);
                  if (icon == null) return const SizedBox.shrink();
                  return Semantics(
                    label: lane.valid ? 'Lane open' : 'Lane closed',
                    button: false,
                    child: Icon(
                      icon,
                      color: lane.valid
                          ? Colors.white
                          : Colors.white.withAlpha(100),
                      size: 30,
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Top-of-map navigation banner for the active route.
///
/// Hidden ([SizedBox.shrink]) while [activeRouteProvider] is null; otherwise
/// a card with the first maneuver instruction, the total distance, and a
/// close button that clears the active route.
class NavBanner extends ConsumerWidget {
  const NavBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(activeRouteProvider);
    if (route == null) return const SizedBox.shrink();
    final String instruction = route.maneuvers.isNotEmpty
        ? route.maneuvers.first.instruction
        : 'Route ready';
    return Semantics(
      label: 'Current maneuver',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        instruction,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        RouteFormat.distance(route.distanceM),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Clear route',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () {
                    ref.read(activeRouteProvider.notifier).state = null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
