# Face Recognition Attendance App (Flutter)

A cross-platform (Android/iOS) Flutter app for recording student/employee
attendance via on-device face recognition, built around the requirements in
the assignment brief: user & face profile management, check-in/check-out,
attendance history, a dashboard with stats, schedules, GPS/device checks,
role-based access, activity logs, and reports.

## What's implemented

- **Auth & roles** — Firebase Authentication (email/password), with `admin`
  vs `member` roles stored on each user's Realtime Database profile node
  (`lib/services/app_state.dart`, `lib/screens/login_screen.dart`,
  `register_screen.dart`).
- **Database** — Firebase Realtime Database for all app data (users, face
  profiles, attendance, schedules, activity logs). See
  `lib/services/realtime_db_service.dart` for every read/write.
- **Photo storage** — face reference photos upload to **Cloudinary**
  (unsigned upload preset — see `lib/services/cloudinary_service.dart`),
  with only the resulting URL stored in the database.
- **Face registration** — guided 3-angle capture (front/left/right) using the
  device camera + Google ML Kit face detection. The averaged descriptor is
  saved to the database and the reference photo uploaded to Cloudinary
  (`lib/screens/face_capture_screen.dart`,
  `lib/services/face_descriptor_extractor.dart`).
- **Check-in / Check-out** — live camera capture, rejects frames with zero or
  multiple faces, matches the captured face against all enrolled profiles via
  cosine similarity, and records a timestamped attendance entry with
  Present/Late/Absent status derived from the active schedule
  (`lib/screens/check_in_out_screen.dart`, `lib/services/face_matcher.dart`).
- **GPS geofencing** — when a schedule defines a location (`latitude`/
  `longitude`/`radiusMeters`), check-in/out requests the device's current
  position (`lib/services/location_service.dart`, built on `geolocator`) and
  rejects the attempt with `VerificationResult.locationRejected` if the
  device is outside the allowed radius or location can't be determined.
  Admins set a schedule's geofence from **Schedules → + → Restrict check-in
  to a GPS location** (captures the admin's current device location and an
  adjustable radius).
- **Device validation** — a user's face profile is bound to the device it
  was captured on the first time they successfully check in
  (`lib/services/device_service.dart`, built on `device_info_plus`). A later
  check-in attempt from a different device is rejected with
  `VerificationResult.deviceMismatch`, which makes it harder for someone to
  reuse a face profile from a device that isn't the enrolled user's own.
  Admins can clear a stale binding (lost/replaced phone) from **User
  Management → edit user → Reset**.
- **Attendance history** — searchable/filterable list (by user name, status,
  class/group/department, and date range), personal view for members and
  all-users view for admins.
- **User management** — admins can search/filter users by class, group, or
  department, edit a user's organizational fields (class, group, room,
  subject, department, position), and remove a user's profile + face
  enrollment (`lib/screens/user_management_screen.dart`).
- **Dashboard** — today's present/late/absent counts, 7-day attendance rate,
  recent activity feed.
- **Schedules** — admins define class/shift windows (days, start/end time,
  late threshold) used to compute on-time vs. late. A schedule can also be
  assigned directly to specific employees (`ScheduleItem.assignedUserIds`)
  instead of matching everyone in a class/department, for "this person works
  Tue/Thu 2–6pm" style shifts.
- **Employee provisioning** — admins add employees directly from **User
  Management → + → Add Employee** without the person self-registering. The
  app generates a unique login email + temporary password (shown once) and
  creates the Firebase Auth account via a throwaway secondary `FirebaseApp`
  instance, so creating the account doesn't sign the admin out of their own
  session (`lib/services/employee_provisioning_service.dart`). Note: the
  generated "email" is a login identifier only, not a real deliverable
  mailbox — provisioning actual Gmail/Workspace inboxes needs the Google
  Workspace Admin SDK, which is a separate, out-of-scope integration.
