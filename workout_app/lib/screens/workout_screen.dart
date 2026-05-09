import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../models/exercise.dart';
import '../models/workout_set.dart';
import '../widgets/add_set_sheet.dart';
import '../widgets/exercise_card.dart';

class WorkoutScreen extends StatefulWidget {
  final String date; // YYYY-MM-DD
  const WorkoutScreen({super.key, required this.date});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  List<Exercise> _exercises = [];
  Map<int, List<WorkoutSet>> _setsByExercise = {};
  Map<int, double> _maxRMByExercise = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = DatabaseHelper.instance;
    final exercises = await db.listExercises();
    final sets = await db.setsForDate(widget.date);

    final byEx = <int, List<WorkoutSet>>{};
    for (final s in sets) {
      byEx.putIfAbsent(s.exerciseId, () => []).add(s);
    }
    for (final list in byEx.values) {
      list.sort((a, b) => a.setNumber.compareTo(b.setNumber));
    }

    final maxRM = <int, double>{};
    for (final e in exercises) {
      maxRM[e.id!] = await db.allTimeMaxRM(e.id!);
    }

    if (!mounted) return;
    setState(() {
      _exercises = exercises;
      _setsByExercise = byEx;
      _maxRMByExercise = maxRM;
      _loading = false;
    });
  }

  Future<void> _addSet(Exercise ex) async {
    final existing = _setsByExercise[ex.id!] ?? [];
    final last = existing.isNotEmpty ? existing.last : null;
    final result = await showModalBottomSheet<AddSetResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddSetSheet(
        exerciseName: ex.name,
        lastWeight: last == null || last.isBodyweight ? null : last.weight,
        lastReps: last?.reps,
      ),
    );
    if (result == null) return;
    final nextNumber = existing.length + 1;
    await DatabaseHelper.instance.insertSet(WorkoutSet(
      exerciseId: ex.id!,
      workoutDate: widget.date,
      setNumber: nextNumber,
      weight: result.weight,
      reps: result.reps,
      isBodyweight: result.isBodyweight,
    ));
    await _load();
  }

  Future<void> _deleteSet(WorkoutSet s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this set?'),
        content: Text(
          s.isBodyweight
              ? '自重 × ${s.reps} reps'
              : '${s.weight}kg × ${s.reps} reps',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await DatabaseHelper.instance.deleteSet(s.id!);
    await _load();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(widget.date),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null || !mounted) return;
    final dateStr = DateFormat('yyyy-MM-dd').format(picked);
    if (dateStr == widget.date) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => WorkoutScreen(date: dateStr)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final headerDate = widget.date.replaceAll('-', '/');
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                width: double.infinity,
                color: Colors.red,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$headerDate WorkOut',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Icon(Icons.calendar_today,
                        color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      children: [
                        ..._exercises.map((e) => ExerciseCard(
                              exercise: e,
                              sets: _setsByExercise[e.id!] ?? const [],
                              allTimeMaxRM: _maxRMByExercise[e.id!] ?? 0,
                              onAddSet: () => _addSet(e),
                              onDeleteSet: _deleteSet,
                            )),
                        const SizedBox(height: 24),
                      ],
                    ),
            ),
            Container(
              width: double.infinity,
              color: Colors.red,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              child: const Text(
                'Long-press a set to delete',
                textAlign: TextAlign.right,
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
