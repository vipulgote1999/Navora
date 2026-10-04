import 'package:flutter/material.dart';
import 'package:tripmesh/features/home/home_screen.dart';

/// TripMesh root widget. Material3, dark-first (`themeMode: ThemeMode.dark`).
class TripMeshApp extends StatelessWidget {
  const TripMeshApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TripMesh',
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
