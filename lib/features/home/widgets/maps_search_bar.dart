import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripmesh/features/auth/providers/auth_providers.dart';
import 'package:tripmesh/features/home/providers/map_ui_providers.dart';

/// Floating maps-home search bar (mock-only, no map SDK).
///
/// Leading 48dp menu button ([onMenuTap]), expanding `Search here`
/// field writing [searchQueryProvider], trailing mic stub + avatar.
class MapsSearchBar extends ConsumerWidget {
  const MapsSearchBar({super.key, required this.onMenuTap});

  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                onPressed: onMenuTap,
              ),
            ),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Search here',
                  hintText: 'Search here',
                  border: InputBorder.none,
                ),
                onChanged: (v) =>
                    ref.read(searchQueryProvider.notifier).state = v,
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
