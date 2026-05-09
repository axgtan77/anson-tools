import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../utils/format.dart';
import 'workout_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<DailySummary> _summaries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await DatabaseHelper.instance.dailySummaries();
    if (!mounted) return;
    setState(() {
      _summaries = s;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _summaries.isEmpty
              ? const Center(
                  child: Text('No workouts logged yet.',
                      style: TextStyle(color: Colors.black54)),
                )
              : ListView.separated(
                  itemCount: _summaries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final s = _summaries[i];
                    final date = DateTime.tryParse(s.date);
                    final formatted = date != null
                        ? DateFormat('EEE, MMM d, y').format(date)
                        : s.date;
                    return ListTile(
                      title: Text(formatted,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${s.exerciseCount} exercise${s.exerciseCount == 1 ? '' : 's'} · '
                        '${s.setCount} set${s.setCount == 1 ? '' : 's'} · '
                        '${fmtKg(s.totalVolumeKg)} kg total',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WorkoutScreen(date: s.date),
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
