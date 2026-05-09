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

class Template {
  final int? id;
  final String name;
  final int displayOrder;
  Template({this.id, required this.name, this.displayOrder = 0});

  factory Template.fromMap(Map<String, dynamic> m) => Template(
        id: m['id'] as int?,
        name: m['name'] as String,
        displayOrder: (m['display_order'] as int?) ?? 0,
      );
}

class BodyWeightEntry {
  final String date; // YYYY-MM-DD
  final double weightKg;
  final String? notes;

  BodyWeightEntry({required this.date, required this.weightKg, this.notes});

  factory BodyWeightEntry.fromMap(Map<String, dynamic> m) => BodyWeightEntry(
        date: m['date'] as String,
        weightKg: (m['weight_kg'] as num).toDouble(),
        notes: m['notes'] as String?,
      );
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
      version: 2,
      onCreate: (db, version) async {
        await _createV1(db);
        await _migrateToV2(db);
        await _seedExercises(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _migrateToV2(db);
      },
    );
  }

  Future<void> _createV1(Database db) async {
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
    await db.execute('CREATE INDEX idx_sets_date ON sets(workout_date)');
    await db.execute('CREATE INDEX idx_sets_ex ON sets(exercise_id)');
  }

  Future<void> _migrateToV2(Database db) async {
    final existingCols = await db.rawQuery('PRAGMA table_info(exercises)');
    final hasRest = existingCols.any((c) => c['name'] == 'rest_seconds');
    if (!hasRest) {
      await db.execute(
          'ALTER TABLE exercises ADD COLUMN rest_seconds INTEGER NOT NULL DEFAULT 90');
    }

    await db.execute('''
      CREATE TABLE IF NOT EXISTS day_exercises (
        workout_date TEXT NOT NULL,
        exercise_id INTEGER NOT NULL,
        position INTEGER NOT NULL,
        PRIMARY KEY (workout_date, exercise_id)
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_day_ex_date ON day_exercises(workout_date)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        display_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS template_exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        template_id INTEGER NOT NULL,
        exercise_id INTEGER NOT NULL,
        position INTEGER NOT NULL,
        FOREIGN KEY (template_id) REFERENCES templates(id),
        FOREIGN KEY (exercise_id) REFERENCES exercises(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS body_weights (
        date TEXT PRIMARY KEY,
        weight_kg REAL NOT NULL,
        notes TEXT
      )
    ''');
  }

  Future<void> _seedExercises(Database db) async {
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
        'rest_seconds': 90,
      });
    }
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

  Future<int> insertExercise(String name, {int restSeconds = 90}) async {
    final db = await database;
    final maxOrderRow =
        await db.rawQuery('SELECT MAX(display_order) AS m FROM exercises');
    final nextOrder = ((maxOrderRow.first['m'] as int?) ?? -1) + 1;
    return db.insert('exercises', {
      'name': name,
      'display_order': nextOrder,
      'rest_seconds': restSeconds,
    });
  }

  Future<int> renameExercise(int id, String name) async {
    final db = await database;
    return db.update('exercises', {'name': name},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> setRestSeconds(int id, int seconds) async {
    final db = await database;
    return db.update('exercises', {'rest_seconds': seconds},
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
    final r = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM sets WHERE exercise_id = ?', [id]);
    return (r.first['c'] as int?) ?? 0;
  }

  Future<void> deleteExercise(int id, {bool cascade = false}) async {
    final db = await database;
    await db.transaction((txn) async {
      if (cascade) {
        await txn.delete('sets', where: 'exercise_id = ?', whereArgs: [id]);
        await txn.delete('day_exercises',
            where: 'exercise_id = ?', whereArgs: [id]);
        await txn.delete('template_exercises',
            where: 'exercise_id = ?', whereArgs: [id]);
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

  // ---- Day exercises (which exercises are on a given workout day) ----

  /// Returns exercise IDs for the given date in card display order.
  ///
  /// Lazily backfills [day_exercises] rows for any exercise that has sets
  /// on this date but no positional row yet (i.e. legacy data).
  Future<List<int>> exerciseIdsForDate(String date) async {
    final db = await database;
    final rows = await db.query('day_exercises',
        where: 'workout_date = ?',
        whereArgs: [date],
        orderBy: 'position');
    final positioned = rows.map((r) => r['exercise_id'] as int).toList();

    final fromSets = await db.rawQuery('''
      SELECT exercise_id, MIN(id) AS first_id
      FROM sets
      WHERE workout_date = ?
      GROUP BY exercise_id
      ORDER BY first_id
    ''', [date]);
    final setIds =
        fromSets.map((r) => r['exercise_id'] as int).toList();

    final missing = setIds.where((id) => !positioned.contains(id)).toList();
    if (missing.isNotEmpty) {
      var nextPos = positioned.length;
      final batch = db.batch();
      for (final id in missing) {
        batch.insert('day_exercises', {
          'workout_date': date,
          'exercise_id': id,
          'position': nextPos++,
        });
      }
      await batch.commit(noResult: true);
      positioned.addAll(missing);
    }

    return positioned;
  }

  Future<void> addExerciseToDay(String date, int exerciseId) async {
    final db = await database;
    final existing = await db.query('day_exercises',
        where: 'workout_date = ? AND exercise_id = ?',
        whereArgs: [date, exerciseId]);
    if (existing.isNotEmpty) return;
    final maxRow = await db.rawQuery(
        'SELECT MAX(position) AS m FROM day_exercises WHERE workout_date = ?',
        [date]);
    final nextPos = ((maxRow.first['m'] as int?) ?? -1) + 1;
    await db.insert('day_exercises', {
      'workout_date': date,
      'exercise_id': exerciseId,
      'position': nextPos,
    });
  }

  Future<void> removeExerciseFromDay(String date, int exerciseId,
      {bool cascadeSets = false}) async {
    final db = await database;
    await db.transaction((txn) async {
      if (cascadeSets) {
        await txn.delete('sets',
            where: 'workout_date = ? AND exercise_id = ?',
            whereArgs: [date, exerciseId]);
      }
      await txn.delete('day_exercises',
          where: 'workout_date = ? AND exercise_id = ?',
          whereArgs: [date, exerciseId]);
    });
  }

  Future<void> reorderDayExercises(
      String date, List<int> orderedExerciseIds) async {
    final db = await database;
    final batch = db.batch();
    for (var i = 0; i < orderedExerciseIds.length; i++) {
      batch.update('day_exercises', {'position': i},
          where: 'workout_date = ? AND exercise_id = ?',
          whereArgs: [date, orderedExerciseIds[i]]);
    }
    await batch.commit(noResult: true);
  }

  // ---- Summaries ----

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

  // ---- Templates ----

  Future<List<Template>> listTemplates() async {
    final db = await database;
    final rows =
        await db.query('templates', orderBy: 'display_order, name');
    return rows.map(Template.fromMap).toList();
  }

  Future<int> insertTemplate(String name) async {
    final db = await database;
    final maxRow =
        await db.rawQuery('SELECT MAX(display_order) AS m FROM templates');
    final next = ((maxRow.first['m'] as int?) ?? -1) + 1;
    return db.insert(
        'templates', {'name': name, 'display_order': next});
  }

  Future<int> renameTemplate(int id, String name) async {
    final db = await database;
    return db.update('templates', {'name': name},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteTemplate(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn
          .delete('template_exercises', where: 'template_id = ?', whereArgs: [id]);
      await txn.delete('templates', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<int>> templateExerciseIds(int templateId) async {
    final db = await database;
    final rows = await db.query('template_exercises',
        where: 'template_id = ?',
        whereArgs: [templateId],
        orderBy: 'position');
    return rows.map((r) => r['exercise_id'] as int).toList();
  }

  Future<void> setTemplateExercises(
      int templateId, List<int> orderedExerciseIds) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('template_exercises',
          where: 'template_id = ?', whereArgs: [templateId]);
      for (var i = 0; i < orderedExerciseIds.length; i++) {
        await txn.insert('template_exercises', {
          'template_id': templateId,
          'exercise_id': orderedExerciseIds[i],
          'position': i,
        });
      }
    });
  }

  /// Apply a template to a workout date — adds any missing exercises
  /// onto [day_exercises] in the template's order.
  Future<void> applyTemplate(int templateId, String date) async {
    final ids = await templateExerciseIds(templateId);
    for (final exId in ids) {
      await addExerciseToDay(date, exId);
    }
  }

  // ---- Body weight ----

  Future<List<BodyWeightEntry>> listBodyWeights() async {
    final db = await database;
    final rows =
        await db.query('body_weights', orderBy: 'date DESC');
    return rows.map(BodyWeightEntry.fromMap).toList();
  }

  Future<void> upsertBodyWeight(BodyWeightEntry e) async {
    final db = await database;
    await db.insert(
      'body_weights',
      {
        'date': e.date,
        'weight_kg': e.weightKg,
        'notes': e.notes,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteBodyWeight(String date) async {
    final db = await database;
    await db.delete('body_weights', where: 'date = ?', whereArgs: [date]);
  }
}
