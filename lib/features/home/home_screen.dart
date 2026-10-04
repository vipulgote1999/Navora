import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripmesh/features/auth/providers/auth_providers.dart';
import 'package:tripmesh/features/trips/data/mock_trip_datasource.dart';
import 'package:tripmesh/features/trips/providers/trip_providers.dart';
import 'package:tripmesh/shared/models/trip.dart';
import 'package:tripmesh/shared/widgets/trip_card.dart';

/// P0 home: Create/Join entry points plus the recent-trips list.
///
/// Create/Join push placeholder screens — the convoy map owns the real
/// flows in P0-02. Dark-first Material3 comes from [TripMeshApp].
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final repo = ref.watch(tripRepositoryProvider);
    final trips = repo is MockTripDataSource
        ? repo.trips.values.toList()
        : const <Trip>[];
    final user = authState.value;

    return Scaffold(
      appBar: AppBar(title: const Text('TripMesh')),
      body: ListView(
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
    );
  }
}

/// Placeholder for the P0-02 create flow (convoy map owns it).
class CreateTripPlaceholderScreen extends StatelessWidget {
  const CreateTripPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create trip')),
      body: const Center(
        child: Text('Create trip lands in P0-02 with the convoy map.'),
      ),
    );
  }
}

/// Placeholder for the P0-02 join flow (convoy map owns it).
class JoinTripPlaceholderScreen extends StatelessWidget {
  const JoinTripPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join trip')),
      body: const Center(
        child: Text('Join trip lands in P0-02 with the convoy map.'),
      ),
    );
  }
}
