import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/exercise.dart';
import 'exercise_picker.dart';

class EditTemplateScreen extends StatefulWidget {
  final int templateId;
  final String templateName;
  const EditTemplateScreen({
    super.key,
    required this.templateId,
    required this.templateName,
  });

  @override
  State<EditTemplateScreen> createState() => _EditTemplateScreenState();
}

class _EditTemplateScreenState extends State<EditTemplateScreen> {
  List<Exercise> _exercises = [];
  bool _loading = true;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper.instance;
    final ids = await db.templateExerciseIds(widget.templateId);
    final list = <Exercise>[];
    for (final id in ids) {
      final e = await db.getExercise(id);
      if (e != null) list.add(e);
    }
    if (!mounted) return;
    setState(() {
      _exercises = list;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await DatabaseHelper.instance.setTemplateExercises(
      widget.templateId,
      _exercises.map((e) => e.id!).toList(),
    );
    if (!mounted) return;
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Template saved')));
  }

  Future<void> _add() async {
    final picked = await ExercisePicker.show(
      context,
      excludeIds: _exercises.map((e) => e.id!).toSet(),
    );
    if (picked == null) return;
    setState(() {
      _exercises = [..._exercises, picked];
      _dirty = true;
    });
  }

  void _remove(int index) {
    setState(() {
      _exercises = [..._exercises]..removeAt(index);
      _dirty = true;
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final list = [..._exercises];
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);
    setState(() {
      _exercises = list;
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.templateName),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          if (_dirty)
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save',
              onPressed: _save,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Add exercise'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_dirty)
                  Container(
                    width: double.infinity,
                    color: Colors.amber.shade100,
                    padding: const EdgeInsets.all(8),
                    child: const Text(
                      'Unsaved changes — tap the save icon to keep them.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                Expanded(
                  child: _exercises.isEmpty
                      ? const Center(
                          child: Text(
                            'No exercises yet. Tap “Add exercise”.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        )
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.only(bottom: 96),
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
                              trailing: IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.black54),
                                onPressed: () => _remove(i),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
