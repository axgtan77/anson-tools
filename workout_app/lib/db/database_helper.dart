import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/exercise.dart';
import '../models/workout_set.dart';

class DailySummary {
  final String date;
  final int exerciseCount;
  final int setCount;
  final double totalVolumeKg;

  DailySummary({
    required this.date,
    required this.exerciseCount,
    required this.setCount,
    required this.totalVolumeKg,
  });
}

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'workout.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE exercises (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            display_order INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE sets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            exercise_id INTEGER NOT NULL,
            workout_date TEXT NOT NULL,
            set_number INTEGER NOT NULL,
            weight REAL NOT NULL,
            reps INTEGER NOT NULL,
            is_bodyweight INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (exercise_id) REFERENCES exercises(id)
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_sets_date ON sets(workout_date)');
        await db.execute(
            'CREATE INDEX idx_sets_ex ON sets(exercise_id)');

        const seeds = [
          'ベンチプレス',
          'ダンベルプレス',
          'インクラインダンベルプレス',
          'ディップス',
          'ケーブルフライ',
          'フェイスプル',
        ];
        for (var i = 0; i < seeds.length; i++) {
          await db.insert('exercises', {
            'name': seeds[i],
            'display_order': i,
          });
        }
      },
    );
  }

  // ---- Exercises ----

  Future<List<Exercise>> listExercises() async {
    final db = await database;
    final rows =
        await db.query('exercises', orderBy: 'display_order, name');
    return rows.map(Exercise.fromMap).toList();
  }

  Future<Exercise?> getExercise(int id) async {
    final db = await database;
    final rows =
        await db.query('exercises', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Exercise.fromMap(rows.first);
  }

  Future<int> insertExercise(String name) async {
    final db = await database;
    final maxOrderRow =
        await db.rawQuery('SELECT MAX(display_order) AS m FROM exercises');
    final nextOrder = ((maxOrderRow.first['m'] as int?) ?? -1) + 1;
    return db.insert('exercises', {
      'name': name,
      'display_order': nextOrder,
    });
  }

  Future<int> renameExercise(int id, String name) async {
    final db = await database;
    return db.update('exercises', {'name': name},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> reorderExercises(List<Exercise> ordered) async {
    final db = await database;
    final batch = db.batch();
    for (var i = 0; i < ordered.length; i++) {
      batch.update('exercises', {'display_order': i},
          where: 'id = ?', whereArgs: [ordered[i].id]);
    }
    await batch.commit(noResult: true);
  }

  Future<int> setCountForExercise(int id) async {
    final db = await database;
    final r = await db
        .rawQuery('SELECT COUNT(*) AS c FROM sets WHERE exercise_id = ?', [id]);
    return (r.first['c'] as int?) ?? 0;
  }

  Future<void> deleteExercise(int id, {bool cascade = false}) async {
    final db = await database;
    await db.transaction((txn) async {
      if (cascade) {
        await txn.delete('sets', where: 'exercise_id = ?', whereArgs: [id]);
      }
      await txn.delete('exercises', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ---- Sets ----

  Future<List<WorkoutSet>> setsForDate(String date) async {
    final db = await database;
    final rows = await db.query(
      'sets',
      where: 'workout_date = ?',
      whereArgs: [date],
      orderBy: 'exercise_id, set_number',
    );
    return rows.map(WorkoutSet.fromMap).toList();
  }

  Future<List<WorkoutSet>> setsForExercise(int exerciseId) async {
    final db = await database;
    final rows = await db.query(
      'sets',
      where: 'exercise_id = ?',
      whereArgs: [exerciseId],
      orderBy: 'workout_date, set_number',
    );
    return rows.map(WorkoutSet.fromMap).toList();
  }

  Future<int> insertSet(WorkoutSet s) async {
    final db = await database;
    return db.insert('sets', s.toMap());
  }

  Future<int> updateSet(WorkoutSet s) async {
    final db = await database;
    return db.update('sets', s.toMap(),
        where: 'id = ?', whereArgs: [s.id]);
  }

  Future<int> deleteSet(int id) async {
    final db = await database;
    return db.delete('sets', where: 'id = ?', whereArgs: [id]);
  }

  Future<double> allTimeMaxRM(int exerciseId) async {
    final db = await database;
    final rows = await db.query(
      'sets',
      where: 'exercise_id = ? AND is_bodyweight = 0',
      whereArgs: [exerciseId],
    );
    double max = 0;
    for (final r in rows) {
      final s = WorkoutSet.fromMap(r);
      if (s.estimated1RM > max) max = s.estimated1RM;
    }
    return max;
  }

  // ---- Summaries ----

  /// Distinct workout dates, newest first, with totals for each.
  Future<List<DailySummary>> dailySummaries() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT
        workout_date,
        COUNT(DISTINCT exercise_id) AS ex_count,
        COUNT(*)                    AS set_count,
        SUM(weight * reps)          AS volume
      FROM sets
      GROUP BY workout_date
      ORDER BY workout_date DESC
    ''');
    return rows
        .map((r) => DailySummary(
              date: r['workout_date'] as String,
              exerciseCount: (r['ex_count'] as int?) ?? 0,
              setCount: (r['set_count'] as int?) ?? 0,
              totalVolumeKg: ((r['volume'] as num?) ?? 0).toDouble(),
            ))
        .toList();
  }

  /// Exercise IDs that have at least one set on a given date,
  /// ordered by their first set's primary key (insertion order).
  Future<List<int>> exerciseIdsForDate(String date) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT exercise_id, MIN(id) AS first_id
      FROM sets
      WHERE workout_date = ?
      GROUP BY exercise_id
      ORDER BY first_id
    ''', [date]);
    return rows.map((r) => r['exercise_id'] as int).toList();
  }
}
