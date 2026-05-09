import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../models/exercise.dart';
import '../models/workout_set.dart';
import '../utils/format.dart';

class ExerciseDetailScreen extends StatefulWidget {
  final Exercise exercise;
  const ExerciseDetailScreen({super.key, required this.exercise});

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  List<WorkoutSet> _sets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sets = await DatabaseHelper.instance
        .setsForExercise(widget.exercise.id!);
    if (!mounted) return;
    setState(() {
      _sets = sets;
      _loading = false;
    });
  }

  /// Best estimated 1RM per date, oldest → newest.
  List<MapEntry<String, double>> _bestPerDate() {
    final byDate = <String, double>{};
    for (final s in _sets) {
      if (s.isBodyweight) continue;
      final cur = byDate[s.workoutDate] ?? 0;
      if (s.estimated1RM > cur) byDate[s.workoutDate] = s.estimated1RM;
    }
    final entries = byDate.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  Map<String, List<WorkoutSet>> _setsByDateDesc() {
    final m = <String, List<WorkoutSet>>{};
    for (final s in _sets) {
      m.putIfAbsent(s.workoutDate, () => []).add(s);
    }
    final keys = m.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final k in keys) k: m[k]!};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exercise.name),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sets.isEmpty
              ? const Center(
                  child: Text('No sets logged for this exercise yet.',
                      style: TextStyle(color: Colors.black54)),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    _ChartSection(points: _bestPerDate()),
                    const Divider(height: 1),
                    ..._setsByDateDesc().entries.map(
                          (e) => _DateBlock(date: e.key, sets: e.value),
                        ),
                  ],
                ),
    );
  }
}

class _ChartSection extends StatelessWidget {
  final List<MapEntry<String, double>> points;
  const _ChartSection({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          points.isEmpty
              ? 'Log a weighted set to start tracking your 1RM.'
              : 'Log another weighted set to draw a trend line.',
          style: const TextStyle(color: Colors.black54),
        ),
      );
    }

    final spots = [
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].value),
    ];
    final maxY = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final minY = points.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    final pad = ((maxY - minY) * 0.1).clamp(2.0, 20.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
      child: SizedBox(
        height: 220,
        child: LineChart(
          LineChartData(
            minY: (minY - pad).clamp(0, double.infinity),
            maxY: maxY + pad,
            minX: 0,
            maxX: (points.length - 1).toDouble(),
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
                      ((points.length - 1) / 4).clamp(1, 999).toDouble(),
                  getTitlesWidget: (v, _) {
                    final i = v.round();
                    if (i < 0 || i >= points.length) {
                      return const SizedBox.shrink();
                    }
                    final d = DateTime.tryParse(points[i].key);
                    final label = d == null
                        ? points[i].key
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

class _DateBlock extends StatelessWidget {
  final String date;
  final List<WorkoutSet> sets;
  const _DateBlock({required this.date, required this.sets});

  @override
  Widget build(BuildContext context) {
    final d = DateTime.tryParse(date);
    final label = d == null
        ? date
        : DateFormat('EEE, MMM d, y').format(d);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          ...List.generate(sets.length, (i) {
            final s = sets[i];
            final w = s.isBodyweight ? 'BW' : '${fmtKg(s.weight)}kg';
            final rm = s.isBodyweight
                ? ''
                : '  (1RM:${s.estimated1RM.toStringAsFixed(2)})';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Text(
                '${i + 1}.  $w × ${s.reps} reps$rm',
                style: const TextStyle(color: Colors.black87),
              ),
            );
          }),
        ],
      ),
    );
  }
}
