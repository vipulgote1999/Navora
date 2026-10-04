import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripmesh/features/home/providers/map_ui_providers.dart';
import 'package:tripmesh/features/home/widgets/map_fabs.dart';
import 'package:tripmesh/features/trips/data/mock_trip_datasource.dart';
import 'package:tripmesh/features/trips/providers/trip_providers.dart';
import 'package:tripmesh/shared/models/live_position.dart';
import 'package:tripmesh/shared/models/trip.dart';
import 'package:tripmesh/shared/widgets/trip_card.dart';
import 'package:url_launcher/url_launcher.dart';

/// Bottom sheet for the maps-home view: trip vibe summary + recent trips.
///
/// Sizes mirror the maps-home spec: peek 0.22, collapsed 0.12, expanded 0.75.
/// Title is `Trip vibe` until a trip is selected ([selectedTripIdProvider]),
/// then it shows the trip name. The status chip reads `Last updated Xs ago`.
/// Age is `max(live updatedAt, else trip createdAt)` — honest only once
/// watchLive yields fixes (mock yields none; see the TODO below): until
/// P0-02 wires real GPS, `createdAt` is a liveness proxy, NOT a GPS fix age.
/// The chip greys out once the data is older than 90s. The trip list is
/// filtered by [searchQueryProvider] (name/origin/destination contains).
class TripVibeSheet extends ConsumerWidget {
  final DraggableScrollableController controller;

  const TripVibeSheet({super.key, required this.controller});

  Future<void> _navigate() async {
    try {
      await launchUrl(directionsUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Offline / no handler: stay on the map, never crash.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(tripRepositoryProvider);
    final allTrips = repo is MockTripDataSource
        ? repo.trips.values.toList()
        : const <Trip>[];
    final query = ref.watch(searchQueryProvider);
    final trips = filterTripsByQuery(allTrips, query);
    final selectedId = ref.watch(selectedTripIdProvider);
    final activeId = activeTripId(allTrips, selectedId);
    final Trip? focus = (activeId == null
        ? null
        : _findTrip(allTrips, activeId));
    final Trip? resolved = focus ?? (allTrips.isEmpty ? null : allTrips.last);

    // TODO(P0-02): createdAt below is NOT a GPS fix age — it only stands in
    // because mock watchLive yields [] and Member carries no timestamp.
    // Real liveness = max live updatedAt per member; do not present the
    // createdAt fallback as GPS age once live fixes exist.
    final live = resolved == null
        ? const <LivePosition>[]
        : (ref.watch(livePositionsProvider(resolved.id)).value ??
              const <LivePosition>[]);
    var anchor = resolved?.createdAt;
    for (final p in live) {
      if (anchor == null || p.updatedAt.isAfter(anchor)) {
        anchor = p.updatedAt;
      }
    }
    final ageSec = anchor == null
        ? 0
        : DateTime.now().difference(anchor).inSeconds.clamp(0, 1 << 31);
    final stale = ageSec > 90;

    return DraggableScrollableSheet(
      controller: controller,
      initialChildSize: 0.22,
      minChildSize: 0.12,
      maxChildSize: 0.75,
      expand: false,
      builder: (context, scrollController) {
        return Material(
          elevation: 4,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(16)),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  label: 'Trip details',
                  container: true,
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  focus?.name ?? 'Trip vibe',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Chip(
                  label: Text('Last updated ${ageSec}s ago'),
                  labelStyle: TextStyle(
                    color: stale
                        ? Colors.grey
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: _navigate,
                      child: const Text('Navigate'),
                    ),
                    // TODO(P1): wire Share to a real share target.
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: () {},
                      child: const Text('Share'),
                    ),
                    // TODO(P1): wire Save to a real saved-trips store.
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: () {},
                      child: const Text('Save'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (trips.isEmpty)
                  const Text('No trips yet — create one to get started.')
                else
                  for (final trip in trips)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TripCard(
                        trip: trip,
                        memberCount: repo is MockTripDataSource
                            ? repo.membersFor(trip.id).length
                            : 0,
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Trip? _findTrip(List<Trip> trips, String id) {
  for (final trip in trips) {
    if (trip.id == id) return trip;
  }
  return null;
}
