import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AddSetResult {
  final double weight;
  final int reps;
  final bool isBodyweight;

  AddSetResult({
    required this.weight,
    required this.reps,
    required this.isBodyweight,
  });
}

class AddSetSheet extends StatefulWidget {
  final String exerciseName;
  final double? initialWeight;
  final int? initialReps;
  final bool initialBodyweight;
  final bool isEdit;

  const AddSetSheet({
    super.key,
    required this.exerciseName,
    this.initialWeight,
    this.initialReps,
    this.initialBodyweight = false,
    this.isEdit = false,
  });

  @override
  State<AddSetSheet> createState() => _AddSetSheetState();
}

class _AddSetSheetState extends State<AddSetSheet> {
  final _weightCtrl = TextEditingController();
  final _repsCtrl = TextEditingController();
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
    super.dispose();
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
            title: const Text('Bodyweight (自重)'),
            value: _bodyweight,
            activeColor: Colors.red,
            onChanged: (v) => setState(() => _bodyweight = v),
          ),
          if (!_bodyweight)
            TextField(
              controller: _weightCtrl,
              autofocus: !widget.isEdit,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              ],
              decoration: const InputDecoration(labelText: 'Weight (kg)'),
            ),
          TextField(
            controller: _repsCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Reps'),
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
    Navigator.pop(
      context,
      AddSetResult(
        weight: weight,
        reps: reps,
        isBodyweight: _bodyweight,
      ),
    );
  }
}
