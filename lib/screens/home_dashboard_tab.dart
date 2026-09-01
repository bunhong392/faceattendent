import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/attendance_model.dart';
import '../models/leave_request_model.dart';
import '../widgets/ms_school_emblem.dart';
import '../widgets/id_card_dialog.dart';
import 'attendance_history_screen.dart';
import 'leave_request_screen.dart';
import 'leave_requests_admin_screen.dart';
import 'check_in_out_screen.dart';
import 'all_members_screen.dart';
import 'my_calendar_screen.dart';
import 'branch_management_screen.dart';
import 'reports_screen.dart';
import 'activity_log_screen.dart';

class HomeDashboardTab extends StatefulWidget {
  const HomeDashboardTab({super.key});

  @override
  State<HomeDashboardTab> createState() => _HomeDashboardTabState();
}

class _HomeDashboardTabState extends State<HomeDashboardTab> {
  bool _showBirthdayNotice = true;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final summary = state.todaySummary();
    final user = state.currentUser;
    final totalMembers = state.users.isNotEmpty ? state.users.length : 98;
    final onLeaveCount = state.leaveRequests.where((r) => r.status == LeaveStatus.approved).length;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final pillBg = isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F8);
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;
    final textHeading = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Hi, ${user?.name.split(" ").first ?? "Member"} 👋',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: Icon(state.isDarkMode ? Icons.wb_sunny_rounded : Icons.nightlight_round),
            tooltip: state.isDarkMode ? 'Bright Mode' : 'Dark Mode',
            onPressed: () => state.toggleTheme(),
          ),
          if (state.isAdmin)
            IconButton(
              icon: const Icon(Icons.receipt_long_outlined),
              tooltip: 'Reports',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReportsScreen())),
            ),
          if (state.isAdmin)
            IconButton(
              icon: const Icon(Icons.store_mall_directory_outlined),
              tooltip: 'Branches',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BranchManagementScreen())),
            ),
          IconButton(
            icon: const Icon(Icons.fact_check_outlined),
            tooltip: 'Activity log',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ActivityLogScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => state.refresh(),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // 1. Birthday / Announcement Notification Banner
            if (_showBirthdayNotice) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Check your Birthday! 🎂',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Please confirm your birthday.',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                      onPressed: () => setState(() => _showBirthdayNotice = false),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 2. Hero School Emblem & "My Card" Card
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  const Center(
                    child: MsSchoolEmblem(size: 240),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF243044) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFD32F2F),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.school, size: 18, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'MS SCHOOL',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () {
                            if (user != null) {
                              IdCardDialog.show(context, user);
                            }
                          },
                          child: const Text(
                            'My Card',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 3. Action Menu List
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildMenuItem(
                        icon: Icons.calendar_month,
                        iconColor: Colors.white,
                        bgColor: const Color(0xFFF97316),
                        title: 'Attendance',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen()),
                        ),
                      ),
                      _divider(),
                      _buildMenuItem(
                        icon: Icons.chat_bubble_outline,
                        iconColor: Colors.white,
                        bgColor: const Color(0xFF3B82F6),
                        title: 'Leave',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => state.isAdmin
                                ? const LeaveRequestsAdminScreen()
                                : const LeaveRequestScreen(),
                          ),
                        ),
                      ),
                      _divider(),
                      _buildMenuItem(
                        icon: Icons.timer_outlined,
                        iconColor: Colors.white,
                        bgColor: const Color(0xFF22C55E),
                        title: 'Overtime',
                        onTap: () => _showOvertimeDialog(context, state),
                      ),
                      _divider(),
                      _buildMenuItem(
                        icon: user != null && state.getAutoAttendanceType(user.id) == AttendanceType.checkOut
                            ? Icons.logout_rounded
                            : Icons.login_rounded,
                        iconColor: Colors.white,
                        bgColor: user != null && state.getAutoAttendanceType(user.id) == AttendanceType.checkOut
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF059669),
                        title: user != null && state.getAutoAttendanceType(user.id) == AttendanceType.checkOut
                            ? 'Check Out'
                            : 'Check In',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const CheckInOutScreen()),
                        ),
                      ),
                      _divider(),
                      _buildMenuItem(
                        icon: Icons.calendar_today_outlined,
                        iconColor: Colors.white,
                        bgColor: const Color(0xFF6366F1),
                        title: 'My Calendar',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const MyCalendarScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
                // Floating Action Arrow Pill
                Positioned(
                  bottom: -16,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 24),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 36),

            // 4. Dashboard Title
            Text(
              'Dashboard',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textHeading),
            ),
            const SizedBox(height: 14),

            // 5. Dashboard Summary Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Members Row Pill
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AllMembersScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: pillBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.groups_2_rounded, color: Color(0xFF3B82F6), size: 32),
                          const SizedBox(width: 14),
                          Text(
                            '$totalMembers',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: textHeading,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Members',
                            style: TextStyle(fontSize: 16, color: textHeading, fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          const Icon(Icons.arrow_forward_ios, color: Color(0xFF3B82F6), size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 4 Stats Overview Grid
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn(
                        icon: Icons.event_available,
                        label: 'Attendance',
                        count: '${summary[AttendanceStatus.present]}',
                        color: const Color(0xFF22C55E),
                      ),
                      _buildStatColumn(
                        icon: Icons.event_busy,
                        label: 'Absent',
                        count: '${summary[AttendanceStatus.absent]}',
                        color: const Color(0xFFEF4444),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn(
                        icon: Icons.mark_chat_read_outlined,
                        label: 'On leave',
                        count: '$onLeaveCount',
                        color: const Color(0xFF3B82F6),
                      ),
                      _buildStatColumn(
                        icon: Icons.favorite_border,
                        label: 'Day off',
                        count: '${summary[AttendanceStatus.late]}',
                        color: const Color(0xFFF59E0B),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F8),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.arrow_forward_ios, size: 13, color: Color(0xFF3B82F6)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(height: 1, indent: 64, endIndent: 16, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9));
  }

  Widget _buildStatColumn({
    required IconData icon,
    required String label,
    required String count,
    required Color color,
  }) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Text(
                label,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showOvertimeDialog(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.timer_outlined, color: Color(0xFF22C55E)),
            SizedBox(width: 8),
            Text('Overtime Summary'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Active Work Schedules: ${state.schedules.length}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Overtime is tracked automatically when check-out occurs after the scheduled shift end time.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
