import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../db/database_helper.dart';
import '../models/exercise.dart';
import '../models/workout_set.dart';
import '../utils/csv_io.dart';
import '../widgets/add_set_sheet.dart';
import '../widgets/exercise_card.dart';
import '../widgets/rest_timer_bar.dart';
import 'body_weight_screen.dart';
import 'exercise_detail_screen.dart';
import 'exercise_picker.dart';
import 'history_screen.dart';
import 'manage_exercises_screen.dart';
import 'plate_calculator_screen.dart';
import 'settings_screen.dart';
import 'templates_screen.dart';

class WorkoutScreen extends StatefulWidget {
  final String date;
  const WorkoutScreen({super.key, required this.date});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  List<Exercise> _exercises = [];
  Map<int, List<WorkoutSet>> _setsByExercise = {};
  Map<int, double> _maxRMByExercise = {};
  String? _dayNote;
  bool _loading = true;

  DateTime? _restEndsAt;
  String _restExerciseName = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = DatabaseHelper.instance;

    final ids = await db.exerciseIdsForDate(widget.date);
    final allSets = await db.setsForDate(widget.date);

    final byEx = <int, List<WorkoutSet>>{};
    for (final s in allSets) {
      byEx.putIfAbsent(s.exerciseId, () => []).add(s);
    }
    for (final list in byEx.values) {
      list.sort((a, b) => a.setNumber.compareTo(b.setNumber));
    }

    final exercises = <Exercise>[];
    for (final id in ids) {
      final e = await db.getExercise(id);
      if (e != null) exercises.add(e);
    }

    final maxRM = <int, double>{};
    for (final e in exercises) {
      maxRM[e.id!] = await db.allTimeMaxRM(e.id!);
    }

    final note = await db.getWorkoutNote(widget.date);

