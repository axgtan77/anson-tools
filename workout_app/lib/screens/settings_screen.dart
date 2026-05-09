import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/one_rm.dart';
import '../utils/settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late OneRMFormula _formula = FormulaSettings.current;
  late int _restSeconds = AppSettings.defaultRestSeconds;

  Future<void> _editRest() async {
    final ctrl = TextEditingController(text: _restSeconds.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Default rest seconds'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Seconds'),
          onSubmitted: (v) => Navigator.pop(
              context, int.tryParse(v) ?? _restSeconds),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(
                  context, int.tryParse(ctrl.text) ?? _restSeconds),
              child: const Text('OK')),
        ],
      ),
    );
    if (result == null || result < 0) return;
    await setDefaultRest(result);
    setState(() => _restSeconds = result);
  }

  String _formulaLabel(OneRMFormula f) {
    switch (f) {
      case OneRMFormula.epley:
        return 'Epley — w × (1 + reps/30)';
      case OneRMFormula.brzycki:
        return 'Brzycki — w × 36/(37 − reps)';
      case OneRMFormula.oConner:
        return 'O\'Conner — w × (1 + 0.025·reps)  (matches 筋トレMEMO)';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: Text('1RM formula',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.black54)),
          ),
          ...OneRMFormula.values.map(
            (f) => RadioListTile<OneRMFormula>(
              value: f,
              groupValue: _formula,
              activeColor: Colors.red,
              title: Text(_formulaLabel(f)),
              onChanged: (v) async {
                if (v == null) return;
                await setFormula(v);
                setState(() => _formula = v);
              },
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Defaults',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.black54)),
          ),
          ListTile(
            title: const Text('Default rest seconds'),
            subtitle: const Text(
                'Used when creating a new exercise. Existing exercises keep their own value.'),
            trailing: Text('${_restSeconds}s',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            onTap: _editRest,
          ),
        ],
      ),
    );
  }
}
