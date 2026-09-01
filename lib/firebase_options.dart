// File generated normally by the FlutterFire CLI. This is a PLACEHOLDER —
// you must replace it by running the real generator once you've created a
// Firebase project (see README.md, "Firebase setup"):
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// That command overwrites this file with real API keys/app IDs for each
// platform you select. Do NOT ship the placeholder values below — they will
// not connect to any project.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for this platform. '
          'Run `flutterfire configure` to generate real values.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAhcsCrvpBrsQbQAnWPN7MYzsUo1p1q5TA',
    appId: '1:427099065:web:placeholder',
    messagingSenderId: '427099065',
    projectId: 'faceattendent-44790',
    authDomain: 'faceattendent-44790.firebaseapp.com',
    databaseURL: 'https://faceattendent-44790-default-rtdb.firebaseio.com',
    storageBucket: 'faceattendent-44790.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAhcsCrvpBrsQbQAnWPN7MYzsUo1p1q5TA',
    appId: '1:427099065:android:a4d8f82ec9ce39e8e46c68',
    messagingSenderId: '427099065',
    projectId: 'faceattendent-44790',
    databaseURL: 'https://faceattendent-44790-default-rtdb.firebaseio.com',
    storageBucket: 'faceattendent-44790.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAhcsCrvpBrsQbQAnWPN7MYzsUo1p1q5TA',
    appId: '1:427099065:ios:placeholder',
    messagingSenderId: '427099065',
    projectId: 'faceattendent-44790',
    databaseURL: 'https://faceattendent-44790-default-rtdb.firebaseio.com',
    storageBucket: 'faceattendent-44790.firebasestorage.app',
    iosBundleId: 'com.example.faceAttendanceApp',
  );
}
