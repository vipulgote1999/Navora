import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripmesh/features/home/providers/map_ui_providers.dart';
import 'package:tripmesh/features/trips/data/mock_trip_datasource.dart';
import 'package:tripmesh/features/trips/providers/trip_providers.dart';
import 'package:tripmesh/shared/models/trip.dart';
import 'package:tripmesh/shared/widgets/trip_card.dart';

/// Bottom sheet for the maps-home view: trip vibe summary + recent trips.
///
/// Sizes mirror the maps-home spec: peek 0.22, collapsed 0.12, expanded 0.75.
/// Title is `Trip vibe` until a trip is selected ([selectedTripIdProvider]),
/// then it shows the trip name. The status chip reads `Last updated Xs ago`
/// (keyed off [Trip.createdAt] as the P0 liveness proxy) and greys out once
/// the data is older than 90s.
class TripVibeSheet extends ConsumerWidget {
  final DraggableScrollableController controller;

  const TripVibeSheet({super.key, required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(tripRepositoryProvider);
    final trips = repo is MockTripDataSource
        ? repo.trips.values.toList()
        : const <Trip>[];
    final selectedId = ref.watch(selectedTripIdProvider);
    final Trip? selected = selectedId == null
        ? null
        : _findTrip(trips, selectedId);
    final Trip? focus = selected ?? (trips.isEmpty ? null : trips.first);

    final ageSec = focus == null
        ? 0
        : DateTime.now().difference(focus.createdAt).inSeconds.clamp(0, 1 << 31);
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
                  selected?.name ?? 'Trip vibe',
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
                      onPressed: () {},
                      child: const Text('Navigate'),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('Share'),
                    ),
                    TextButton(
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
