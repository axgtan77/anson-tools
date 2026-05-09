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
  final ValueChanged<WorkoutSet> onTapSet;
  final ValueChanged<WorkoutSet> onLongPressSet;
  final VoidCallback onTapTitle;
  final VoidCallback? onRemoveFromDay;

  /// When non-null, a drag handle is shown that starts a reorder drag at this
  /// index in the parent [ReorderableListView].
  final int? dragIndex;

  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.sets,
    required this.allTimeMaxRM,
    required this.onAddSet,
    required this.onTapSet,
    required this.onLongPressSet,
    required this.onTapTitle,
    this.onRemoveFromDay,
    this.dragIndex,
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
        padding: const EdgeInsets.fromLTRB(10, 6, 4, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onTapTitle,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              exercise.name,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(maxRMLabel,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ),
                if (dragIndex != null)
                  ReorderableDragStartListener(
                    index: dragIndex!,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.drag_handle,
                          color: Colors.black38, size: 22),
                    ),
                  ),
                if (onRemoveFromDay != null)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        color: Colors.black38, size: 20),
                    onSelected: (v) {
                      if (v == 'remove') onRemoveFromDay!();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'remove',
                          child: Text('Remove from this workout')),
                    ],
                  ),
              ],
            ),
            ...List.generate(sets.length, (i) {
              final s = sets[i];
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _SetRow(
                  displayNumber: i + 1,
                  set: s,
                  isMaxRM: !s.isBodyweight &&
                      allTimeMaxRM > 0 &&
                      (s.estimated1RM - allTimeMaxRM).abs() < 0.005,
                  onTap: () => onTapSet(s),
                  onLongPress: () => onLongPressSet(s),
                ),
              );
            }),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onAddSet,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add set'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  final int displayNumber;
  final WorkoutSet set;
  final bool isMaxRM;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SetRow({
    required this.displayNumber,
    required this.set,
    required this.isMaxRM,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final weightStr =
        set.isBodyweight ? '自重' : '${fmtKg(set.weight)} kg';
    final rmStr = set.isBodyweight
        ? ''
        : '(1RM:${_fmtRM(set.estimated1RM)})';

    const tabular =
        TextStyle(fontFeatures: [FontFeature.tabularFigures()]);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '$displayNumber',
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
            if (set.notes != null && set.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 24, top: 1),
                child: Text(
                  set.notes!,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
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
