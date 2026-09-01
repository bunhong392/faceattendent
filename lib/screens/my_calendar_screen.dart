import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/app_state.dart';
import '../models/schedule_model.dart';
import '../models/leave_request_model.dart';
import 'schedule_management_screen.dart';

/// A personal, read-only calendar for the signed-in user: a month grid
/// (weekends marked as the weekly holiday) plus three tabs — Workday (their
/// assigned schedule, broken down by weekday), Holiday (this month's
/// weekend dates), and Leave (their own leave requests).
class MyCalendarScreen extends StatefulWidget {
  const MyCalendarScreen({super.key});

  @override
  State<MyCalendarScreen> createState() => _MyCalendarScreenState();
}

enum _CalendarTab { workday, holiday, leave }

class _MyCalendarScreenState extends State<MyCalendarScreen> {
  late DateTime _displayedMonth;
  late DateTime _selectedDate;
  _CalendarTab _tab = _CalendarTab.workday;

  static const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayedMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  bool _isWeekend(DateTime d) => d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;

  List<ScheduleItem> _mySchedules(AppState state) {
    final user = state.currentUser;
    if (user == null) return [];
    var mine = state.schedules.where((s) => s.assignedUserIds.contains(user.id)).toList();
    if (mine.isEmpty) {
      mine = state.schedules.where((s) => s.className == user.className || s.department == user.department).toList();
    }
    return mine;
  }

  String _fmtTime(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final dt = DateTime(2000, 1, 1, h, m);
    return DateFormat('hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Calendar'),
        actions: [
          if (state.isAdmin)
            IconButton(
              icon: const Icon(Icons.edit_calendar_outlined),
              tooltip: 'Manage schedules',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScheduleManagementScreen())),
            ),
        ],
      ),
      body: ListView(
        children: [
          _monthHeader(),
          _calendarGrid(),
          const Divider(height: 1),
          _tabBar(),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _tabContent(state),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _monthHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.blue),
            onPressed: () => setState(() => _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1)),
          ),
          Text(
            DateFormat('MMMM yyyy').format(_displayedMonth),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.blue),
            onPressed: () => setState(() => _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1)),
          ),
        ],
      ),
    );
  }

  Widget _calendarGrid() {
    final firstOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    // Grid starts on the Monday on/before the 1st.
    final gridStart = firstOfMonth.subtract(Duration(days: firstOfMonth.weekday - 1));
    const totalCells = 42; // 6 full weeks, matches the reference design

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Row(
            children: [for (final l in _weekdayLabels) Expanded(child: Center(child: Text(l, style: TextStyle(color: Colors.grey.shade400, fontSize: 16))))],
          ),
          const SizedBox(height: 8),
          for (int week = 0; week < totalCells / 7; week++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  for (int day = 0; day < 7; day++) Expanded(child: _dayCell(gridStart.add(Duration(days: week * 7 + day)))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayCell(DateTime date) {
    final inMonth = date.month == _displayedMonth.month;
    final isSelected = date.year == _selectedDate.year && date.month == _selectedDate.month && date.day == _selectedDate.day;
    final isHoliday = inMonth && _isWeekend(date);

    Color? bg;
    Color textColor = inMonth ? Colors.black87 : Colors.grey.shade300;
    if (isHoliday) {
      bg = const Color(0xFFEF4444);
      textColor = Colors.white;
    }

    return GestureDetector(
      onTap: inMonth ? () => setState(() => _selectedDate = date) : null,
      child: Container(
        height: 52,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
        ),
        child: Text('${date.day}', style: TextStyle(fontSize: 20, color: textColor)),
      ),
    );
  }

  Widget _tabBar() {
    Widget tabButton(String label, _CalendarTab value) {
      final selected = _tab == value;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _tab = value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: selected ? Colors.blue : Colors.transparent, width: 3)),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.blue : Colors.black87,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tabButton('Workday', _CalendarTab.workday),
        tabButton('Holiday', _CalendarTab.holiday),
        tabButton('Leave', _CalendarTab.leave),
      ],
    );
  }

  Widget _tabContent(AppState state) {
    switch (_tab) {
      case _CalendarTab.workday:
        return _workdayList(state);
      case _CalendarTab.holiday:
        return _holidayList();
      case _CalendarTab.leave:
        return _leaveList(state);
    }
  }

  Widget _workdayList(AppState state) {
    final mySchedules = _mySchedules(state);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          for (int weekday = 1; weekday <= 7; weekday++) _workdayRow(weekday, mySchedules),
        ],
      ),
    );
  }

  Widget _workdayRow(int weekday, List<ScheduleItem> mySchedules) {
    final todays = mySchedules.where((s) => s.weekdays.contains(weekday)).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 90,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
              ),
              alignment: Alignment.center,
              child: Text(_weekdayLabels[weekday - 1], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    if (todays.isEmpty)
                      Text('No schedule', style: TextStyle(color: Colors.grey.shade400, fontSize: 14))
                    else
                      for (final s in todays)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 7, right: 8),
                                child: Icon(Icons.circle, size: 8, color: Colors.blue),
                              ),
                              Expanded(
                                child: Text(
                                  '${_fmtTime(s.startTime)} - ${_fmtTime(s.endTime)}',
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _holidayList() {
    final daysInMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    final holidays = [
      for (int d = 1; d <= daysInMonth; d++) DateTime(_displayedMonth.year, _displayedMonth.month, d),
    ].where(_isWeekend).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          if (holidays.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text('No holidays this month.', style: TextStyle(color: Colors.grey.shade500)),
            )
          else
            for (final h in holidays)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 12),
                    Text(DateFormat('EEEE, d MMMM yyyy').format(h), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _leaveList(AppState state) {
    final user = state.currentUser;
    final myLeaves = (user == null ? <LeaveRequest>[] : state.leaveRequests.where((r) => r.userId == user.id).toList())
      ..sort((a, b) => b.date.compareTo(a.date));
    final thisMonth = myLeaves.where((r) => r.date.year == _displayedMonth.year && r.date.month == _displayedMonth.month).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          if (thisMonth.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text('No leave requests this month.', style: TextStyle(color: Colors.grey.shade500)),
            )
          else
            for (final r in thisMonth)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('EEEE, d MMMM yyyy').format(r.date), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        _leaveStatusChip(r.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(r.reason, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _leaveStatusChip(LeaveStatus status) {
    late final Color color;
    late final String label;
    switch (status) {
      case LeaveStatus.approved:
        color = const Color(0xFF22C55E);
        label = 'Approved';
        break;
      case LeaveStatus.rejected:
        color = const Color(0xFFEF4444);
        label = 'Rejected';
        break;
      case LeaveStatus.pending:
        color = const Color(0xFFF59E0B);
        label = 'Pending';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
