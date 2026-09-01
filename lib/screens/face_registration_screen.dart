import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import 'face_capture_screen.dart';

class FaceRegistrationScreen extends StatefulWidget {
  const FaceRegistrationScreen({super.key});

  @override
  State<FaceRegistrationScreen> createState() => _FaceRegistrationScreenState();
}

class _FaceRegistrationScreenState extends State<FaceRegistrationScreen> {
  bool _saving = false;

  Future<void> _startEnrollment() async {
    final state = context.read<AppState>();
    final user = state.currentUser;
    if (user == null) return;

    final result = await Navigator.of(context).push<EnrollmentResult?>(
      MaterialPageRoute(builder: (_) => const FaceCaptureScreen(mode: FaceCaptureMode.enroll)),
    );
    if (result == null || !mounted) return;

    setState(() => _saving = true);
    await state.saveFaceProfile(user.id, result.descriptor, result.thumbnailPath, result.sampleCount);
    setState(() => _saving = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Face profile registered successfully!')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final hasProfile = state.currentUser?.hasFaceProfile ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Face Registration')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Icon(hasProfile ? Icons.verified_user : Icons.face_retouching_natural,
                size: 96, color: hasProfile ? Colors.green : Colors.blue),
            const SizedBox(height: 20),
            Text(
              hasProfile ? 'Your face profile is registered' : 'Register your face to enable check-in/out',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              "We'll capture three angles (front, left, right) to build an accurate profile for verification. "
              "Make sure you're in a well-lit area and only your face is in frame.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _saving ? null : _startEnrollment,
              icon: _saving
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.camera_alt),
              label: Text(hasProfile ? 'Re-register Face' : 'Start Face Capture'),
            ),
          ],
        ),
      ),
    );
  }
}
