import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database_helper.dart';
import '../models/exercise.dart';
import 'exercise_picker.dart';

class ManageExercisesScreen extends StatefulWidget {
  const ManageExercisesScreen({super.key});

  @override
  State<ManageExercisesScreen> createState() =>
      _ManageExercisesScreenState();
}

class _ManageExercisesScreenState extends State<ManageExercisesScreen> {
  List<Exercise> _exercises = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await DatabaseHelper.instance.listExercises();
    if (!mounted) return;
    setState(() {
      _exercises = list;
      _loading = false;
    });
  }

  Future<void> _rename(Exercise e) async {
    final newName = await RenameExerciseDialog.show(context, e.name);
    if (newName == null || newName.trim().isEmpty) return;
    if (newName.trim() == e.name) return;
    try {
      await DatabaseHelper.instance.renameExercise(e.id!, newName.trim());
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That name already exists.')),
      );
    }
  }

  Future<void> _editRest(Exercise e) async {
    final ctrl = TextEditingController(text: e.restSeconds.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${e.name} — rest seconds'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Seconds'),
          onSubmitted: (v) =>
              Navigator.pop(context, int.tryParse(v) ?? e.restSeconds),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(
                  context, int.tryParse(ctrl.text) ?? e.restSeconds),
              child: const Text('OK')),
        ],
      ),
    );
    if (result == null || result < 0) return;
    await DatabaseHelper.instance.setRestSeconds(e.id!, result);
    await _load();
  }

  Future<void> _delete(Exercise e) async {
    final count =
        await DatabaseHelper.instance.setCountForExercise(e.id!);
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete "${e.name}"?'),
        content: Text(
          count == 0
              ? 'No sets are logged for this exercise.'
              : 'This will also delete $count set(s) across every workout.',
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
    if (confirmed != true) return;

    await DatabaseHelper.instance
        .deleteExercise(e.id!, cascade: count > 0);
    await _load();
  }

  Future<void> _create() async {
    final name = await RenameExerciseDialog.show(context, '');
    if (name == null || name.trim().isEmpty) return;
    try {
      await DatabaseHelper.instance.insertExercise(name.trim());
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That name already exists.')),
      );
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final list = [..._exercises];
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);
    setState(() => _exercises = list);
    DatabaseHelper.instance.reorderExercises(list);
  }

  String _fmtRest(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return s == 0 ? '${m}m' : '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage exercises'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red,
        onPressed: _create,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              buildDefaultDragHandles: false,
              itemCount: _exercises.length,
              onReorder: _onReorder,
              itemBuilder: (context, i) {
                final e = _exercises[i];
                return ListTile(
                  key: ValueKey(e.id),
                  leading: ReorderableDragStartListener(
                    index: i,
                    child: const Icon(Icons.drag_handle,
                        color: Colors.black45),
                  ),
                  title: Text(e.name),
                  subtitle: GestureDetector(
                    onTap: () => _editRest(e),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Rest: ${_fmtRest(e.restSeconds)}  (tap to change)',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                      ),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.black54),
                        onPressed: () => _rename(e),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.black54),
                        onPressed: () => _delete(e),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
