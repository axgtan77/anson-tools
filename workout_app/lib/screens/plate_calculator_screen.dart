import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/format.dart';

class PlateCalculatorScreen extends StatefulWidget {
  final double? initialTarget;
  const PlateCalculatorScreen({super.key, this.initialTarget});

  @override
  State<PlateCalculatorScreen> createState() =>
      _PlateCalculatorScreenState();
}

class _PlateCalculatorScreenState extends State<PlateCalculatorScreen> {
  late final _targetCtrl = TextEditingController(
      text: widget.initialTarget?.toStringAsFixed(1) ?? '');
  final _barCtrl = TextEditingController(text: '20');

  /// Common plate inventory in kg.
  final List<double> _allPlates = const [25, 20, 15, 10, 5, 2.5, 1.25];
  final Set<double> _enabled = {25, 20, 15, 10, 5, 2.5, 1.25};

  @override
  void dispose() {
    _targetCtrl.dispose();
    _barCtrl.dispose();
    super.dispose();
  }

  ({List<double> plates, double loaded, double leftover}) _compute() {
    final target = double.tryParse(_targetCtrl.text) ?? 0;
    final bar = double.tryParse(_barCtrl.text) ?? 20;
    if (target < bar) {
      return (plates: const [], loaded: bar, leftover: 0);
    }
    var remaining = (target - bar) / 2;
    final result = <double>[];
    final candidates = _enabled.toList()..sort((a, b) => b.compareTo(a));
    for (final p in candidates) {
      while (remaining >= p - 0.0001) {
        result.add(p);
        remaining -= p;
      }
    }
    final perSide = result.fold<double>(0, (a, b) => a + b);
    final loaded = bar + perSide * 2;
    return (
      plates: result,
      loaded: loaded,
      leftover: target - loaded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final out = _compute();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plate calculator'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _targetCtrl,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
            ],
            decoration: const InputDecoration(
              labelText: 'Target weight (kg)',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _barCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
            ],
            decoration: const InputDecoration(
              labelText: 'Bar weight (kg)',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          const Text('Available plates (kg)',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _allPlates
                .map((p) => FilterChip(
                      label: Text(fmtKg(p)),
                      selected: _enabled.contains(p),
                      selectedColor: Colors.red.shade100,
                      onSelected: (sel) => setState(() {
                        if (sel) {
                          _enabled.add(p);
                        } else {
                          _enabled.remove(p);
                        }
                      }),
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red, width: 1.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Per side',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  out.plates.isEmpty
                      ? 'just the bar'
                      : out.plates.map(fmtKg).join(' + '),
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(height: 12),
                Text('Total loaded: ${fmtKg(out.loaded)} kg'),
                if (out.leftover.abs() > 0.01)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      out.leftover > 0
                          ? '${fmtKg(out.leftover)} kg short — enable smaller plates'
                          : '${fmtKg(-out.leftover)} kg over',
                      style:
                          const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
