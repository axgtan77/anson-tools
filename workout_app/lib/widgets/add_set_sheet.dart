import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/plate_calculator_screen.dart';

class AddSetResult {
  final double weight;
  final int reps;
  final bool isBodyweight;
  final String? notes;

  AddSetResult({
    required this.weight,
    required this.reps,
    required this.isBodyweight,
    required this.notes,
  });
}

class AddSetSheet extends StatefulWidget {
  final String exerciseName;
  final double? initialWeight;
  final int? initialReps;
  final bool initialBodyweight;
  final String? initialNotes;
  final bool isEdit;

  const AddSetSheet({
    super.key,
    required this.exerciseName,
    this.initialWeight,
    this.initialReps,
    this.initialBodyweight = false,
    this.initialNotes,
    this.isEdit = false,
  });

  @override
  State<AddSetSheet> createState() => _AddSetSheetState();
}

class _AddSetSheetState extends State<AddSetSheet> {
  final _weightCtrl = TextEditingController();
  final _repsCtrl = TextEditingController();
  late final _notesCtrl =
      TextEditingController(text: widget.initialNotes ?? '');
  late bool _bodyweight = widget.initialBodyweight;

  @override
  void initState() {
    super.initState();
    if (widget.initialWeight != null && widget.initialWeight! > 0) {
      _weightCtrl.text = widget.initialWeight!.toStringAsFixed(1);
    }
    if (widget.initialReps != null) {
      _repsCtrl.text = widget.initialReps!.toString();
    }
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _openPlateCalc() async {
    final target = double.tryParse(_weightCtrl.text);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlateCalculatorScreen(initialTarget: target),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.isEdit
                ? 'Edit set — ${widget.exerciseName}'
                : widget.exerciseName,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Bodyweight'),
            value: _bodyweight,
            activeColor: Colors.red,
            onChanged: (v) => setState(() => _bodyweight = v),
          ),
          if (!_bodyweight)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weightCtrl,
                    autofocus: !widget.isEdit,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                    ],
                    decoration:
                        const InputDecoration(labelText: 'Weight (kg)'),
                  ),
                ),
                IconButton(
                  tooltip: 'Plate calculator',
                  icon: const Icon(Icons.calculate_outlined),
                  onPressed: _openPlateCalc,
                ),
              ],
            ),
          TextField(
            controller: _repsCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Reps'),
          ),
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
              labelText: 'Notes (RPE, form cues, …)',
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _save,
            child: Text(widget.isEdit ? 'Update set' : 'Save set'),
          ),
        ],
      ),
    );
  }

  void _save() {
    final reps = int.tryParse(_repsCtrl.text);
    if (reps == null || reps <= 0) return;
    final weight =
        _bodyweight ? 0.0 : double.tryParse(_weightCtrl.text) ?? 0;
    if (!_bodyweight && weight <= 0) return;
    final notes = _notesCtrl.text.trim();
    Navigator.pop(
      context,
      AddSetResult(
        weight: weight,
        reps: reps,
        isBodyweight: _bodyweight,
        notes: notes.isEmpty ? null : notes,
      ),
    );
  }
}
