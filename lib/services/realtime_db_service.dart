import 'dart:io';
import 'package:firebase_database/firebase_database.dart';
import '../models/user_model.dart';
import '../models/face_profile_model.dart';
import '../models/attendance_model.dart';
import '../models/schedule_model.dart';
import '../models/activity_log_model.dart';
import '../models/branch_model.dart';
import '../models/leave_request_model.dart';
import 'cloudinary_service.dart';

/// All Firebase Realtime Database access lives here. Data is a single JSON
/// tree:
///
///   /users/{uid}              -> AppUser            (key == Firebase Auth uid)
///   /faceProfiles/{uid}       -> FaceProfile         (key == user id, 1 profile per user)
///   /attendance/{pushId}      -> AttendanceRecord    (key == push() id)
///   /schedules/{pushId}       -> ScheduleItem         (key == push() id)
///   /activityLogs/{pushId}    -> ActivityLog          (key == push() id)
///
/// Face reference thumbnails are uploaded to **Cloudinary** (not Firebase
/// Storage) via [CloudinaryService]; only the resulting URL is stored on the
/// FaceProfile record.
///
/// Timestamps are stored as ISO-8601 strings, which sort correctly under
/// plain string ordering — so `orderByChild('timestamp')` gives correct
/// chronological order without needing RTDB's numeric ServerValue.timestamp.
class RealtimeDbService {
  RealtimeDbService._();
  static final RealtimeDbService instance = RealtimeDbService._();

  final _db = FirebaseDatabase.instance;
  final _cloudinary = CloudinaryService.instance;

  DatabaseReference get _users => _db.ref('users');
  DatabaseReference get _faceProfiles => _db.ref('faceProfiles');
  DatabaseReference get _attendance => _db.ref('attendance');
  DatabaseReference get _schedules => _db.ref('schedules');
  DatabaseReference get _logs => _db.ref('activityLogs');
  DatabaseReference get _branches => _db.ref('branches');
  DatabaseReference get _leaveRequests => _db.ref('leaveRequests');

  Map<String, dynamic> _asMap(Object? value) => Map<String, dynamic>.from(value as Map);

  // ---------------- Users ----------------
  Future<void> upsertUser(AppUser user) => _users.child(user.id).set(user.toJson());

  Future<AppUser?> getUser(String uid) async {
    final snap = await _users.child(uid).get();
    if (!snap.exists) return null;
    return AppUser.fromJson({..._asMap(snap.value), 'id': uid});
  }

  Future<List<AppUser>> getAllUsers() async {
    final snap = await _users.get();
    if (!snap.exists) return [];
    final map = _asMap(snap.value);
    return map.entries.map((e) => AppUser.fromJson({..._asMap(e.value), 'id': e.key})).toList();
  }

  Future<bool> emailExists(String email) async {
    final snap = await _users.orderByChild('email').equalTo(email).limitToFirst(1).get();
    return snap.exists;
  }

  /// Removes the user's profile and face enrollment node. Does NOT remove
  /// the Firebase Auth account (client SDKs can only delete the currently
  /// signed-in account) — an admin should also disable/delete the Auth
  /// account from the Firebase console.
  Future<void> deleteUser(String uid) async {
    await _users.child(uid).remove();
    await _faceProfiles.child(uid).remove();
  }

  // ---------------- Face profiles ----------------
  /// Uploads the reference thumbnail to Cloudinary (if configured), then
  /// writes the profile node (overwriting any prior enrollment for this user).
  Future<FaceProfile> saveFaceProfile({
    required String userId,
    required List<double> descriptor,
    required File thumbnailFile,
    required int sampleCount,
  }) async {
    String url = thumbnailFile.path;
    if (CloudinaryService.cloudName != 'YOUR_CLOUD_NAME') {
      try {
        url = await _cloudinary.uploadImage(thumbnailFile, publicId: 'face_profiles/$userId');
      } catch (_) {
        // Fall back to local file path if Cloudinary fails
        url = thumbnailFile.path;
      }
    }

    final profile = FaceProfile(
      id: userId,
      userId: userId,
      descriptor: descriptor,
      sampleImagePath: url,
      registeredAt: DateTime.now(),
      sampleCount: sampleCount,
    );
    await _faceProfiles.child(userId).set(profile.toJson());
    await _users.child(userId).update({'faceProfileId': userId});
    return profile;
  }

  Future<List<FaceProfile>> getAllFaceProfiles() async {
    final snap = await _faceProfiles.get();
    if (!snap.exists) return [];
    final map = _asMap(snap.value);
    return map.entries.map((e) => FaceProfile.fromJson({..._asMap(e.value), 'id': e.key})).toList();
  }

