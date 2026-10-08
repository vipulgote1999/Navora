import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tripmesh/features/auth/providers/auth_providers.dart';
import 'package:tripmesh/features/home/home_screen.dart';
import 'package:tripmesh/features/home/map/map_tiles.dart';
import 'package:tripmesh/features/home/providers/map_ui_providers.dart';
import 'package:tripmesh/features/home/tracking/location_permission.dart';
import 'package:tripmesh/features/home/tracking/tracking_controller.dart';
import 'package:tripmesh/features/home/widgets/assist_chips.dart';
import 'package:tripmesh/features/home/widgets/convoy_map.dart';
import 'package:tripmesh/features/home/widgets/map_fabs.dart';
import 'package:tripmesh/features/home/widgets/maps_search_bar.dart';
import 'package:tripmesh/features/home/widgets/nav_banner.dart';
import 'package:tripmesh/features/home/widgets/trip_drawer.dart';
import 'package:tripmesh/features/home/widgets/trip_nav_bar.dart';
import 'package:tripmesh/features/home/widgets/trip_vibe_sheet.dart';
import 'package:tripmesh/features/navigation/route_providers.dart';
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

  /// One-shot startup centering (Google Maps behaviour). Runs once per
  /// process from [initState]; see [_startupLocation].
  bool _startupLocated = false;

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
    // Ask the OS location prompt at most once per install, then center.
    unawaited(_startupLocation());
  }

  /// First-launch centering: the OS prompt fires at most once per install
  /// ([requestPermissionOnce] persists the asked flag before prompting,
  /// so even a kill mid-prompt never re-prompts). When granted, the
  /// stream starts and [FollowMode.me] is set so [ConvoyMap] flies to
  /// the first real fix. Denied → stay on the trip area, stay silent.
  /// Runs once per process; [requestPermissionOnce] never throws.
  Future<void> _startupLocation() async {
    if (_startupLocated) return;
    _startupLocated = true;
    final status = await requestPermissionOnce();
    if (!mounted) return;
    if (status != LocationPermission.whileInUse &&
        status != LocationPermission.always) {
      return;
    }
    await _tracker.start(ref);
    if (!mounted) return;
    ref.read(mapFollowModeProvider.notifier).state = FollowMode.me;
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
                  const _SearchResultsDropdown(),
                  const NavBanner(),
                  const _RouteErrorLine(),
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
            const Positioned(
              left: 12,
              bottom: 180,
              child: _MapStyleButton(),
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

/// Inline route-failure line under the nav banner.
///
/// Visible only while [routeErrorProvider] is set — a failed re-route must
/// not silently leave a stale route on screen with no error visible. The
/// close button dismisses it; [fetchRoute] also clears it when a new fetch
/// starts.
class _RouteErrorLine extends ConsumerWidget {
  const _RouteErrorLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = ref.watch(routeErrorProvider);
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(error)),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Dismiss route error',
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                onPressed: () {
                  ref.read(routeErrorProvider.notifier).state = null;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Base-map style cycler: standard → dark → satellite.
///
/// One control with semantics label `Map style`; [ConvoyMap] switches its
/// tile layer (URL + attribution) off [mapStyleProvider].
class _MapStyleButton extends ConsumerWidget {
  const _MapStyleButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(mapStyleProvider);
    return Semantics(
      label: 'Map style',
      button: true,
      child: FloatingActionButton.small(
        heroTag: 'map-style',
        tooltip: 'Change map style',
        onPressed: () {
          final next =
              MapStyle.values[(style.index + 1) % MapStyle.values.length];
          ref.read(mapStyleProvider.notifier).state = next;
        },
        child: const Icon(Icons.layers_outlined),
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
