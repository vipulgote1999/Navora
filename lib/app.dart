import 'package:flutter/material.dart';
import 'package:navora/features/home/home_screen.dart';

/// Navora root widget. Material3, dark-first (`themeMode: ThemeMode.dark`).
class NavoraApp extends StatelessWidget {
  const NavoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Navora',
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