  // ---------------- Attendance ----------------
  Future<AttendanceRecord> addAttendance(AttendanceRecord record) async {
    final ref = _attendance.push();
    final withId = AttendanceRecord(
      id: ref.key!,
      userId: record.userId,
      userName: record.userName,
      scheduleId: record.scheduleId,
      timestamp: record.timestamp,
      type: record.type,
      status: record.status,
      verification: record.verification,
      matchConfidence: record.matchConfidence,
      latitude: record.latitude,
      longitude: record.longitude,
      deviceId: record.deviceId,
      note: record.note,
    );
    await ref.set(withId.toJson());
    return withId;
  }

  /// Permanently removes an attendance record (admin correction tool — e.g.
  /// undoing a mistaken/test check-in so the person can check in again for
  /// that same schedule today). The database rules also enforce that only
  /// admins can delete an existing record, regardless of what this call does.
  Future<void> deleteAttendance(String id) => _attendance.child(id).remove();

  /// Loads attendance ordered newest-first. [limit] keeps initial loads fast;
  /// pass null to fetch everything (used by Reports for custom ranges).
  /// Requires `.indexOn: ["timestamp"]` on /attendance (see database.rules.json).
  Future<List<AttendanceRecord>> getAttendance({int? limit}) async {
    Query q = _attendance.orderByChild('timestamp');
    if (limit != null) q = q.limitToLast(limit);
    final snap = await q.get();
    if (!snap.exists) return [];
    final map = _asMap(snap.value);
    final list = map.entries.map((e) => AttendanceRecord.fromJson({..._asMap(e.value), 'id': e.key})).toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // newest-first
    return list;
  }

  // ---------------- Schedules ----------------
  Future<void> addSchedule(ScheduleItem schedule) => _schedules.child(schedule.id).set(schedule.toJson());

  Future<void> deleteSchedule(String id) => _schedules.child(id).remove();

  Future<List<ScheduleItem>> getSchedules() async {
    final snap = await _schedules.get();
    if (!snap.exists) return [];
    final map = _asMap(snap.value);
    return map.entries.map((e) => ScheduleItem.fromJson({..._asMap(e.value), 'id': e.key})).toList();
  }

  // ---------------- Activity logs ----------------
  Future<void> addLog(ActivityLog log) => _logs.child(log.id).set(log.toJson());

  /// Requires `.indexOn: ["timestamp"]` on /activityLogs (see database.rules.json).
  Future<List<ActivityLog>> getLogs({int limit = 200}) async {
    final snap = await _logs.orderByChild('timestamp').limitToLast(limit).get();
    if (!snap.exists) return [];
    final map = _asMap(snap.value);
    final list = map.entries.map((e) => ActivityLog.fromJson({..._asMap(e.value), 'id': e.key})).toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // newest-first
    return list;
  }

  // ---------------- Branches ----------------
  Future<void> upsertBranch(Branch branch) => _branches.child(branch.id).set(branch.toJson());

  Future<void> deleteBranch(String id) => _branches.child(id).remove();

  Future<List<Branch>> getBranches() async {
    final snap = await _branches.get();
    if (!snap.exists) return [];
    final map = _asMap(snap.value);
    return map.entries.map((e) => Branch.fromJson({..._asMap(e.value), 'id': e.key})).toList();
  }

  // ---------------- Leave requests ----------------
  Future<LeaveRequest> addLeaveRequest(LeaveRequest request) async {
    final ref = _leaveRequests.push();
    final withId = LeaveRequest(
      id: ref.key!,
      userId: request.userId,
      userName: request.userName,
      date: request.date,
      reason: request.reason,
      status: request.status,
      submittedAt: request.submittedAt,
    );
    await ref.set(withId.toJson());
    return withId;
  }

  Future<void> updateLeaveRequest(LeaveRequest request) => _leaveRequests.child(request.id).set(request.toJson());

  /// Requires `.indexOn: ["submittedAt"]` on /leaveRequests (see database.rules.json).
  Future<List<LeaveRequest>> getLeaveRequests() async {
    final snap = await _leaveRequests.orderByChild('submittedAt').get();
    if (!snap.exists) return [];
    final map = _asMap(snap.value);
    final list = map.entries.map((e) => LeaveRequest.fromJson({..._asMap(e.value), 'id': e.key})).toList();
    list.sort((a, b) => b.submittedAt.compareTo(a.submittedAt)); // newest-first
    return list;
  }
}
