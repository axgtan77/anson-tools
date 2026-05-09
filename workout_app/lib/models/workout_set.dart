import '../utils/one_rm.dart';

class WorkoutSet {
  final int? id;
  final int exerciseId;
  final String workoutDate; // YYYY-MM-DD
  final int setNumber;
  final double weight; // kg, 0 when bodyweight
  final int reps;
  final bool isBodyweight;

  WorkoutSet({
    this.id,
    required this.exerciseId,
    required this.workoutDate,
    required this.setNumber,
    required this.weight,
    required this.reps,
    this.isBodyweight = false,
  });

  double get estimated1RM =>
      isBodyweight ? 0 : estimate1RM(weight, reps);

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'exercise_id': exerciseId,
        'workout_date': workoutDate,
        'set_number': setNumber,
        'weight': weight,
        'reps': reps,
        'is_bodyweight': isBodyweight ? 1 : 0,
      };

  factory WorkoutSet.fromMap(Map<String, dynamic> m) => WorkoutSet(
        id: m['id'] as int?,
        exerciseId: m['exercise_id'] as int,
        workoutDate: m['workout_date'] as String,
        setNumber: m['set_number'] as int,
        weight: (m['weight'] as num).toDouble(),
        reps: m['reps'] as int,
        isBodyweight: (m['is_bodyweight'] as int? ?? 0) == 1,
      );
}
