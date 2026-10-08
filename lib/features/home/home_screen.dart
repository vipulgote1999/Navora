import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navora/features/home/map_shell.dart';

/// P0 home: maps-first shell. Keeps the class name for route compat;
/// the convoy map owns the Create/Join flows (placeholders below).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const MapShell();
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
