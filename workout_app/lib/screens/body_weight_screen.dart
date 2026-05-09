import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../utils/format.dart';

class BodyWeightScreen extends StatefulWidget {
  const BodyWeightScreen({super.key});

  @override
  State<BodyWeightScreen> createState() => _BodyWeightScreenState();
}

class _BodyWeightScreenState extends State<BodyWeightScreen> {
  List<BodyWeightEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await DatabaseHelper.instance.listBodyWeights();
    if (!mounted) return;
    setState(() {
      _entries = list;
      _loading = false;
    });
  }

  Future<void> _addOrEdit({BodyWeightEntry? existing}) async {
    final result = await showModalBottomSheet<_BWInput>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BWSheet(initial: existing),
    );
    if (result == null) return;
    await DatabaseHelper.instance.upsertBodyWeight(BodyWeightEntry(
      date: result.date,
      weightKg: result.weightKg,
      notes: result.notes,
    ));
    await _load();
  }

  Future<void> _delete(BodyWeightEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: Text('${e.date} — ${fmtKg(e.weightKg)} kg'),
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
    await DatabaseHelper.instance.deleteBodyWeight(e.date);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final ascending = [..._entries.reversed];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Body weight'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        onPressed: () => _addOrEdit(),
        icon: const Icon(Icons.add),
        label: const Text('Log weight'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? const Center(
                  child: Text(
                    'No weigh-ins logged yet.',
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 96),
                  children: [
                    if (ascending.length >= 2)
                      _BodyWeightChart(entries: ascending),
                    const Divider(height: 1),
                    ..._entries.map(
                      (e) => Dismissible(
                        key: ValueKey('bw-${e.date}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          color: Colors.red,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          child: const Icon(Icons.delete,
                              color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          await _delete(e);
                          return false;
                        },
                        child: ListTile(
                          title: Text(_formatDate(e.date),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: e.notes == null || e.notes!.isEmpty
                              ? null
                              : Text(e.notes!),
                          trailing: Text(
                            '${fmtKg(e.weightKg)} kg',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                          onTap: () => _addOrEdit(existing: e),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  String _formatDate(String d) {
    final dt = DateTime.tryParse(d);
    return dt == null ? d : DateFormat('EEE, MMM d, y').format(dt);
  }
}

class _BodyWeightChart extends StatelessWidget {
  final List<BodyWeightEntry> entries; // ascending date order
  const _BodyWeightChart({required this.entries});

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < entries.length; i++)
        FlSpot(i.toDouble(), entries[i].weightKg),
    ];
    final ys = entries.map((e) => e.weightKg);
    final maxY = ys.reduce((a, b) => a > b ? a : b);
    final minY = ys.reduce((a, b) => a < b ? a : b);
    final pad = ((maxY - minY) * 0.1).clamp(0.5, 5.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
      child: SizedBox(
        height: 220,
        child: LineChart(
          LineChartData(
            minY: minY - pad,
            maxY: maxY + pad,
            minX: 0,
            maxX: (entries.length - 1).toDouble(),
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            borderData: FlBorderData(
              show: true,
              border: const Border(
                left: BorderSide(color: Colors.black26),
                bottom: BorderSide(color: Colors.black26),
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (v, _) => Text(
                    v.toStringAsFixed(0),
                    style: const TextStyle(
                        color: Colors.black54, fontSize: 11),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval:
                      ((entries.length - 1) / 4).clamp(1, 999).toDouble(),
                  getTitlesWidget: (v, _) {
                    final i = v.round();
                    if (i < 0 || i >= entries.length) {
                      return const SizedBox.shrink();
                    }
                    final d = DateTime.tryParse(entries[i].date);
                    final label = d == null
                        ? entries[i].date
                        : DateFormat('M/d').format(d);
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(label,
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 11)),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: false,
                color: Colors.red,
                barWidth: 2.5,
                dotData: const FlDotData(show: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BWInput {
  final String date;
  final double weightKg;
  final String? notes;
  _BWInput(
      {required this.date, required this.weightKg, required this.notes});
}

class _BWSheet extends StatefulWidget {
  final BodyWeightEntry? initial;
  const _BWSheet({this.initial});

  @override
  State<_BWSheet> createState() => _BWSheetState();
}

class _BWSheetState extends State<_BWSheet> {
  late DateTime _date = widget.initial == null
      ? DateTime.now()
      : DateTime.parse(widget.initial!.date);
  late final _weight = TextEditingController(
      text: widget.initial?.weightKg.toStringAsFixed(1) ?? '');
  late final _notes =
      TextEditingController(text: widget.initial?.notes ?? '');

  @override
  void dispose() {
    _weight.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    final w = double.tryParse(_weight.text);
    if (w == null || w <= 0) return;
    Navigator.pop(
      context,
      _BWInput(
        date: DateFormat('yyyy-MM-dd').format(_date),
        weightKg: w,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
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
            widget.initial == null ? 'Log body weight' : 'Edit weigh-in',
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title: Text(DateFormat('EEE, MMM d, y').format(_date)),
            onTap: _pickDate,
          ),
          TextField(
            controller: _weight,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
            ],
            decoration: const InputDecoration(labelText: 'Weight (kg)'),
          ),
          TextField(
            controller: _notes,
            decoration:
                const InputDecoration(labelText: 'Notes (optional)'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
