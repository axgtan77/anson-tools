import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../db/database_helper.dart';
import '../models/workout_set.dart';

class ImportResult {
  final int rowsRead;
  final int setsInserted;
  final int exercisesCreated;
  final List<String> errors;

  ImportResult({
    required this.rowsRead,
    required this.setsInserted,
    required this.exercisesCreated,
    required this.errors,
  });
}

const _headers = [
  'date',
  'exercise',
  'set_number',
  'weight_kg',
  'reps',
  'is_bodyweight',
  'notes',
];

Future<File> exportSetsCsv() async {
  final db = DatabaseHelper.instance;
  final exercises = await db.listExercises();
  final nameById = {for (final e in exercises) e.id!: e.name};
  final sets = await db.allSets();

  final rows = <List<dynamic>>[
    _headers,
    for (final s in sets)
      [
        s.workoutDate,
        nameById[s.exerciseId] ?? '#${s.exerciseId}',
        s.setNumber,
        s.weight,
        s.reps,
        s.isBodyweight ? 1 : 0,
        s.notes ?? '',
      ],
  ];

  final csv = const ListToCsvConverter().convert(rows);
  // BOM + UTF-8 bytes so Excel detects the encoding correctly and Japanese
  // exercise names round-trip cleanly.
  final bytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(csv)];

  final dir = await getApplicationDocumentsDirectory();
  final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
  final file = File(p.join(dir.path, 'workout_log_$stamp.csv'));
  await file.writeAsBytes(bytes, flush: true);
  return file;
}

Future<ImportResult> importSetsCsv(File file) async {
  final db = DatabaseHelper.instance;
  final raw = await file.readAsString();
  final noBom = raw.startsWith('﻿') ? raw.substring(1) : raw;
  // Normalise line endings so the parser handles \r\n, \r and \n alike.
  final normalised =
      noBom.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final rows = const CsvToListConverter(
    eol: '\n',
    shouldParseNumbers: false,
  ).convert(normalised);

  if (rows.isEmpty) {
    return ImportResult(
        rowsRead: 0, setsInserted: 0, exercisesCreated: 0, errors: const []);
  }

  // Determine column indexes from header row.
  final header = rows.first.map((c) => c.toString().trim()).toList();
  int idx(String name) => header.indexOf(name);
  final iDate = idx('date');
  final iEx = idx('exercise');
  final iSet = idx('set_number');
  final iWeight = idx('weight_kg');
  final iReps = idx('reps');
  final iBw = idx('is_bodyweight');
  final iNotes = idx('notes');

  if ([iDate, iEx, iWeight, iReps].any((i) => i < 0)) {
    return ImportResult(
      rowsRead: 0,
      setsInserted: 0,
      exercisesCreated: 0,
      errors: ['Missing required columns: date, exercise, weight_kg, reps'],
    );
  }

  final errors = <String>[];
  var inserted = 0;
  var created = 0;

  // Track per-(date, exercise) max set_number for auto-numbering when the
  // CSV omits set_number.
  final autoCounters = <String, int>{};

  for (var r = 1; r < rows.length; r++) {
    final row = rows[r];
    if (row.every((c) => c.toString().trim().isEmpty)) continue;
    try {
      final date = row[iDate].toString().trim();
      final exName = row[iEx].toString().trim();
      if (date.isEmpty || exName.isEmpty) {
        errors.add('Row ${r + 1}: missing date or exercise');
        continue;
      }
      final weight = double.tryParse(row[iWeight].toString()) ?? 0;
      final reps = int.tryParse(row[iReps].toString()) ?? 0;
      final isBw = iBw >= 0 &&
          row[iBw].toString().trim() != '0' &&
          row[iBw].toString().toLowerCase() != 'false' &&
          row[iBw].toString().trim().isNotEmpty;
      if (reps <= 0) {
        errors.add('Row ${r + 1}: reps must be > 0');
        continue;
      }

      var ex = await db.getExerciseByName(exName);
      if (ex == null) {
        final id = await db.insertExercise(exName);
        ex = await db.getExercise(id);
        created++;
      }

      int setNum;
      if (iSet >= 0 && row[iSet].toString().trim().isNotEmpty) {
        setNum = int.tryParse(row[iSet].toString()) ?? 1;
      } else {
        final key = '$date|${ex!.id}';
        autoCounters[key] = (autoCounters[key] ?? 0) + 1;
        setNum = autoCounters[key]!;
      }

      final notes = iNotes >= 0 ? row[iNotes].toString().trim() : '';
      await db.insertSet(WorkoutSet(
        exerciseId: ex!.id!,
        workoutDate: date,
        setNumber: setNum,
        weight: isBw ? 0 : weight,
        reps: reps,
        isBodyweight: isBw,
        notes: notes.isEmpty ? null : notes,
      ));
      await db.addExerciseToDay(date, ex.id!);
      inserted++;
    } catch (e) {
      errors.add('Row ${r + 1}: $e');
    }
  }

  return ImportResult(
    rowsRead: rows.length - 1,
    setsInserted: inserted,
    exercisesCreated: created,
    errors: errors,
  );
}
