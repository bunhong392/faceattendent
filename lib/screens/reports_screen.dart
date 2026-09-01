import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/app_state.dart';
import '../models/attendance_model.dart';

enum ReportPeriod { daily, weekly, monthly, custom }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportPeriod _period = ReportPeriod.weekly;
  DateTimeRange? _customRange;

  DateTimeRange _rangeFor(ReportPeriod period) {
    final now = DateTime.now();
    switch (period) {
      case ReportPeriod.daily:
        return DateTimeRange(start: DateTime(now.year, now.month, now.day), end: now);
      case ReportPeriod.weekly:
        return DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
      case ReportPeriod.monthly:
        return DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now);
      case ReportPeriod.custom:
        return _customRange ?? DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final range = _rangeFor(_period);
    final records = state.attendance.where((r) => r.timestamp.isAfter(range.start) && r.timestamp.isBefore(range.end.add(const Duration(days: 1)))).toList();

    final byStatus = <AttendanceStatus, int>{for (final s in AttendanceStatus.values) s: 0};
    for (final r in records) {
      byStatus[r.status] = (byStatus[r.status] ?? 0) + 1;
    }

    final byUser = <String, List<AttendanceRecord>>{};
    for (final r in records) {
      byUser.putIfAbsent(r.userName, () => []).add(r);
    }
    final mostAbsent = byUser.entries.toList()
      ..sort((a, b) => b.value.where((r) => r.status == AttendanceStatus.absent).length
          .compareTo(a.value.where((r) => r.status == AttendanceStatus.absent).length));

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Reports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<ReportPeriod>(
            segments: const [
              ButtonSegment(value: ReportPeriod.daily, label: Text('Day')),
              ButtonSegment(value: ReportPeriod.weekly, label: Text('Week')),
              ButtonSegment(value: ReportPeriod.monthly, label: Text('Month')),
              ButtonSegment(value: ReportPeriod.custom, label: Text('Custom')),
            ],
            selected: {_period},
            onSelectionChanged: (s) async {
              if (s.first == ReportPeriod.custom) {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _customRange = picked);
              }
              setState(() => _period = s.first);
            },
          ),
          const SizedBox(height: 8),
          Text(
            '${DateFormat('MMM d').format(range.start)} – ${DateFormat('MMM d, yyyy').format(range.end)}',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Summary', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                for (final status in AttendanceStatus.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(status.name[0].toUpperCase() + status.name.substring(1)),
                        Text('${byStatus[status]}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total records'),
                    Text('${records.length}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Frequently Absent', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (mostAbsent.isEmpty || mostAbsent.first.value.where((r) => r.status == AttendanceStatus.absent).isEmpty)
            Text('No absences in this period.', style: TextStyle(color: Colors.grey.shade500))
          else
            ...mostAbsent.take(5).map((e) {
              final absentCount = e.value.where((r) => r.status == AttendanceStatus.absent).length;
              if (absentCount == 0) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key),
                    Text('$absentCount absence(s)', style: const TextStyle(color: Colors.red)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
