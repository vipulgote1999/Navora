import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navora/features/auth/providers/auth_providers.dart';
import 'package:navora/features/home/home_screen.dart';
import 'package:navora/features/home/providers/map_ui_providers.dart';
import 'package:navora/features/home/tracking/startup_location_permission.dart';
import 'package:navora/features/home/tracking/tracking_controller.dart';
import 'package:navora/features/home/widgets/assist_chips.dart';
import 'package:navora/features/home/widgets/convoy_map.dart';
import 'package:navora/features/home/widgets/nav_banner.dart';
import 'package:navora/features/home/widgets/map_fabs.dart';
import 'package:navora/features/home/widgets/maps_search_bar.dart';
import 'package:navora/features/home/widgets/trip_drawer.dart';
import 'package:navora/features/home/widgets/trip_nav_bar.dart';
import 'package:navora/features/home/widgets/trip_vibe_sheet.dart';
import 'package:navora/features/navigation/route_providers.dart';
import 'package:navora/features/trips/providers/trip_providers.dart';
import 'package:navora/shared/models/trip.dart';
import 'package:navora/shared/widgets/trip_card.dart';

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
    // One-shot hydrate of saved trip ids; failures stay in-memory only.
    unawaited(loadSavedTripIds(ref));
    // Startup location prompt: once per installation. Post-frame so the
    // system dialog opens over the first rendered map frame; on grant the
    // silent auto-start below picks up tracking immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_requestStartupPermission());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _syncTracking(resumed: state == AppLifecycleState.resumed);
  }

  /// Tracks only on Explore (index 0) while resumed; otherwise the stream
  /// halts (battery). Auto-start is silent: `checkPermission` only, no
  /// prompt, no SnackBar — a silent `false` is ignored and retried on the
  /// next lifecycle/nav event. Explicit permission UX lives in [MapFabs];
  /// the one-time startup system prompt lives in
  /// [_requestStartupPermission] (once per installation).
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

  /// Once-per-installation startup prompt. Shows the OS location dialog on
  /// the very first launch only ([ensureStartupLocationPermission] guards
  /// with a persisted flag); afterwards starts tracking when granted.
  Future<void> _requestStartupPermission() async {
    final prompted = await ensureStartupLocationPermission();
    if (!mounted) return;
    // First launch (prompt attempted): re-sync — a grant enables tracking
    // right away via the silent check-only start.
    if (prompted) await _syncTracking();
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
    // Maps-style nav mode: the maneuver banner replaces search + chips
    // while guiding (search returns on arrival/stop).
    final navigating = ref.watch(navigatingProvider);

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
                  if (navigating) ...[
                    const SizedBox(height: 8),
                    const NavHeaderBanner(),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: MapsSearchBar(
                        onMenuTap: () =>
                            Scaffold.of(scaffoldContext).openDrawer(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const _SearchResultsDropdown(),
                    const AssistChips(),
                  ],
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

/// Nominatim suggestion dropdown under the search bar.
///
/// Shows while [searchResultsProvider] is non-empty (or a spinner while
/// [searchingProvider]); hidden otherwise. Tapping a result pins it via
/// [searchFocusProvider] (ConvoyMap flies there), clears the list and
/// dismisses the keyboard. Trip filtering via [searchQueryProvider] is
/// untouched — suggestions and trip results coexist.
class _SearchResultsDropdown extends ConsumerWidget {
  const _SearchResultsDropdown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(searchResultsProvider);
    final searching = ref.watch(searchingProvider);
    if (results.isEmpty && !searching) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: searching && results.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final r = results[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.place_outlined),
                      title: Text(
                        r.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        r.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        ref.read(searchFocusProvider.notifier).state = r;
                        ref.read(searchResultsProvider.notifier).state =
                            const [];
                        ref.read(searchingProvider.notifier).state = false;
                        FocusScope.of(context).unfocus();
                      },
                    );
                  },
                ),
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
    final tripsAsync = ref.watch(watchTripsProvider);
    final trips = tripsAsync.value ?? const <Trip>[];
    final memberCounts = ref.watch(tripMemberCountsProvider);
    // ONE stable watch (empty-uid key when signed out); rows below use
    // plain map lookups, never per-row family watches.
    final myIds = ref.watch(userTripIdsProvider(user?.uid ?? ''));
    final mine = user == null
        ? const <Trip>[]
        : trips.where((t) => myIds.contains(t.id)).toList();

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
              else if (tripsAsync.hasError)
                Row(
                  children: [
                    const Expanded(
                      child: Text("Couldn't load trips"),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: () =>
                          ref.invalidate(watchTripsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                )
              else if (mine.isEmpty)
                const Text('No trips yet — create one to get started.')
              else
                for (final trip in mine)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TripCard(
                      trip: trip,
                      memberCount: memberCounts[trip.id] ?? 0,
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
