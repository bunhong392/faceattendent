import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../models/face_profile_model.dart';
import '../models/attendance_model.dart';
import '../models/schedule_model.dart';
import '../models/activity_log_model.dart';
import 'realtime_db_service.dart';
import 'face_matcher.dart';
import 'device_service.dart';
import 'employee_provisioning_service.dart';
import '../models/branch_model.dart';
import '../models/leave_request_model.dart';
import '../utils/status_utils.dart';

/// Central app state: authentication (Firebase Auth) and cached data
/// (Firebase Realtime Database + Storage via [RealtimeDbService]). Exposed
/// through Provider to all screens. Data is fetched into local lists on
/// init/refresh so the UI can read synchronously; every mutation writes to
/// the database first, then updates the cache and calls notifyListeners().
class AppState extends ChangeNotifier {
  final _uuid = const Uuid();
  final _fs = RealtimeDbService.instance;
  final _auth = fb_auth.FirebaseAuth.instance;
  final _matcher = FaceMatcher();

  List<AppUser> users = [];
  List<FaceProfile> faceProfiles = [];
  List<AttendanceRecord> attendance = [];
  List<ScheduleItem> schedules = [];
  List<ActivityLog> logs = [];
  List<Branch> branches = [];
  List<LeaveRequest> leaveRequests = [];

  AppUser? currentUser;
  bool isLoading = true;

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  ScheduleItem? scheduleById(String id) {
    return schedules.where((s) => s.id == id).cast<ScheduleItem?>().firstOrNull;
  }

  bool get isAdmin => currentUser?.role == UserRole.admin;

