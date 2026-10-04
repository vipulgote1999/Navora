import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripmesh/core/utils/eta_label.dart';
import 'package:tripmesh/features/home/providers/map_ui_providers.dart';
import 'package:tripmesh/features/trips/data/mock_trip_datasource.dart';
import 'package:tripmesh/features/trips/providers/trip_providers.dart';
import 'package:tripmesh/shared/models/trip.dart';

/// Horizontal assist chips under the maps-home search bar.
///
/// `Ask TripMesh` (stub), `ActiveTrip · ETA` (mock straight-line
/// [formatEtaLabel] distance 12.5 km), `Stops / Food / Fuel` (stub).
/// All chips are at least 48dp tall.
class AssistChips extends ConsumerWidget {
  const AssistChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(tripRepositoryProvider);
    final selectedId = ref.watch(selectedTripIdProvider);
    // TODO(P0-02): replace MockTripDataSource downcast with a watchTrips
    // provider/stream; downcast is a P0-01 stopgap, do not expand its use.
    final trips = repo is MockTripDataSource
        ? repo.trips.values.toList()
        : const <Trip>[];
    final resolvedId = activeTripId(trips, selectedId);
    Trip? active;
    if (resolvedId != null) {
      for (final t in trips) {
        if (t.id == resolvedId) active = t;
      }
    }
    active ??= trips.isNotEmpty ? trips.last : null;
    final activeLabel = active?.name ?? 'ActiveTrip';
    final etaLabel = '$activeLabel · ${formatEtaLabel(12.5)}';

    Widget chip(Widget child) => ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Center(child: child),
    );

    void comingSoon() => ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Coming in P1')));

    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          chip(
            ActionChip(
              avatar: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Ask TripMesh'),
              onPressed: comingSoon,
            ),
          ),
          const SizedBox(width: 8),
          chip(
            ActionChip(
              avatar: const Icon(Icons.bolt, size: 18),
              label: Text(etaLabel),
              onPressed: comingSoon,
            ),
          ),
          const SizedBox(width: 8),
          chip(
            ActionChip(
              avatar: const Icon(Icons.filter_list, size: 18),
              label: const Text('Stops / Food / Fuel'),
              onPressed: comingSoon,
            ),
          ),
        ],
      ),
    );
  }
}