    if (!mounted) return;
    setState(() {
      _exercises = exercises;
      _setsByExercise = byEx;
      _maxRMByExercise = maxRM;
      _dayNote = note;
      _loading = false;
    });
  }

  Future<void> _editDayNote() async {
    final ctrl = TextEditingController(text: _dayNote ?? '');
    final result = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Workout notes'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 5,
          minLines: 3,
          decoration: const InputDecoration(
            hintText: 'How did the session feel? Any cues for next time?',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (result == null) return;
    await DatabaseHelper.instance.setWorkoutNote(widget.date, result);
    await _load();
  }

  Future<void> _addExerciseToWorkout() async {
    final picked = await ExercisePicker.show(
      context,
      excludeIds: _exercises.map((e) => e.id!).toSet(),
    );
    if (picked == null) return;
    await DatabaseHelper.instance
        .addExerciseToDay(widget.date, picked.id!);
    await _load();
    await _addSet(picked);
  }

  Future<void> _addSet(Exercise ex) async {
    final existing = _setsByExercise[ex.id!] ?? [];
    final last = existing.isNotEmpty ? existing.last : null;
    final result = await showModalBottomSheet<AddSetResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddSetSheet(
        exerciseName: ex.name,
        initialWeight:
            last == null || last.isBodyweight ? null : last.weight,
        initialReps: last?.reps,
        initialBodyweight: last?.isBodyweight ?? false,
      ),
    );
    if (result == null) return;
    final nextNumber = existing.isEmpty
        ? 1
        : existing.map((s) => s.setNumber).reduce((a, b) => a > b ? a : b) +
            1;
    await DatabaseHelper.instance.insertSet(WorkoutSet(
      exerciseId: ex.id!,
      workoutDate: widget.date,
      setNumber: nextNumber,
      weight: result.weight,
      reps: result.reps,
      isBodyweight: result.isBodyweight,
      notes: result.notes,
    ));
    _startRestTimer(ex);
    await _load();
  }

  Future<void> _editSet(WorkoutSet s) async {
    final ex = _exercises.firstWhere((e) => e.id == s.exerciseId);
    final result = await showModalBottomSheet<AddSetResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddSetSheet(
        exerciseName: ex.name,
        initialWeight: s.isBodyweight ? null : s.weight,
        initialReps: s.reps,
        initialBodyweight: s.isBodyweight,
        initialNotes: s.notes,
        isEdit: true,
      ),
    );
    if (result == null) return;
    await DatabaseHelper.instance.updateSet(WorkoutSet(
      id: s.id,
      exerciseId: s.exerciseId,
      workoutDate: s.workoutDate,
      setNumber: s.setNumber,
      weight: result.weight,
      reps: result.reps,
      isBodyweight: result.isBodyweight,
      notes: result.notes,
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
              ? 'BW × ${s.reps} reps'
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

  Future<void> _removeFromDay(Exercise ex) async {
    final sets = _setsByExercise[ex.id!] ?? const [];
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Remove "${ex.name}" from this workout?'),
        content: Text(
          sets.isEmpty
              ? 'No sets are logged for it on this day.'
              : 'This will also delete ${sets.length} logged set(s) for this date.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    await DatabaseHelper.instance.removeExerciseFromDay(
      widget.date,
      ex.id!,
      cascadeSets: sets.isNotEmpty,
    );
    await _load();
  }

  void _onReorderCards(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final list = [..._exercises];
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);
    setState(() => _exercises = list);
    DatabaseHelper.instance.reorderDayExercises(
      widget.date,
      list.map((e) => e.id!).toList(),
    );
  }

  void _startRestTimer(Exercise ex) {
    if (ex.restSeconds <= 0) return;
    setState(() {
      _restEndsAt =
          DateTime.now().add(Duration(seconds: ex.restSeconds));
      _restExerciseName = ex.name;
    });
  }

  void _skipRest() => setState(() => _restEndsAt = null);

  void _addRestTime() {
    final base = _restEndsAt ?? DateTime.now();
    setState(() =>
        _restEndsAt = base.add(const Duration(seconds: 30)));
  }

  Future<void> _openExerciseDetail(Exercise ex) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseDetailScreen(exercise: ex),
      ),
    );
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

  Future<void> _exportCsv() async {
    try {
      final file = await exportSetsCsv();
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Workout log export',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _importCsv() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (picked == null || picked.files.single.path == null) return;
    final result = await importSetsCsv(File(picked.files.single.path!));
    if (!mounted) return;
    await _load();
    final msg = StringBuffer(
      'Imported ${result.setsInserted} of ${result.rowsRead} rows. '
      '${result.exercisesCreated} new exercises.',
    );
    if (result.errors.isNotEmpty) {
      msg.writeln();
      msg.writeln('${result.errors.length} error(s).');
    }
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Import done'),
        content: Text(msg.toString()),
        actions: [
          if (result.errors.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Import errors'),
                    content: SingleChildScrollView(
                      child: Text(result.errors.join('\n')),
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK')),
                    ],
                  ),
                );
              },
              child: const Text('Show errors'),
            ),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _applyTemplate() async {
    final t = await TemplatesScreen.pick(context);
    if (t == null) return;
    await DatabaseHelper.instance.applyTemplate(t.id!, widget.date);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Applied template: ${t.name}')),
    );
  }

  Future<void> _navTo(Widget screen, {bool reload = false}) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => screen));
    if (reload) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final headerDate = widget.date.replaceAll('-', '/');
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        onPressed: _addExerciseToWorkout,
        icon: const Icon(Icons.add),
        label: const Text('Add exercise'),
      ),
      bottomSheet: RestTimerBar(
        endsAt: _restEndsAt,
        exerciseName: _restExerciseName,
        onSkip: _skipRest,
        onAddTime: _addRestTime,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              dateLabel: '$headerDate WorkOut',
              onTapDate: _pickDate,
              onHistory: () => _navTo(const HistoryScreen()),
              onMenuSelected: (v) {
                switch (v) {
                  case 'apply':
                    _applyTemplate();
                    break;
                  case 'templates':
                    _navTo(const TemplatesScreen());
                    break;
                  case 'manage':
                    _navTo(const ManageExercisesScreen(), reload: true);
                    break;
                  case 'bodyweight':
                    _navTo(const BodyWeightScreen());
                    break;
                  case 'plate':
                    _navTo(const PlateCalculatorScreen());
                    break;
                  case 'export':
                    _exportCsv();
                    break;
                  case 'import':
                    _importCsv();
                    break;
                  case 'settings':
                    _navTo(const SettingsScreen(), reload: true);
                    break;
                }
              },
            ),
            _DayNoteBanner(notes: _dayNote, onTap: _editDayNote),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _exercises.isEmpty
                      ? const _EmptyDay()
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.only(bottom: 160),
                          buildDefaultDragHandles: false,
                          itemCount: _exercises.length,
                          onReorder: _onReorderCards,
                          itemBuilder: (context, i) {
                            final e = _exercises[i];
                            return ExerciseCard(
                              key: ValueKey('day-ex-${e.id}'),
                              exercise: e,
                              sets: _setsByExercise[e.id!] ?? const [],
                              allTimeMaxRM:
                                  _maxRMByExercise[e.id!] ?? 0,
                              onAddSet: () => _addSet(e),
                              onTapSet: _editSet,
                              onLongPressSet: _deleteSet,
                              onTapTitle: () => _openExerciseDetail(e),
                              onRemoveFromDay: () => _removeFromDay(e),
                              dragIndex: i,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String dateLabel;
  final VoidCallback onTapDate;
  final VoidCallback onHistory;
  final ValueChanged<String> onMenuSelected;

  const _Header({
    required this.dateLabel,
    required this.onTapDate,
    required this.onHistory,
    required this.onMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.red,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onTapDate,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      dateLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.calendar_today,
                      color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            tooltip: 'History',
            onPressed: onHistory,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: onMenuSelected,
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'apply', child: Text('Apply template')),
              PopupMenuItem(
                  value: 'templates',
                  child: Text('Manage templates')),
              PopupMenuItem(
                  value: 'manage',
                  child: Text('Manage exercises')),
              PopupMenuDivider(),
              PopupMenuItem(
                  value: 'bodyweight', child: Text('Body weight')),
              PopupMenuItem(
                  value: 'plate', child: Text('Plate calculator')),
              PopupMenuDivider(),
              PopupMenuItem(
                  value: 'export', child: Text('Export CSV')),
              PopupMenuItem(
                  value: 'import', child: Text('Import CSV')),
              PopupMenuDivider(),
              PopupMenuItem(
                  value: 'settings', child: Text('Settings')),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayNoteBanner extends StatelessWidget {
  final String? notes;
  final VoidCallback onTap;
  const _DayNoteBanner({required this.notes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasNotes = notes != null && notes!.isNotEmpty;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        color: hasNotes ? Colors.amber.shade50 : Colors.grey.shade50,
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Icon(
              hasNotes ? Icons.sticky_note_2 : Icons.edit_note,
              size: 18,
              color: Colors.black54,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasNotes ? notes! : 'Add workout notes…',
                style: TextStyle(
                  color: hasNotes ? Colors.black87 : Colors.black45,
                  fontSize: 13,
                  fontStyle:
                      hasNotes ? FontStyle.normal : FontStyle.italic,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center, size: 56, color: Colors.black26),
            SizedBox(height: 12),
            Text(
              'No exercises logged for this day yet.\n'
              'Tap “Add exercise” or apply a template from the menu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
