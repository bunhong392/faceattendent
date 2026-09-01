import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import 'face_registration_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.currentUser;
    if (user == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: Icon(state.isDarkMode ? Icons.wb_sunny_rounded : Icons.nightlight_round),
            tooltip: state.isDarkMode ? 'Bright Mode' : 'Dark Mode',
            onPressed: () => state.toggleTheme(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: Colors.blue.withValues(alpha: 0.12),
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(child: Text(user.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          Center(child: Text(user.role.name == 'admin' ? 'Administrator' : 'Member', style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600))),
          const SizedBox(height: 24),

          // Theme / Appearance Card
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      state.isDarkMode ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                      color: state.isDarkMode ? Colors.amber : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Appearance',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Spacer(),
                    Text(
                      state.isDarkMode ? 'Dark Mode' : 'Bright Mode',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: state.isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Bright Mode'),
                        icon: Icon(Icons.wb_sunny_outlined, size: 18),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dark Mode'),
                        icon: Icon(Icons.nightlight_round, size: 18),
                      ),
                    ],
                    selected: {state.themeMode},
                    onSelectionChanged: (set) => state.setThemeMode(set.first),
                  ),
                ),
              ],
            ),
          ),

          _infoTile(context, 'ID', user.identificationNumber),
          _infoTile(context, 'Email', user.email),
          if (user.className != null) _infoTile(context, 'Class', user.className!),
          if (user.group != null) _infoTile(context, 'Group', user.group!),
          if (user.room != null) _infoTile(context, 'Room', user.room!),
          if (user.subject != null) _infoTile(context, 'Subject', user.subject!),
          if (user.department != null) _infoTile(context, 'Department', user.department!),
          if (user.position != null) _infoTile(context, 'Position', user.position!),
          _infoTile(context, 'Face profile', user.hasFaceProfile ? 'Registered ✓' : 'Not registered'),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FaceRegistrationScreen())),
            icon: const Icon(Icons.face),
            label: Text(user.hasFaceProfile ? 'Manage Face Profile' : 'Register Face'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showChangeEmailDialog(context, user.email),
            icon: const Icon(Icons.alternate_email),
            label: const Text('Change Email'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showChangePasswordDialog(context),
            icon: const Icon(Icons.lock_outline),
            label: const Text('Change Password'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              await state.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  void _showChangeEmailDialog(BuildContext context, String currentEmail) {
    final newEmailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final appState = context.read<AppState>();
    bool submitting = false;
    String? error;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocalState) {
          return AlertDialog(
              title: const Text('Change Email'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Current: $currentEmail', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newEmailCtrl,
                    decoration: const InputDecoration(labelText: 'New email'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passwordCtrl,
                    decoration: const InputDecoration(labelText: 'Current password'),
                    obscureText: true,
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                FilledButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          if (newEmailCtrl.text.trim().isEmpty || passwordCtrl.text.isEmpty) return;
                          setLocalState(() => submitting = true);
                          final result = await appState.changeOwnEmail(
                            currentPassword: passwordCtrl.text,
                            newEmail: newEmailCtrl.text,
                          );
                          setLocalState(() => submitting = false);
                          if (result == null) {
                            if (dialogContext.mounted) Navigator.pop(dialogContext);
                          } else {
                            setLocalState(() => error = result);
                          }
                        },
                  child: submitting
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save'),
                ),
              ],
            );
        },
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    final appState = context.read<AppState>();
    bool submitting = false;
    String? error;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocalState) {
          return AlertDialog(
              title: const Text('Change Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentPasswordCtrl,
                    decoration: const InputDecoration(labelText: 'Current password'),
                    obscureText: true,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: newPasswordCtrl,
                    decoration: const InputDecoration(labelText: 'New password (min 6 characters)'),
                    obscureText: true,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmPasswordCtrl,
                    decoration: const InputDecoration(labelText: 'Confirm new password'),
                    obscureText: true,
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                FilledButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          if (currentPasswordCtrl.text.isEmpty || newPasswordCtrl.text.isEmpty) return;
                          if (newPasswordCtrl.text != confirmPasswordCtrl.text) {
                            setLocalState(() => error = 'New passwords do not match.');
                            return;
                          }
                          if (newPasswordCtrl.text.length < 6) {
                            setLocalState(() => error = 'Password must be at least 6 characters.');
                            return;
                          }
                          setLocalState(() => submitting = true);
                          final result = await appState.changeOwnPassword(
                            currentPassword: currentPasswordCtrl.text,
                            newPassword: newPasswordCtrl.text,
                          );
                          setLocalState(() => submitting = false);
                          if (result == null) {
                            if (dialogContext.mounted) Navigator.pop(dialogContext);
                          } else {
                            setLocalState(() => error = result);
                          }
                        },
                  child: submitting
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save'),
                ),
              ],
            );
        },
      ),
    );
  }

  Widget _infoTile(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