  Future<void> init() async {
    try {
      final fbUser = _auth.currentUser;
      if (fbUser != null) {
        currentUser = await _fs.getUser(fbUser.uid);
        if (currentUser != null) {
          await _refreshAll();
        }
      }
    } catch (e) {
      debugPrint('Error during AppState init: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _refreshAll() async {
    if (currentUser == null) return;
    try {
      users = await _fs.getAllUsers();
      if (users.isEmpty && currentUser != null) {
        users = [currentUser!];
      }
    } catch (e) {
      debugPrint('Error getting users: $e');
      if (currentUser != null && !users.any((u) => u.id == currentUser!.id)) {
        users = [currentUser!];
      }
    }

    try {
      faceProfiles = await _fs.getAllFaceProfiles();
    } catch (e) {
      debugPrint('Error getting faceProfiles: $e');
    }

    try {
      attendance = await _fs.getAttendance(limit: 500);
    } catch (e) {
      debugPrint('Error getting attendance: $e');
    }

    try {
      schedules = await _fs.getSchedules();
    } catch (e) {
      debugPrint('Error getting schedules: $e');
    }

    try {
      logs = await _fs.getLogs();
    } catch (e) {
      debugPrint('Error getting logs: $e');
    }

    try {
      branches = await _fs.getBranches();
    } catch (e) {
      debugPrint('Error getting branches: $e');
    }

    try {
      leaveRequests = await _fs.getLeaveRequests();
    } catch (e) {
      debugPrint('Error getting leaveRequests: $e');
    }
  }

  Future<void> refresh() async {
    await _refreshAll();
    notifyListeners();
  }

  // ---------------- Authentication ----------------
  Future<String?> login(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      fb_auth.UserCredential cred;
      try {
        cred = await _auth.signInWithEmailAndPassword(email: cleanEmail, password: password);
      } on fb_auth.FirebaseAuthException catch (e) {
        // Auto-provision demo account if it doesn't exist in Firebase Auth yet
        if ((e.code == 'user-not-found' || e.code == 'invalid-credential') &&
            (cleanEmail == 'admin@demo.com' || cleanEmail == 'jamie@demo.com')) {
          cred = await _auth.createUserWithEmailAndPassword(email: cleanEmail, password: password);
          final isDemoAdmin = cleanEmail == 'admin@demo.com';
          final newDemoUser = AppUser(
            id: cred.user!.uid,
            identificationNumber: isDemoAdmin ? 'ADM-001' : 'STU-1001',
            name: isDemoAdmin ? 'Alex Admin' : 'Jamie Student',
            gender: isDemoAdmin ? 'Other' : 'Female',
            role: isDemoAdmin ? UserRole.admin : UserRole.member,
            department: isDemoAdmin ? 'Administration' : null,
            position: isDemoAdmin ? 'System Administrator' : null,
            className: isDemoAdmin ? null : 'Grade 10-A',
            subject: isDemoAdmin ? null : 'Homeroom',
            email: cleanEmail,
            createdAt: DateTime.now(),
          );
          await _fs.upsertUser(newDemoUser);
        } else {
          rethrow;
        }
      }

      var user = await _fs.getUser(cred.user!.uid);
      if (user == null) {
        final isDemoAdmin = cleanEmail == 'admin@demo.com';
        user = AppUser(
          id: cred.user!.uid,
          identificationNumber: isDemoAdmin ? 'ADM-001' : 'USR-${cred.user!.uid.substring(0, 4).toUpperCase()}',
          name: isDemoAdmin ? 'Alex Admin' : 'User',
          gender: 'Other',
          role: isDemoAdmin ? UserRole.admin : UserRole.member,
          email: cleanEmail,
          createdAt: DateTime.now(),
        );
        await _fs.upsertUser(user);
      }

      currentUser = user;
      await _refreshAll();
      await _addLog(ActivityAction.login, '${user.name} logged in.');
      notifyListeners();
      return null;
    } on fb_auth.FirebaseAuthException catch (e) {
      return _friendlyAuthError(e);
    } catch (e) {
      return 'Login failed: $e';
    }
  }

  Future<void> logout() async {
    if (currentUser != null) {
      await _addLog(ActivityAction.logout, '${currentUser!.name} logged out.');
    }
    await _auth.signOut();
    currentUser = null;
    notifyListeners();
  }

  Future<String?> registerUser({
    required String identificationNumber,
    required String name,
    required String gender,
    required UserRole role,
    String? className,
    String? group,
    String? subject,
    String? room,
    String? department,
    String? position,
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      final user = AppUser(
        id: cred.user!.uid,
        identificationNumber: identificationNumber,
        name: name,
        gender: gender,
        role: role,
        className: className,
        group: group,
        subject: subject,
        room: room,
        department: department,
        position: position,
        email: email.trim(),
        createdAt: DateTime.now(),
      );
      await _fs.upsertUser(user);
      users = await _fs.getAllUsers();
      await _addLog(ActivityAction.userCreated, 'Created user ${user.name} ($identificationNumber).');
      notifyListeners();
      return null;
    } on fb_auth.FirebaseAuthException catch (e) {
      return _friendlyAuthError(e);
    }
  }

  /// Admin-only: creates a full employee/member account without the person
  /// signing themselves up. Generates a login email + temporary password
  /// (see [EmployeeProvisioningService] for why a *real* email can't be
  /// created here), provisions the Firebase Auth account on a throwaway
  /// secondary app instance (so the admin's own session stays signed in),
  /// then writes the profile. Returns the generated login so the calling
  /// screen can show it to the admin once — it is never shown again.
  Future<ProvisionedLogin?> createEmployeeByAdmin({
    required String identificationNumber,
    required String name,
    required String gender,
    String? phoneNumber,
    String? className,
    String? group,
    String? subject,
    String? room,
    String? department,
    String? position,
    String? branchId,
    List<String> assignedScheduleIds = const [],
  }) async {
    final loginEmail = EmployeeProvisioningService.generateLoginEmail(name);
    final password = EmployeeProvisioningService.generateTemporaryPassword();
    try {
      final uid = await EmployeeProvisioningService.createAuthAccount(loginEmail: loginEmail, password: password);
      final user = AppUser(
        id: uid,
        identificationNumber: identificationNumber,
        name: name,
        gender: gender,
        role: UserRole.member,
        phoneNumber: phoneNumber,
        className: className,
        group: group,
        subject: subject,
        room: room,
        department: department,
        position: position,
        branchId: branchId,
        email: loginEmail,
        createdAt: DateTime.now(),
        createdByAdmin: true,
      );
      await _fs.upsertUser(user);
      users = await _fs.getAllUsers();

      // Assign user to chosen schedules
      if (assignedScheduleIds.isNotEmpty) {
        await updateScheduleAssignments(uid, assignedScheduleIds);
      }

      await _addLog(ActivityAction.userCreated, 'Admin created employee ${user.name} ($identificationNumber).');
      notifyListeners();
      return ProvisionedLogin(uid: uid, loginEmail: loginEmail, temporaryPassword: password);
    } catch (_) {
      return null;
    }
  }

  Future<void> updateScheduleAssignments(String userId, List<String> selectedScheduleIds) async {
    for (var i = 0; i < schedules.length; i++) {
      final s = schedules[i];
      final isSelected = selectedScheduleIds.contains(s.id);
      final currentlyAssigned = s.assignedUserIds.contains(userId);

      if (isSelected && !currentlyAssigned) {
        final updated = ScheduleItem(
          id: s.id,
          title: s.title,
          className: s.className,
          subject: s.subject,
          department: s.department,
          room: s.room,
          weekdays: s.weekdays,
          startTime: s.startTime,
          endTime: s.endTime,
          location: s.location,
          latitude: s.latitude,
          longitude: s.longitude,
          radiusMeters: s.radiusMeters,
          lateThresholdMinutes: s.lateThresholdMinutes,
          assignedUserIds: [...s.assignedUserIds, userId],
        );
        await _fs.addSchedule(updated);
        schedules[i] = updated;
      } else if (!isSelected && currentlyAssigned) {
        final updated = ScheduleItem(
          id: s.id,
          title: s.title,
          className: s.className,
          subject: s.subject,
          department: s.department,
          room: s.room,
          weekdays: s.weekdays,
          startTime: s.startTime,
          endTime: s.endTime,
          location: s.location,
          latitude: s.latitude,
          longitude: s.longitude,
          radiusMeters: s.radiusMeters,
          lateThresholdMinutes: s.lateThresholdMinutes,
          assignedUserIds: s.assignedUserIds.where((id) => id != userId).toList(),
        );
        await _fs.addSchedule(updated);
        schedules[i] = updated;
      }
    }
    notifyListeners();
  }

  // ---------------- Self-service credential changes ----------------
  // Employees/students who were given a random login by an admin (or who
  // registered themselves) can change their own email and/or password from
  // their Profile screen. Both require re-entering the current password
  // (Firebase requires a "recent login" before letting you change security-
  // sensitive fields like these).

  /// Re-authenticates the signed-in user with their current password.
  /// Returns null on success, or a friendly error message on failure.
  Future<String?> _reauthenticate(String currentPassword) async {
    final fbUser = _auth.currentUser;
    if (fbUser == null || fbUser.email == null) return 'You are not signed in.';
    try {
      final cred = fb_auth.EmailAuthProvider.credential(email: fbUser.email!, password: currentPassword);
      await fbUser.reauthenticateWithCredential(cred);
      return null;
    } on fb_auth.FirebaseAuthException catch (e) {
      return _friendlyAuthError(e);
    }
  }

  /// Changes the signed-in user's own password. Requires their current
  /// password to confirm it's really them.
  Future<String?> changeOwnPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final reauthError = await _reauthenticate(currentPassword);
    if (reauthError != null) return reauthError;
    try {
      await _auth.currentUser!.updatePassword(newPassword);
      await _addLog(ActivityAction.userUpdated, '${currentUser?.name ?? "A user"} changed their own password.');
      return null;
    } on fb_auth.FirebaseAuthException catch (e) {
      return _friendlyAuthError(e);
    }
  }

