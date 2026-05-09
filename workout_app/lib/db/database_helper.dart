import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/exercise.dart';
import '../models/workout_set.dart';

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

  Future<List<Exercise>> listExercises() async {
    final db = await database;
    final rows =
        await db.query('exercises', orderBy: 'display_order, name');
    return rows.map(Exercise.fromMap).toList();
  }

  Future<int> insertExercise(Exercise e) async {
    final db = await database;
    return db.insert('exercises', e.toMap());
  }

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

  Future<int> insertSet(WorkoutSet s) async {
    final db = await database;
    return db.insert('sets', s.toMap());
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

  Future<List<String>> listWorkoutDates() async {
    final db = await database;
    final rows = await db.rawQuery(
        'SELECT DISTINCT workout_date FROM sets ORDER BY workout_date DESC');
    return rows.map((r) => r['workout_date'] as String).toList();
  }
}
