import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripmesh/features/auth/providers/auth_providers.dart';
import 'package:tripmesh/features/home/home_screen.dart';
import 'package:tripmesh/features/home/providers/map_ui_providers.dart';
import 'package:tripmesh/features/home/tracking/tracking_controller.dart';
import 'package:tripmesh/features/home/widgets/assist_chips.dart';
import 'package:tripmesh/features/home/widgets/convoy_map.dart';
import 'package:tripmesh/features/home/widgets/map_fabs.dart';
import 'package:tripmesh/features/home/widgets/maps_search_bar.dart';
import 'package:tripmesh/features/home/widgets/trip_drawer.dart';
import 'package:tripmesh/features/home/widgets/trip_nav_bar.dart';
import 'package:tripmesh/features/home/widgets/trip_vibe_sheet.dart';
import 'package:tripmesh/features/trips/data/mock_trip_datasource.dart';
import 'package:tripmesh/features/trips/providers/trip_providers.dart';
import 'package:tripmesh/shared/models/trip.dart';
import 'package:tripmesh/shared/widgets/trip_card.dart';

/// Maps-home shell: drawer + bottom nav over a [ConvoyMap] stack.
///
/// Index 0 (Explore) is the bare map stack. Index 1 (You) overlays the
/// auth-filtered trip list; index 2 (Contribute) overlays Create/Join
/// quick actions that push the same placeholder routes as [TripDrawer].
/// No `AppBar` — [MapsSearchBar] floats over the map.
class MapShell extends ConsumerStatefulWidget {
  const MapShell({super.key});

  @override
  ConsumerState<MapShell> createState() => _MapShellState();
}

class _MapShellState extends ConsumerState<MapShell>
    with WidgetsBindingObserver {
  late final DraggableScrollableController _sheetController;
  final _tracker = TrackingController();
  ProviderSubscription<int>? _navSub;

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
    WidgetsBinding.instance.addObserver(this);
    _navSub = ref.listenManual<int>(navIndexProvider, (prev, next) {
      _syncTracking();
    });
    _syncTracking();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _syncTracking(resumed: state == AppLifecycleState.resumed);
  }

  /// Tracks only on Explore (index 0) while resumed; otherwise the stream
  /// halts (battery). Auto-start is silent: `checkPermission` only, no
  /// prompt, no SnackBar — a silent `false` is ignored and retried on the
  /// next lifecycle/nav event. Explicit permission UX lives in [MapFabs].
  Future<void> _syncTracking({bool? resumed}) async {
    final isResumed =
        resumed ??
        (WidgetsBinding.instance.lifecycleState == null ||
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed);
    final onExplore = ref.read(navIndexProvider) == 0;
    if (!onExplore || !isResumed) {
      await _tracker.stop();
      return;
    }
    await _tracker.start(ref);
  }

  @override
  void dispose() {
    _navSub?.close();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_tracker.stop());
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navIndex = ref.watch(navIndexProvider);

    return Scaffold(
      drawer: const TripDrawer(),
      bottomNavigationBar: const TripNavBar(),
      body: Builder(
        builder: (scaffoldContext) => Stack(
          children: [
            const ConvoyMap(),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: MapsSearchBar(
                      onMenuTap: () =>
                          Scaffold.of(scaffoldContext).openDrawer(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const AssistChips(),
                  if (navIndex == 1) const Expanded(child: YouTripsOverlay()),
                  if (navIndex == 2) const Expanded(child: ContributeOverlay()),
                ],
              ),
            ),
            const Positioned(
              right: 12,
              bottom: 180,
              child: MapFabs(),
            ),
            // Anchored bottom-center: a bare sheet child would align to
            // the top of the Stack and cover the search bar.
            Align(
              alignment: Alignment.bottomCenter,
              child: TripVibeSheet(controller: _sheetController),
            ),
          ],
        ),
      ),
    );
  }
}

/// Index-1 overlay: trips filtered to the signed-in user's membership.
///
/// Signed out (mock mode) shows the auth stub line instead of a list.
class YouTripsOverlay extends ConsumerWidget {
  const YouTripsOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final repo = ref.watch(tripRepositoryProvider);
    final trips = repo is MockTripDataSource
        ? repo.trips.values.toList()
        : const <Trip>[];
    final mine = user == null
        ? const <Trip>[]
        : trips
              .where(
                (t) =>
                    repo is MockTripDataSource &&
                    repo.membersFor(t.id).any((m) => m.uid == user.uid),
              )
              .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your trips',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (user == null)
                const Text('Not signed in (mock mode)')
              else if (mine.isEmpty)
                const Text('No trips yet — create one to get started.')
              else
                for (final trip in mine)
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
      ),
    );
  }
}

/// Index-2 overlay: Create/Join quick actions.
///
/// Pushes the same placeholder routes as [TripDrawer].
class ContributeOverlay extends StatelessWidget {
  const ContributeOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Contribute',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CreateTripPlaceholderScreen(),
                  ),
                ),
                child: const Text('Create trip'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const JoinTripPlaceholderScreen(),
                  ),
                ),
                child: const Text('Join trip'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
