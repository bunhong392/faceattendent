import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/attendance_model.dart';
import '../models/user_model.dart';
import '../widgets/attendance_tile.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  AttendanceStatus? _statusFilter;
  String _query = '';
  String? _groupFilter; // class / department / group value
  DateTimeRange? _dateRange;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isAdmin = state.currentUser?.role == UserRole.admin;

    List<AttendanceRecord> records = isAdmin ? state.attendance : state.attendanceFor(state.currentUser!.id);

    // Distinct class/department/group labels among the users who have
    // records, so admins can filter attendance by them (per requirement:
    // "searched by date, user, class, group, department, or status").
    final usersById = {for (final u in state.users) u.id: u};
    final groups = <String>{
      for (final r in records)
        if (usersById[r.userId] != null) ...[
          if (usersById[r.userId]!.className != null && usersById[r.userId]!.className!.isNotEmpty) usersById[r.userId]!.className!,
          if (usersById[r.userId]!.department != null && usersById[r.userId]!.department!.isNotEmpty) usersById[r.userId]!.department!,
          if (usersById[r.userId]!.group != null && usersById[r.userId]!.group!.isNotEmpty) usersById[r.userId]!.group!,
        ],
    }.toList()
      ..sort();

    if (_statusFilter != null) {
      records = records.where((r) => r.status == _statusFilter).toList();
    }
    if (_query.isNotEmpty) {
      records = records.where((r) => r.userName.toLowerCase().contains(_query.toLowerCase())).toList();
    }
    if (_groupFilter != null) {
      records = records.where((r) {
        final u = usersById[r.userId];
        return u != null && (u.className == _groupFilter || u.department == _groupFilter || u.group == _groupFilter);
      }).toList();
    }
    if (_dateRange != null) {
      final start = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day);
      final end = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day, 23, 59, 59);
      records = records.where((r) => r.timestamp.isAfter(start) && r.timestamp.isBefore(end)).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
        actions: [
          IconButton(
            icon: Icon(state.isDarkMode ? Icons.wb_sunny_rounded : Icons.nightlight_round),
            tooltip: state.isDarkMode ? 'Bright Mode' : 'Dark Mode',
            onPressed: () => state.toggleTheme(),
          ),
          IconButton(
            icon: Icon(Icons.date_range, color: _dateRange != null ? Colors.blue : null),
            tooltip: 'Filter by date',
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(now.year - 2),
                lastDate: DateTime(now.year + 1),
                initialDateRange: _dateRange,
              );
              if (picked != null) setState(() => _dateRange = picked);
            },
          ),
          if (_dateRange != null)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear date filter',
              onPressed: () => setState(() => _dateRange = null),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              children: [
                if (isAdmin)
                  TextField(
                    decoration: const InputDecoration(hintText: 'Search by name', prefixIcon: Icon(Icons.search)),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                if (_dateRange != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${DateFormat.yMMMd().format(_dateRange!.start)} – ${DateFormat.yMMMd().format(_dateRange!.end)}',
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _filterChip('All', null),
                      _filterChip('Present', AttendanceStatus.present),
                      _filterChip('Late', AttendanceStatus.late),
                      _filterChip('Absent', AttendanceStatus.absent),
                      _filterChip('Leave', AttendanceStatus.leave),
                    ],
                  ),
                ),
                if (isAdmin && groups.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _groupChip('All classes/depts', null),
                        for (final g in groups) _groupChip(g, g),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: records.isEmpty
                ? Center(child: Text('No records found.', style: TextStyle(color: Colors.grey.shade500)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: records.length,
                    itemBuilder: (_, i) => AttendanceTile(
                      record: records[i],
                      onDelete: isAdmin ? () => _confirmDelete(context, records[i]) : null,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, AttendanceRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this record?'),
        content: Text(
          '${record.userName} • ${record.type == AttendanceType.checkIn ? "Check-in" : "Check-out"} • '
          '${DateFormat('MMM d, h:mm a').format(record.timestamp)}\n\n'
          'This frees up that schedule so they can check in/out again today. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final error = await context.read<AppState>().deleteAttendanceRecord(record.id);
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Widget _filterChip(String label, AttendanceStatus? status) {
    final selected = _statusFilter == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _statusFilter = status),
      ),
    );
  }

  Widget _groupChip(String label, String? value) {
    final selected = _groupFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _groupFilter = value),
      ),
    );
  }
}
