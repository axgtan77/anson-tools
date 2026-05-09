import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'screens/workout_screen.dart';
import 'utils/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadSettings();
  runApp(const WorkoutApp());
}

class WorkoutApp extends StatelessWidget {
  const WorkoutApp({super.key});

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return MaterialApp(
      title: 'Workout Log',
      theme: ThemeData(
        colorSchemeSeed: Colors.red,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: WorkoutScreen(date: today),
    );
  }
}
