import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripmesh/features/auth/providers/auth_providers.dart';
import 'package:tripmesh/features/home/home_screen.dart';
import 'package:tripmesh/features/home/providers/map_ui_providers.dart';
import 'package:tripmesh/features/trips/providers/trip_providers.dart';
import 'package:tripmesh/shared/models/trip.dart';
import 'package:tripmesh/shared/widgets/trip_card.dart';

/// Drawer for the maps-home shell: auth line, Create/Join entry points,
/// and the recent-trips list. Create/Join push the placeholder screens from
/// [HomeScreen] ([CreateTripPlaceholderScreen]/[JoinTripPlaceholderScreen]);
/// the recent-trips list mirrors the vibe sheet, filtered by
/// [searchQueryProvider] (name/origin/destination contains).
class TripDrawer extends ConsumerWidget {
  const TripDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final tripsAsync = ref.watch(watchTripsProvider);
    // Loading shows the same empty text as no-trips; error shows retry.
    final allTrips = tripsAsync.value ?? const <Trip>[];
    final memberCounts = ref.watch(tripMemberCountsProvider);
    final trips = filterTripsByQuery(allTrips, ref.watch(searchQueryProvider));
    final user = authState.value;

    return Drawer(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            user == null
                ? 'Not signed in (mock mode)'
                : 'Signed in as ${user.displayName ?? user.uid}',
          ),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CreateTripPlaceholderScreen(),
              ),
            ),
            child: const Text('Create trip'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const JoinTripPlaceholderScreen(),
              ),
            ),
            child: const Text('Join trip'),
          ),
          const SizedBox(height: 16),
          Text(
            'Recent trips',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (tripsAsync.hasError)
            Row(
              children: [
                const Expanded(
                  child: Text("Couldn't load trips"),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () => ref.invalidate(watchTripsProvider),
                  child: const Text('Retry'),
                ),
              ],
            )
          else if (trips.isEmpty)
            const Text('No trips yet — create one to get started.')
          else
            for (final trip in trips)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TripCard(
                  trip: trip,
                  memberCount: memberCounts[trip.id] ?? 0,
                ),
              ),
        ],
      ),
    );
  }
}
