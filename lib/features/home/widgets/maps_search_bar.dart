import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripmesh/features/auth/providers/auth_providers.dart';
import 'package:tripmesh/features/home/places/places_repository.dart';
import 'package:tripmesh/features/home/providers/map_ui_providers.dart';

/// Floating maps-home search bar.
///
/// Leading 48dp menu button ([onMenuTap]), expanding `Search here`
/// field, trailing mic stub + avatar. Typing filters local trips via
/// [searchQueryProvider] AND fetches keyless Nominatim suggestions
/// (debounced 600ms, min 3 chars, viewport-biased) into
/// [searchResultsProvider]; [searchingProvider] drives the dropdown
/// spinner. Selecting a result is the dropdown's job (see MapShell).
class MapsSearchBar extends ConsumerStatefulWidget {
  const MapsSearchBar({super.key, required this.onMenuTap});

  final VoidCallback onMenuTap;

  @override
  ConsumerState<MapsSearchBar> createState() => _MapsSearchBarState();
}

class _MapsSearchBarState extends ConsumerState<MapsSearchBar> {
  final _places = PlacesRepository();
  Timer? _debounce;
  int _token = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String v) {
    ref.read(searchQueryProvider.notifier).state = v;
    ref.read(searchFocusProvider.notifier).state = null;
    _debounce?.cancel();
    final q = v.trim();
    if (q.length < 3) {
      ref.read(searchResultsProvider.notifier).state = const [];
      ref.read(searchingProvider.notifier).state = false;
      return;
    }
    ref.read(searchingProvider.notifier).state = true;
    final myToken = ++_token;
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      final center = ref.read(myPositionProvider);
      final results = await _places.searchPlaces(
        query: q,
        lat: center?.latitude ?? defaultMapCenterLat,
        lng: center?.longitude ?? defaultMapCenterLng,
      );
      if (!mounted || myToken != _token) return; // Stale: a newer keystroke won.
      ref.read(searchResultsProvider.notifier).state = results;
      ref.read(searchingProvider.notifier).state = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final initial =
        (user?.displayName?.trim().isNotEmpty ?? false
                ? user!.displayName![0]
                : user?.email?.trim().isNotEmpty ?? false
                ? user!.email![0]
                : 'V')
            .toUpperCase();

    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            Semantics(
              label: 'Open TripMesh menu',
              button: true,
              child: IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Open TripMesh menu',
                constraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ),
                onPressed: widget.onMenuTap,
              ),
            ),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Search here',
                  hintText: 'Search here',
                  border: InputBorder.none,
                ),
                onChanged: _onChanged,
              ),
            ),
            Semantics(
              label: 'Voice search',
              button: true,
              child: IconButton(
                icon: const Icon(Icons.mic),
                tooltip: 'Voice search',
                constraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Voice search coming in P1')),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: CircleAvatar(radius: 16, child: Text(initial)),
            ),
          ],
        ),
      ),
    );
  }
}
