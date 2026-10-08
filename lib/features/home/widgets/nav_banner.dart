import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripmesh/features/navigation/route_providers.dart';

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
