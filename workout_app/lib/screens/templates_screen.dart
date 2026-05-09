import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import 'edit_template_screen.dart';

class TemplatesScreen extends StatefulWidget {
  /// When true, tapping a template returns it instead of opening the editor.
  final bool pickerMode;
  const TemplatesScreen({super.key, this.pickerMode = false});

  static Future<Template?> pick(BuildContext context) {
    return Navigator.of(context).push<Template>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const TemplatesScreen(pickerMode: true),
      ),
    );
  }

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  List<Template> _templates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await DatabaseHelper.instance.listTemplates();
    if (!mounted) return;
    setState(() {
      _templates = list;
      _loading = false;
    });
  }

  Future<void> _create() async {
    final name = await _promptName(context, title: 'New template');
    if (name == null || name.trim().isEmpty) return;
    try {
      final id =
          await DatabaseHelper.instance.insertTemplate(name.trim());
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EditTemplateScreen(
            templateId: id,
            templateName: name.trim(),
          ),
        ),
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That name already exists.')),
      );
    }
  }

  Future<void> _rename(Template t) async {
    final name =
        await _promptName(context, title: 'Rename template', initial: t.name);
    if (name == null || name.trim().isEmpty || name.trim() == t.name) {
      return;
    }
    try {
      await DatabaseHelper.instance.renameTemplate(t.id!, name.trim());
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That name already exists.')),
      );
    }
  }

  Future<void> _delete(Template t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete template "${t.name}"?'),
        content: const Text('Logged workouts won\'t be affected.'),
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
    await DatabaseHelper.instance.deleteTemplate(t.id!);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pickerMode ? 'Apply template' : 'Templates'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: widget.pickerMode
          ? null
          : FloatingActionButton(
              backgroundColor: Colors.red,
              onPressed: _create,
              child: const Icon(Icons.add, color: Colors.white),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _templates.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      widget.pickerMode
                          ? 'No templates yet. Create one in the menu first.'
                          : 'No templates yet. Tap + to create one.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: _templates.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final t = _templates[i];
                    return ListTile(
                      title: Text(t.name),
                      trailing: widget.pickerMode
                          ? const Icon(Icons.chevron_right)
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.black54),
                                  onPressed: () => _rename(t),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.black54),
                                  onPressed: () => _delete(t),
                                ),
                              ],
                            ),
                      onTap: () async {
                        if (widget.pickerMode) {
                          Navigator.pop(context, t);
                          return;
                        }
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditTemplateScreen(
                              templateId: t.id!,
                              templateName: t.name,
                            ),
                          ),
                        );
                        await _load();
                      },
                    );
                  },
                ),
    );
  }
}

Future<String?> _promptName(BuildContext context,
    {required String title, String? initial}) {
  final ctrl = TextEditingController(text: initial ?? '');
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Template name'),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('OK')),
      ],
    ),
  );
}
