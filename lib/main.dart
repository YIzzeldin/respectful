import 'package:flutter/material.dart';
import 'screens/spike_screen.dart';

void main() {
  runApp(const RespectfulApp());
}

class RespectfulApp extends StatelessWidget {
  const RespectfulApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Respectful',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00695C), // Deep teal
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00695C),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const SpikeScreen(),
    );
  }
}