- **Branches** — admins manage the company's physical sites (**Home →
  store icon**), each with its own map location (captured via "use current
  location") and check-in radius, for companies with multiple offices.
  Employees are assigned to a branch from their profile.
- **Call an employee** — admin's User Management list shows a call button
  next to any employee with a phone number on file, which opens the
  device's phone dialer via a `tel:` link.
- **Leave / absence requests with replies** — employees report an absence
  with a reason (**Home → mail icon**, or the "Leave" tab on member
  accounts); admins see all requests (**Leave tab** on admin accounts),
  approve/reject, and can send a reply message the employee sees on their
  own request. Admins don't have a check-in/out tab at all, since they
  aren't tracked for attendance themselves.
- **Reports** — daily/weekly/monthly/custom-range summaries and a
  "frequently absent" leaderboard.
- **Activity log** — audit trail of logins, registrations, face enrollments,
  and attendance events, written under `/activityLogs`.
- **Security model** — Realtime Database rules (`database.rules.json`)
  enforce that members can only read/write their own data, while admins can
  manage users, schedules, branches, leave requests, and reports. A
  `.validate` rule on `/users/{uid}/role`
  specifically blocks a self-registering (or directly-API-calling) user from
  setting their own role to `admin` — see the comment in that file for why a
  plain `.write` rule there wouldn't have worked (RTDB write rules cascade
  down from the parent node's permissive `auth.uid === $uid` grant). The one
  exception is a one-time bootstrap: the very first user written to a
  completely empty `/users` tree may set `role: admin` (this is what lets
  `_seedDemoAccounts` create the demo admin on first launch); once any user
  exists, that door closes permanently and only an existing admin can grant
  the admin role from then on.

## Project structure

```
lib/
  firebase_options.dart      # FlutterFire-generated config (placeholder — see setup)
  models/                    # AppUser, FaceProfile, AttendanceRecord, ScheduleItem, ActivityLog
  services/                   # AppState (Provider), RealtimeDbService, CloudinaryService, FaceMatcher, FaceDescriptorExtractor
  screens/                    # One file per screen
  widgets/                    # Reusable UI: StatCard, AttendanceTile
  utils/                      # Theme, status/color helpers
database.rules.json           # Realtime Database security rules
firebase.json                  # Firebase CLI deploy config
.firebaserc                    # Firebase project alias (set your project id here)
```

## Firebase setup

This app ships with **placeholder** config (`lib/firebase_options.dart`)
since real API keys can't be generated without a live Firebase project.

1. Create a project at https://console.firebase.google.com.
2. Enable these products in the console:
   - **Authentication** → Sign-in method → enable **Email/Password**.
   - **Realtime Database** → Create database → start in **locked mode**
     (the rules below replace the defaults).
3. Install the FlutterFire CLI and generate real config for this project:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   Select your Firebase project and the platforms you're targeting
   (Android/iOS/Web). This **overwrites** `lib/firebase_options.dart` with
   real values and registers the native apps automatically.
4. Set your project ID in `.firebaserc` (replace the placeholder), then
   deploy the database rules (or paste `database.rules.json` into the
   console's Rules tab):
   ```bash
   npm install -g firebase-tools
   firebase login
   firebase deploy --only database
   ```

## Cloudinary setup

Face reference photos go to Cloudinary instead of Firebase Storage.

1. Create a free account at https://cloudinary.com. Your **Cloud name** is
   shown on the dashboard home page.
2. Go to **Settings → Upload → Upload presets → Add upload preset**.
   - Set **Signing Mode** to **Unsigned** (required — this lets the app
     upload directly without embedding your API secret).
   - Under **Upload Manipulations**, set **Unique filename** to **off** and
     **Overwrite** to **on**. This makes re-registering a face replace the
     old photo at the same `public_id` instead of piling up duplicates.
   - Save the preset and copy its name.
3. Open `lib/services/cloudinary_service.dart` and replace the two
   placeholders:
   ```dart
   static const String cloudName = 'YOUR_CLOUD_NAME';
   static const String uploadPreset = 'YOUR_UNSIGNED_UPLOAD_PRESET';
   ```
4. That's it — no native SDK or extra dependency beyond `http`, which is
   already in `pubspec.yaml`.

## Install & run

1. Install dependencies and generate native runner folders:
   ```bash
   flutter pub get
   flutter create . --platforms=android,ios
   ```
2. Add the camera permission to the generated native projects:

   **Android** (`android/app/src/main/AndroidManifest.xml`, inside `<manifest>`):
   ```xml
   <uses-permission android:name="android.permission.CAMERA" />
   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
   ```
   and in `android/app/build.gradle`, make sure `minSdkVersion` is **21+**
   (required by ML Kit and Firebase).

   **iOS** (`ios/Runner/Info.plist`):
   ```xml
   <key>NSCameraUsageDescription</key>
   <string>Camera access is required to verify your face for attendance.</string>
   <key>NSLocationWhenInUseUsageDescription</key>
   <string>Location access is used to confirm you're checking in from an authorized location.</string>
   ```

   The location permissions are only needed if you plan to use GPS-restricted
   schedules/branches; the app works without them, it just can't enforce
   geofencing (and `LocationService.getCurrentPosition()` will return `null`,
   which `check_in_out_screen.dart` treats as a rejected attempt for
   schedules that *do* require GPS).

3. For the admin "call employee" button (`url_launcher` + `tel:` links) to
   work on **Android 11+**, add a `<queries>` block to
   `android/app/src/main/AndroidManifest.xml` (as a sibling of
   `<application>`, inside `<manifest>`):
   ```xml
   <queries>
     <intent>
       <action android:name="android.intent.action.DIAL" />
       <data android:scheme="tel" />
     </intent>
   </queries>
   ```
   Without this, Android's package-visibility rules can make the dialer
   intent silently fail to resolve. iOS needs no extra configuration for
   `tel:` links.
3. Run it:
   ```bash
   flutter run
   ```

## Demo accounts (seeded automatically the first time the app connects to an empty project)

| Role   | Email            | Password |
|--------|------------------|----------|
| Admin  | admin@demo.com   | admin123 |
| Member | jamie@demo.com   | demo1234 |

The first launch creates these two accounts directly in Firebase Auth + the
database (`AppState._seedDemoAccounts`) if `/users` is empty. Sign in as the
member account first and register your face (Profile → Register Face) —
you'll then be able to check in/out from the "Attend" tab. Sign in as admin
to see the Users, Schedules, and Reports tools. Delete this seeding call once
you have real accounts.

## Realtime Database data model

The whole app lives in one JSON tree:

```
/users/{uid}            AppUser          — profile, role, className/group/room/department, branchId, phoneNumber, faceProfileId, boundDeviceId
/faceProfiles/{uid}     FaceProfile      — descriptor (array of doubles), Cloudinary photo URL
/attendance/{pushId}    AttendanceRecord — userId, type, status, verification, timestamp, lat/lng, deviceId
/schedules/{pushId}     ScheduleItem     — class/shift windows, late threshold, optional GPS geofence, assignedUserIds
/branches/{pushId}      Branch           — name, address, latitude/longitude, radiusMeters
/leaveRequests/{pushId} LeaveRequest     — userId, date, reason, status, adminReply
/activityLogs/{pushId}  ActivityLog      — audit trail, admin-only read
```

Keys for `/users` and `/faceProfiles` are the Firebase Auth `uid`, so each
user has exactly one profile and one face enrollment. `/attendance`,
`/schedules`, and `/activityLogs` use `push()` keys (Firebase's
sortable-by-creation-time unique IDs). Record timestamps are also stored as
ISO-8601 strings, which sort identically to chronological order under plain
string comparison — so `orderByChild('timestamp')` returns correct
chronological order without needing `ServerValue.timestamp`.

`database.rules.json` declares `.indexOn: ["timestamp"]` for `/attendance`
and `/activityLogs`, and `.indexOn: ["email"]` for `/users`, since RTDB
requires an index to efficiently run `orderByChild`/`equalTo` queries at any
real scale.

## Notes on the face recognition approach

Real face **verification** (matching a live face to a stored identity) needs
a learned embedding model (FaceNet, ArcFace, MobileFaceNet, etc.). Bundling a
TFLite model was out of scope for this scaffold, so the app instead:

1. Uses **Google ML Kit Face Detection** (on-device, no model download step)
   to detect faces and extract landmark positions.
2. Converts landmarks into a normalized geometric feature vector
   (`FaceDescriptorExtractor`).
3. Compares vectors with cosine similarity (`FaceMatcher`), thresholded at
   `0.85`.

This correctly demonstrates the full attendance workflow (multi-face
rejection, no-face rejection, enrollment, matching, audit trail) but is
**less accurate than a real embedding network** — treat it as a reference
implementation to swap in a production face-recognition SDK
(e.g. `google_mlkit_face_mesh_detection` + a TFLite embedding model, AWS
Rekognition, Azure Face API, or a vendor SDK) before deploying for real
identity verification.

## Hardening for production

- The included `database.rules.json` is a solid starting point but should be
  reviewed against your exact access requirements before going live (e.g.
  rate-limiting attendance writes, validating field shapes with
  `newData.hasChildren([...])` checks).
- Move face matching (`FaceMatcher.bestMatch`) server-side (a Cloud Function
  triggered on `/faceProfiles` or `/attendance` writes) if you don't want
  every client to be able to read every user's face descriptor.
- **Unsigned Cloudinary uploads accept any file from anyone who has the
  preset name** (it's not a secret, just obscure). For production, either
  restrict the preset with an allowed-formats/max-file-size limit in the
  Cloudinary dashboard, or move the upload behind a small backend/Cloud
  Function that signs the request server-side instead of using an unsigned
  preset.
- Add GPS geofencing (the `ScheduleItem.latitude/longitude/radiusMeters`
  fields are already modeled) using the `geolocator` package to reject
  check-ins outside the authorized area. ✅ **Implemented** — see the "GPS
  geofencing" bullet above.
- Add device-binding/anti-spoofing (liveness detection) to prevent someone
  from checking in using a photo of another person's face. Device-binding is
  ✅ **implemented** (a profile locks to the first device it verifies from —
  see "Device validation" above); true liveness detection (blink/head-turn
  challenge, or a depth/IR sensor) is still out of scope and would be needed
  to stop someone holding up a photo or video of the enrolled user.
- Enable Firebase App Check to ensure only your app's builds can write to
  the database.