  /// Changes the signed-in user's own login email. Requires their current
  /// password to confirm it's really them. Also updates the email stored on
  /// their profile record so it stays in sync everywhere it's displayed.
  Future<String?> changeOwnEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    final cleanEmail = newEmail.trim().toLowerCase();
    final reauthError = await _reauthenticate(currentPassword);
    if (reauthError != null) return reauthError;
    try {
      final fbUser = _auth.currentUser!;
      await fbUser.verifyBeforeUpdateEmail(cleanEmail);

      if (currentUser != null) {
        final updated = AppUser(
          id: currentUser!.id,
          identificationNumber: currentUser!.identificationNumber,
          name: currentUser!.name,
          gender: currentUser!.gender,
          role: currentUser!.role,
          phoneNumber: currentUser!.phoneNumber,
          className: currentUser!.className,
          group: currentUser!.group,
          subject: currentUser!.subject,
          room: currentUser!.room,
          department: currentUser!.department,
          position: currentUser!.position,
          branchId: currentUser!.branchId,
          faceProfileId: currentUser!.faceProfileId,
          boundDeviceId: currentUser!.boundDeviceId,
          photoUrl: currentUser!.photoUrl,
          email: cleanEmail,
          createdAt: currentUser!.createdAt,
          createdByAdmin: currentUser!.createdByAdmin,
        );
        await _fs.upsertUser(updated);
        currentUser = updated;
        final idx = users.indexWhere((u) => u.id == updated.id);
        if (idx != -1) users[idx] = updated;
      }
      await _addLog(ActivityAction.userUpdated, '${currentUser?.name ?? "A user"} changed their own login email.');
      notifyListeners();
      return null;
    } on fb_auth.FirebaseAuthException catch (e) {
      return _friendlyAuthError(e);
    }
  }

  String _friendlyAuthError(fb_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'That email is already registered.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'weak-password':
        return 'Password is too weak (minimum 6 characters).';
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      default:
        return e.message ?? 'Authentication failed (${e.code}).';
    }
  }

  /// Admin-only: edits an existing user's profile fields (identity fields
  /// like id/email/role are immutable here — use dedicated flows for those).
  Future<void> updateUser(AppUser updated) async {
    await _fs.upsertUser(updated);
    final idx = users.indexWhere((u) => u.id == updated.id);
    if (idx != -1) {
      users[idx] = updated;
    } else {
      users.add(updated);
    }
    if (currentUser?.id == updated.id) currentUser = updated;
    await _addLog(ActivityAction.userUpdated, 'Updated profile for ${updated.name}.');
    notifyListeners();
  }

  /// Admin-only: removes a user's profile, face enrollment, and attendance
  /// visibility. Does not delete the underlying Firebase Auth account (that
  /// requires the Admin SDK / a Cloud Function, which is out of scope for a
  /// pure client app) — an admin should also disable the Auth account from
  /// the Firebase console if the person should lose login access entirely.
  Future<void> deleteUser(String userId) async {
    final user = users.where((u) => u.id == userId).cast<AppUser?>().firstOrNull;
    await _fs.deleteUser(userId);
    users.removeWhere((u) => u.id == userId);
    faceProfiles.removeWhere((p) => p.userId == userId);
    await _addLog(ActivityAction.userDeleted, 'Deleted user ${user?.name ?? userId}.');
    notifyListeners();
  }

  // ---------------- Face profiles ----------------
  Future<void> saveFaceProfile(String userId, List<double> descriptor, String imagePath, int sampleCount) async {
    final profile = await _fs.saveFaceProfile(
      userId: userId,
      descriptor: descriptor,
      thumbnailFile: File(imagePath),
      sampleCount: sampleCount,
    );
    faceProfiles.removeWhere((p) => p.userId == userId);
    faceProfiles.add(profile);

    // Bind this enrollment to the device it was captured on (device
    // validation). If DeviceService can't determine an id (e.g. web/desktop
    // during development), skip binding rather than lock the user out.
    final deviceId = await DeviceService.getDeviceId();

    final idx = users.indexWhere((u) => u.id == userId);
    if (idx != -1) {
      users[idx] = users[idx].copyWith(faceProfileId: userId, boundDeviceId: deviceId ?? users[idx].boundDeviceId);
      if (currentUser?.id == userId) currentUser = users[idx];
      if (deviceId != null) await _fs.upsertUser(users[idx]);
    }
    await _addLog(ActivityAction.faceRegistered, 'Face profile registered for user $userId.');
    notifyListeners();
  }

  /// Admin-only: clears a user's device binding (e.g. after they lose or
  /// replace their phone) so their next successful check-in re-binds to
  /// whatever device they're using.
  Future<void> resetBoundDevice(String userId) async {
    final idx = users.indexWhere((u) => u.id == userId);
    if (idx == -1) return;
    final updated = AppUser(
      id: users[idx].id,
      identificationNumber: users[idx].identificationNumber,
      name: users[idx].name,
      gender: users[idx].gender,
      role: users[idx].role,
      className: users[idx].className,
      group: users[idx].group,
      subject: users[idx].subject,
      room: users[idx].room,
      department: users[idx].department,
      position: users[idx].position,
      faceProfileId: users[idx].faceProfileId,
      boundDeviceId: null,
      photoUrl: users[idx].photoUrl,
      email: users[idx].email,
      createdAt: users[idx].createdAt,
    );
    await _fs.upsertUser(updated);
    users[idx] = updated;
    if (currentUser?.id == userId) currentUser = updated;
    await _addLog(ActivityAction.userUpdated, 'Reset device binding for ${updated.name}.');
    notifyListeners();
  }

  /// Silently binds a user's face check-in to [deviceId] the first time
  /// they successfully verify, if they aren't bound to a device yet.
  Future<void> bindDeviceIfUnset(String userId, String deviceId) async {
    final idx = users.indexWhere((u) => u.id == userId);
    if (idx == -1 || users[idx].boundDeviceId != null) return;
    final updated = users[idx].copyWith(boundDeviceId: deviceId);
    await _fs.upsertUser(updated);
    users[idx] = updated;
    if (currentUser?.id == userId) currentUser = updated;
    notifyListeners();
  }

  /// Attempts to match a freshly captured descriptor against all enrolled
  /// face profiles cached locally (refreshed on init/after writes).
  MapEntry<AppUser, double>? identify(List<double> probeDescriptor) {
    final candidates = {for (final p in faceProfiles) p.userId: p.descriptor};
    final result = FaceMatcher.bestMatch(probeDescriptor, candidates);
    if (result == null) return null;
    final user = users.where((u) => u.id == result.key).cast<AppUser?>().firstOrNull;
    if (user == null) return null;
    return MapEntry(user, result.value);
  }

  // ---------------- Attendance ----------------
  Future<AttendanceRecord> recordAttendance({
    required AppUser user,
    required AttendanceType type,
    required VerificationResult verification,
    double? matchConfidence,
    String? scheduleId,
    double? latitude,
    double? longitude,
    String? deviceId,
  }) async {
    final status = _computeStatus(type, verification, scheduleId);
    final draft = AttendanceRecord(
      id: '',
      userId: user.id,
      userName: user.name,
      scheduleId: scheduleId,
      timestamp: DateTime.now(),
      type: type,
      status: status,
      verification: verification,
      matchConfidence: matchConfidence,
      latitude: latitude,
      longitude: longitude,
      deviceId: deviceId,
    );
    final saved = await _fs.addAttendance(draft);
    attendance.insert(0, saved);
    if (verification == VerificationResult.success) {
      await _addLog(ActivityAction.attendanceRecorded,
          '${user.name} ${type == AttendanceType.checkIn ? "checked in" : "checked out"} (${status.name}).');
    }
    notifyListeners();
    return saved;
  }

  /// Returns whether the next action for [userId] today should be CheckIn or CheckOut.
  /// If the user hasn't checked in yet today (or their last action was CheckOut), returns CheckIn.
  /// If their last action was CheckIn, returns CheckOut.
  AttendanceType getAutoAttendanceType(String userId, {DateTime? date}) {
    final targetDate = date ?? DateTime.now();
    final todays = attendance
        .where((a) =>
            a.userId == userId &&
            a.verification == VerificationResult.success &&
            a.timestamp.year == targetDate.year &&
            a.timestamp.month == targetDate.month &&
            a.timestamp.day == targetDate.day)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (todays.isEmpty) return AttendanceType.checkIn;
    final last = todays.last;
    if (last.type == AttendanceType.checkIn) {
      return AttendanceType.checkOut;
    } else {
      return AttendanceType.checkIn;
    }
  }

  /// Intelligently matches the best schedule for [user] at the given [time] and [type].
  /// Matches directly assigned schedules, class/department/group schedules, and global schedules,
  /// filtering by weekday and selecting the closest slot to the current time.
  ScheduleItem? findScheduleForUser(AppUser user, {DateTime? time, AttendanceType? type}) {
    final now = time ?? DateTime.now();
    final todayWeekday = now.weekday; // 1 = Mon ... 7 = Sun

    // 1. Direct assignments
    var candidates = schedules.where((s) => s.assignedUserIds.contains(user.id)).toList();

    // 2. Match by class / department / group
    if (candidates.isEmpty) {
      candidates = schedules.where((s) {
        final matchesClass = user.className != null &&
            user.className!.trim().isNotEmpty &&
            s.className != null &&
            s.className!.trim().toLowerCase() == user.className!.trim().toLowerCase();
        final matchesDept = user.department != null &&
            user.department!.trim().isNotEmpty &&
            s.department != null &&
            s.department!.trim().toLowerCase() == user.department!.trim().toLowerCase();
        final matchesGroup = user.group != null &&
            user.group!.trim().isNotEmpty &&
            s.className != null &&
            s.className!.trim().toLowerCase() == user.group!.trim().toLowerCase();
        return matchesClass || matchesDept || matchesGroup;
      }).toList();
    }

    // 3. Match general/open schedules (no assigned users and no class/department restriction)
    if (candidates.isEmpty) {
      candidates = schedules
          .where((s) =>
              s.assignedUserIds.isEmpty &&
              (s.className == null || s.className!.trim().isEmpty) &&
              (s.department == null || s.department!.trim().isEmpty))
          .toList();
    }

    // 4. Fallback to all schedules
    if (candidates.isEmpty) {
      candidates = List.from(schedules);
    }

    if (candidates.isEmpty) return null;

    // Filter by weekday
    final todayCandidates = candidates.where((s) => s.weekdays.contains(todayWeekday)).toList();
    final pool = todayCandidates.isNotEmpty ? todayCandidates : candidates;

    if (pool.length == 1) return pool.first;

    // Filter/prioritize based on attendance status today
    List<ScheduleItem> prioritized = pool;
    if (type == AttendanceType.checkIn) {
      final unrecorded = pool
          .where((s) => !hasAlreadyRecordedToday(userId: user.id, type: AttendanceType.checkIn, scheduleId: s.id))
          .toList();
      if (unrecorded.isNotEmpty) prioritized = unrecorded;
    } else if (type == AttendanceType.checkOut) {
      final checkedInNotOut = pool
          .where((s) =>
              hasAlreadyRecordedToday(userId: user.id, type: AttendanceType.checkIn, scheduleId: s.id) &&
              !hasAlreadyRecordedToday(userId: user.id, type: AttendanceType.checkOut, scheduleId: s.id))
          .toList();
      if (checkedInNotOut.isNotEmpty) prioritized = checkedInNotOut;
    }

    // Find the schedule whose time is closest to current time
    final nowMinutes = now.hour * 60 + now.minute;
    ScheduleItem? bestSchedule;
    int minDiff = 999999;

    for (final s in prioritized) {
      final timeStr = type == AttendanceType.checkOut ? s.endTime : s.startTime;
      final tod = StatusUtils.parseTimeString(timeStr);
      if (tod == null) continue;
      final schedMinutes = tod.hour * 60 + tod.minute;
      final diff = (nowMinutes - schedMinutes).abs();
      if (diff < minDiff) {
        minDiff = diff;
        bestSchedule = s;
      }
    }

    return bestSchedule ?? prioritized.first;
  }

  AttendanceStatus _computeStatus(AttendanceType type, VerificationResult verification, String? scheduleId) {
    if (verification != VerificationResult.success) return AttendanceStatus.absent;
    if (type == AttendanceType.checkOut) return AttendanceStatus.present;
    if (scheduleId == null) return AttendanceStatus.present;
    final schedule = schedules.where((s) => s.id == scheduleId).cast<ScheduleItem?>().firstOrNull;
    if (schedule == null) return AttendanceStatus.present;

    final now = DateTime.now();
    final startTod = StatusUtils.parseTimeString(schedule.startTime);
    final endTod = StatusUtils.parseTimeString(schedule.endTime);
    if (startTod == null) return AttendanceStatus.present;

    var scheduledStart = DateTime(now.year, now.month, now.day, startTod.hour, startTod.minute);

    // Overnight shift (e.g. 23:30 -> 00:35): if the end time is earlier in
    // the day than the start time, the shift actually began "yesterday"
    // whenever the current wall-clock time is still before the start hour
    // (i.e. we're in the early-morning tail of that shift). Without this,
    // a check-in right after midnight would be compared against a
    // scheduledStart that's hours in the *future*, producing a large
    // negative "lateBy" and never showing as late.
    if (endTod != null) {
      final crossesMidnight = (endTod.hour * 60 + endTod.minute) <= (startTod.hour * 60 + startTod.minute);
      if (crossesMidnight && (now.hour * 60 + now.minute) < (startTod.hour * 60 + startTod.minute)) {
        scheduledStart = scheduledStart.subtract(const Duration(days: 1));
      }
    }

    final lateBy = now.difference(scheduledStart).inMinutes;
    return lateBy > schedule.lateThresholdMinutes ? AttendanceStatus.late : AttendanceStatus.present;
  }

  List<AttendanceRecord> attendanceFor(String userId) => attendance.where((a) => a.userId == userId).toList();

  /// Admin-only correction tool: permanently deletes an attendance record
  /// (e.g. a mistaken test check-in), freeing up that schedule/day so the
  /// person can check in again. Non-admin calls are also rejected by the
  /// database rules, but we check locally too so the UI can't even try.
  Future<String?> deleteAttendanceRecord(String recordId) async {
    if (!isAdmin) return 'Only an admin can delete attendance records.';
    try {
      await _fs.deleteAttendance(recordId);
      attendance.removeWhere((a) => a.id == recordId);
      await _addLog(ActivityAction.attendanceDeleted, '${currentUser?.name ?? "An admin"} deleted an attendance record.');
      notifyListeners();
      return null;
    } catch (e) {
      return 'Could not delete that record: $e';
    }
  }

  List<AttendanceRecord> attendanceOn(DateTime day) => attendance.where((a) =>
      a.timestamp.year == day.year && a.timestamp.month == day.month && a.timestamp.day == day.day).toList();

  /// True if [userId] already has a *successful* [type] (check-in or
  /// check-out) recorded today for [scheduleId] (or, if there's no
  /// schedule, for the day in general). Used to enforce "one check-in and
  /// one check-out per schedule per day".
  bool hasAlreadyRecordedToday({
    required String userId,
    required AttendanceType type,
    required String? scheduleId,
  }) {
    final now = DateTime.now();
    return attendance.any((a) =>
        a.userId == userId &&
        a.type == type &&
        a.scheduleId == scheduleId &&
        a.verification == VerificationResult.success &&
        a.timestamp.year == now.year &&
        a.timestamp.month == now.month &&
        a.timestamp.day == now.day);
  }

  // ---------------- Schedules ----------------
  Future<void> addSchedule(ScheduleItem schedule) async {
    await _fs.addSchedule(schedule);
    schedules.add(schedule);
    await _addLog(ActivityAction.scheduleCreated, 'Created schedule "${schedule.title}".');
    notifyListeners();
  }

  /// Edits an existing schedule in place (same id). Writing to Realtime
  /// Database uses the same "set by id" call as creating one, so this just
  /// needs to replace the matching entry in the local cache instead of
  /// appending a duplicate.
  Future<void> updateSchedule(ScheduleItem schedule) async {
    await _fs.addSchedule(schedule);
    final idx = schedules.indexWhere((s) => s.id == schedule.id);
    if (idx == -1) {
      schedules.add(schedule);
    } else {
      schedules[idx] = schedule;
    }
    await _addLog(ActivityAction.scheduleUpdated, 'Updated schedule "${schedule.title}".');
    notifyListeners();
  }

  Future<void> deleteSchedule(String id) async {
    await _fs.deleteSchedule(id);
    schedules.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  // ---------------- Branches ----------------
  Future<void> upsertBranch(Branch branch) async {
    await _fs.upsertBranch(branch);
    branches.removeWhere((b) => b.id == branch.id);
    branches.add(branch);
    await _addLog(ActivityAction.scheduleCreated, 'Saved branch "${branch.name}".');
    notifyListeners();
  }

  Future<void> deleteBranch(String id) async {
    await _fs.deleteBranch(id);
    branches.removeWhere((b) => b.id == id);
    notifyListeners();
  }

  Branch? branchById(String? id) {
    if (id == null) return null;
    return branches.where((b) => b.id == id).cast<Branch?>().firstOrNull;
  }

  // ---------------- Leave requests ----------------
  /// Employee/member: reports an absence with a reason.
  Future<void> submitLeaveRequest({required DateTime date, required String reason}) async {
    final user = currentUser;
    if (user == null) return;
    final request = LeaveRequest(
      id: '',
      userId: user.id,
      userName: user.name,
      date: date,
      reason: reason,
      submittedAt: DateTime.now(),
    );
    final saved = await _fs.addLeaveRequest(request);
    leaveRequests.insert(0, saved);
    await _addLog(ActivityAction.leaveRequested, '${user.name} reported an absence for ${date.toIso8601String().split("T").first}.');
    notifyListeners();
  }

  /// Admin: approves/rejects a leave request and optionally replies back to
  /// the employee (visible to them on their own leave history).
  Future<void> replyToLeaveRequest(String requestId, {required LeaveStatus status, String? reply}) async {
    final idx = leaveRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) return;
    final admin = currentUser;
    final updated = leaveRequests[idx].copyWith(
      status: status,
      adminReply: reply,
      repliedByName: admin?.name,
      repliedAt: DateTime.now(),
    );
    await _fs.updateLeaveRequest(updated);
    leaveRequests[idx] = updated;
    await _addLog(ActivityAction.leaveReplied, '${admin?.name ?? "Admin"} replied to ${updated.userName}\'s leave request (${status.name}).');
    notifyListeners();
  }

  List<LeaveRequest> leaveRequestsFor(String userId) => leaveRequests.where((r) => r.userId == userId).toList();

  // ---------------- Activity logs ----------------
  Future<void> _addLog(ActivityAction action, String description) async {
    final actor = currentUser;
    final log = ActivityLog(
      id: _uuid.v4(),
      actorUserId: actor?.id ?? 'system',
      actorName: actor?.name ?? 'System',
      action: action,
      description: description,
      timestamp: DateTime.now(),
    );
    await _fs.addLog(log);
    logs.insert(0, log);
  }

  // ---------------- Dashboard aggregates ----------------
  Map<AttendanceStatus, int> todaySummary() {
    final todays = attendanceOn(DateTime.now());
    final map = {for (final s in AttendanceStatus.values) s: 0};
    for (final r in todays) {
      map[r.status] = (map[r.status] ?? 0) + 1;
    }
    return map;
  }

  double attendanceRateOverDays(int days) {
    final now = DateTime.now();
    final since = now.subtract(Duration(days: days));
    final recent = attendance.where((a) => a.timestamp.isAfter(since)).toList();
    if (recent.isEmpty) return 0;
    final present = recent.where((a) => a.status == AttendanceStatus.present || a.status == AttendanceStatus.late).length;
    return present / recent.length;
  }
}

extension FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
