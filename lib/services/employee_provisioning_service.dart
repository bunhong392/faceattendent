import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../firebase_options.dart';

/// Result of provisioning a new employee login: the credentials an admin
/// hands to the employee, and the new Firebase Auth uid to write the
/// AppUser profile under.
class ProvisionedLogin {
  final String uid;
  final String loginEmail;
  final String temporaryPassword;
  ProvisionedLogin({required this.uid, required this.loginEmail, required this.temporaryPassword});
}

/// Creates Firebase Auth accounts *on behalf of* an admin, for employees who
/// don't sign themselves up. The employee doesn't need a real mailbox — the
/// generated address is only ever used as a Firebase Auth login identifier,
/// never sent an email — so the admin must hand the generated email +
/// password to the employee directly (e.g. printed on a slip, or read out
/// loud) after creating the account.
///
/// IMPORTANT: `FirebaseAuth.createUserWithEmailAndPassword` on the *default*
/// Firebase app automatically signs in as the newly created user on the
/// client SDK — which would kick the admin out of their own session. To
/// avoid that, this service creates the account on a **second, temporary
/// Firebase App instance** that shares the same project config but keeps
/// its own independent Auth session, then tears that instance down. The
/// admin's own sign-in on the default app is never touched.
class EmployeeProvisioningService {
  EmployeeProvisioningService._();

  static const _companyEmailDomain = 'company.internal';

  /// Generates a unique, readable login email like
  /// "jane.doe.4821@company.internal" from a full name.
  static String generateLoginEmail(String fullName) {
    final slug = fullName
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .join('.');
    final suffix = Random().nextInt(9000) + 1000; // 4-digit disambiguator
    final base = slug.isEmpty ? 'employee' : slug;
    return '$base.$suffix@$_companyEmailDomain';
  }

  /// Generates a random temporary password the admin can hand over
  /// (employee should be encouraged to change it after first login, if a
  /// "change password" flow is added later).
  static String generateTemporaryPassword() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
    final rand = Random.secure();
    return List.generate(10, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Creates the Firebase Auth account for [loginEmail]/[password] without
  /// disturbing the currently signed-in admin session.
  static Future<String> createAuthAccount({
    required String loginEmail,
    required String password,
  }) async {
    final secondaryApp = await Firebase.initializeApp(
      name: 'employee_provisioning_${DateTime.now().microsecondsSinceEpoch}',
      options: DefaultFirebaseOptions.currentPlatform,
    );
    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final cred = await secondaryAuth.createUserWithEmailAndPassword(email: loginEmail, password: password);
      final uid = cred.user!.uid;
      await secondaryAuth.signOut();
      return uid;
    } finally {
      await secondaryApp.delete();
    }
  }
}
