import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_state.dart';
import '../models/user_model.dart';
import '../models/attendance_model.dart';
import '../models/leave_request_model.dart';
import 'user_management_screen.dart';

/// Read-only directory of everyone in the org with today's attendance
/// status at a glance (Attendance / On leave / Absent) plus a quick-call
/// button — reached by tapping the "Members" pill on the dashboard.
class AllMembersScreen extends StatefulWidget {
  const AllMembersScreen({super.key});

  @override
  State<AllMembersScreen> createState() => _AllMembersScreenState();
}

enum _MemberStatus { attendance, onLeave, absent }

class _AllMembersScreenState extends State<AllMembersScreen> {
  bool _searching = false;
  String _query = '';

  _MemberStatus _statusFor(AppState state, AppUser user, DateTime today) {
    final hasAttendance = state.attendance.any((a) =>
        a.userId == user.id &&
        a.verification == VerificationResult.success &&
        a.timestamp.year == today.year &&
        a.timestamp.month == today.month &&
        a.timestamp.day == today.day);
    if (hasAttendance) return _MemberStatus.attendance;

    final onLeave = state.leaveRequests.any((r) =>
        r.userId == user.id &&
        r.status == LeaveStatus.approved &&
        r.date.year == today.year &&
        r.date.month == today.month &&
        r.date.day == today.day);
    if (onLeave) return _MemberStatus.onLeave;

    return _MemberStatus.absent;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final today = DateTime.now();

    List<AppUser> members = state.users;
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      members = members.where((u) => u.name.toLowerCase().contains(q) || u.identificationNumber.toLowerCase().contains(q)).toList();
    }

    final statuses = {for (final u in state.users) u.id: _statusFor(state, u, today)};
    final attendanceCount = statuses.values.where((s) => s == _MemberStatus.attendance).length;
    final onLeaveCount = statuses.values.where((s) => s == _MemberStatus.onLeave).length;
    final absentCount = statuses.values.where((s) => s == _MemberStatus.absent).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: _searching
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Search by name or ID', border: InputBorder.none),
                onChanged: (v) => setState(() => _query = v),
              )
            : const Text('All Members'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _query = '';
            }),
          ),
          if (state.isAdmin)
            IconButton(
              icon: const Icon(Icons.manage_accounts_outlined),
              tooltip: 'Manage & edit members',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UserManagementScreen())),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(DateFormat('d MMMM yyyy').format(today), style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  label: 'Members',
                  count: '${state.users.length}',
                  icon: Icons.groups_2_rounded,
                  bgColor: const Color(0xFFB9BEC9),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  label: 'Attendance',
                  count: '$attendanceCount',
                  icon: Icons.event_available,
                  bgColor: const Color(0xFF3B82F6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _miniStatCard(label: 'On leave', count: '$onLeaveCount')),
              const SizedBox(width: 12),
              Expanded(child: _miniStatCard(label: 'Absent', count: '$absentCount')),
            ],
          ),
          const SizedBox(height: 20),
          if (members.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(child: Text('No members found.', style: TextStyle(color: Colors.grey.shade500))),
            )
          else
            for (final u in members) _memberCard(u, statuses[u.id] ?? _MemberStatus.absent, state),
        ],
      ),
    );
  }

  Widget _statCard({required String label, required String count, required IconData icon, required Color bgColor}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
              Icon(icon, color: Colors.white, size: 22),
            ],
          ),
          const SizedBox(height: 14),
          Text(count, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _miniStatCard({required String label, required String count}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(count, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _memberCard(AppUser u, _MemberStatus status, AppState state) {
    final subtitleParts = [
      u.position ?? u.subject,
      u.department ?? u.className,
      if (u.room != null && u.room!.isNotEmpty) 'Room ${u.room}',
    ].where((v) => v != null && v.isNotEmpty).cast<String>().toList();

    late final String badgeLabel;
    late final Color badgeColor;
    switch (status) {
      case _MemberStatus.attendance:
        badgeLabel = 'Attendance';
        badgeColor = const Color(0xFF3B82F6);
        break;
      case _MemberStatus.onLeave:
        badgeLabel = 'On leave';
        badgeColor = const Color(0xFF6366F1);
        break;
      case _MemberStatus.absent:
        badgeLabel = 'Absent';
        badgeColor = const Color(0xFFEF4444);
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: u.role == UserRole.admin ? Colors.purple.withValues(alpha: 0.12) : Colors.blue.withValues(alpha: 0.12),
                child: Text(
                  u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: u.role == UserRole.admin ? Colors.purple : Colors.blue,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(12)),
                child: Text(badgeLabel, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (subtitleParts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitleParts.join(' • '), style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  ),
                if (u.phoneNumber != null && u.phoneNumber!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(u.phoneNumber!, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                  ),
              ],
            ),
          ),
          if (u.phoneNumber != null && u.phoneNumber!.isNotEmpty)
            Container(
              decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
              child: IconButton(
                icon: const Icon(Icons.call, color: Colors.white, size: 18),
                tooltip: 'Call ${u.phoneNumber}',
                onPressed: () => launchUrl(Uri(scheme: 'tel', path: u.phoneNumber)),
              ),
            ),
        ],
      ),
    );
  }
}
