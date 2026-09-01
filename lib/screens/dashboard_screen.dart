import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/user_model.dart';
import 'home_dashboard_tab.dart';
import 'attendance_history_screen.dart';
import 'check_in_out_screen.dart';
import 'user_management_screen.dart';
import 'leave_requests_admin_screen.dart';
import 'profile_screen.dart';

/// Root shell after login: bottom navigation between the main sections.
/// Tabs shown depend on whether the signed-in user is an admin or member.
/// Admins don't check in/out themselves, so their "Attend" tab is replaced
/// with "Leave Requests" (reviewing/replying to employee absences).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isAdmin = state.currentUser?.role == UserRole.admin;

    final tabs = <Widget>[
      const HomeDashboardTab(),
      if (isAdmin) const LeaveRequestsAdminScreen() else const CheckInOutScreen(),
      const AttendanceHistoryScreen(),
      if (isAdmin) const UserManagementScreen(),
      const ProfileScreen(),
    ];

    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
      if (isAdmin)
        const BottomNavigationBarItem(icon: Icon(Icons.mail_outline), activeIcon: Icon(Icons.mail), label: 'Leave')
      else
        const BottomNavigationBarItem(icon: Icon(Icons.face_outlined), activeIcon: Icon(Icons.face), label: 'Attend'),
      const BottomNavigationBarItem(icon: Icon(Icons.history_outlined), activeIcon: Icon(Icons.history), label: 'History'),
      if (isAdmin) const BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: 'Users'),
      const BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
    ];

    if (_index >= tabs.length) _index = 0;

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: items,
      ),
    );
  }
}
