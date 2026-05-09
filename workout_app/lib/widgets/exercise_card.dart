import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/exercise.dart';
import '../models/workout_set.dart';
import '../utils/format.dart';

class ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final List<WorkoutSet> sets;
  final double allTimeMaxRM;
  final VoidCallback onAddSet;
  final ValueChanged<WorkoutSet> onDeleteSet;

  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.sets,
    required this.allTimeMaxRM,
    required this.onAddSet,
    required this.onDeleteSet,
  });

  @override
  Widget build(BuildContext context) {
    final maxRMLabel =
        allTimeMaxRM > 0 ? 'RM : ${fmtKg(allTimeMaxRM)}kg' : 'RM : —';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.red, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    exercise.name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(maxRMLabel,
                    style:
                        const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 6),
            ...sets.map((s) => _SetRow(
                  set: s,
                  isMaxRM: !s.isBodyweight &&
                      allTimeMaxRM > 0 &&
                      (s.estimated1RM - allTimeMaxRM).abs() < 0.005,
                  onDelete: () => onDeleteSet(s),
                )),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onAddSet,
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add set'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  final WorkoutSet set;
  final bool isMaxRM;
  final VoidCallback onDelete;

  const _SetRow({
    required this.set,
    required this.isMaxRM,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final weightStr =
        set.isBodyweight ? '自重' : '${fmtKg(set.weight)} kg';
    final rmStr = set.isBodyweight
        ? ''
        : '(1RM:${_fmtRM(set.estimated1RM)})';

    const tabular = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);

    return GestureDetector(
      onLongPress: onDelete,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '${set.setNumber}',
                style: const TextStyle(color: Colors.black54),
              ),
            ),
            SizedBox(
              width: 90,
              child: Text(weightStr,
                  textAlign: TextAlign.right, style: tabular),
            ),
            const SizedBox(width: 6),
            const Text('×'),
            const SizedBox(width: 6),
            SizedBox(
              width: 70,
              child: Text('${set.reps} reps', style: tabular),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                rmStr,
                style: const TextStyle(color: Colors.black54),
              ),
            ),
            if (isMaxRM)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  'MAX RM',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _fmtRM(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }
}
