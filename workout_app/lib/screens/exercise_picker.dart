import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/exercise.dart';

/// Modal screen that lets the user pick an existing exercise or create a new
/// one. Returns the chosen [Exercise], or null if cancelled.
class ExercisePicker extends StatefulWidget {
  final Set<int> excludeIds;
  const ExercisePicker({super.key, this.excludeIds = const {}});

  static Future<Exercise?> show(BuildContext context,
      {Set<int> excludeIds = const {}}) {
    return Navigator.of(context).push<Exercise>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ExercisePicker(excludeIds: excludeIds),
      ),
    );
  }

  @override
  State<ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<ExercisePicker> {
  List<Exercise> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await DatabaseHelper.instance.listExercises();
    if (!mounted) return;
    setState(() {
      _all = all;
      _loading = false;
    });
  }

  Future<void> _createNew() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NameDialog(title: 'New exercise'),
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      final id = await DatabaseHelper.instance.insertExercise(name.trim());
      final ex = await DatabaseHelper.instance.getExercise(id);
      if (ex != null && mounted) Navigator.pop(context, ex);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That name already exists.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible =
        _all.where((e) => !widget.excludeIds.contains(e.id)).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add exercise'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                ListTile(
                  leading:
                      const Icon(Icons.add_circle, color: Colors.red),
                  title: const Text('Create new exercise…'),
                  onTap: _createNew,
                ),
                const Divider(height: 1),
                if (visible.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'All exercises are already on this workout.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  ),
                ...visible.map((e) => ListTile(
                      title: Text(e.name),
                      onTap: () => Navigator.pop(context, e),
                    )),
              ],
            ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  final String title;
  final String? initial;
  const _NameDialog({required this.title, this.initial});

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _ctrl = TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Exercise name'),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.pop(context, _ctrl.text),
            child: const Text('OK')),
      ],
    );
  }
}

/// Reused by ManageExercisesScreen for rename.
class RenameExerciseDialog {
  static Future<String?> show(BuildContext context, String initial) {
    return showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(title: 'Rename exercise', initial: initial),
    );
  }
}
