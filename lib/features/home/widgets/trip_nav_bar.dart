import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripmesh/features/home/providers/map_ui_providers.dart';

/// Bottom navigation for the maps-home shell.
///
/// Writes [navIndexProvider]: 0 = Explore, 1 = You, 2 = Contribute.
class TripNavBar extends ConsumerWidget {
  const TripNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(navIndexProvider);
    return NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (i) =>
          ref.read(navIndexProvider.notifier).state = i,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.explore), label: 'Explore'),
        NavigationDestination(icon: Icon(Icons.person), label: 'You'),
        NavigationDestination(icon: Icon(Icons.add), label: 'Contribute'),
      ],
    );
  }
}
