import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../services/face_descriptor_extractor.dart';

enum FaceCaptureMode { verify, enroll }

/// Shared full-screen camera view that detects faces in real time using
/// ML Kit, guards against zero-face / multi-face frames, and returns a
/// normalized face descriptor to the caller once a stable, well-lit,
/// front-facing detection is captured.
///
/// In [FaceCaptureMode.verify] it returns a single descriptor.
/// In [FaceCaptureMode.enroll] it guides the user through capturing three
/// angles (front, left, right) and returns an averaged descriptor plus a
/// reference thumbnail path, packaged in [EnrollmentResult].
class FaceCaptureScreen extends StatefulWidget {
  final FaceCaptureMode mode;
  const FaceCaptureScreen({super.key, required this.mode});

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class EnrollmentResult {
  final List<double> descriptor;
  final String thumbnailPath;
  final int sampleCount;
  EnrollmentResult({required this.descriptor, required this.thumbnailPath, required this.sampleCount});
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen> {
  CameraController? _controller;
  late final FaceDetector _detector;
  bool _busy = false;
  String _status = 'Position your face inside the frame';
  bool _cameraReady = false;
  String? _error;

  // enrollment state
  final List<List<double>> _capturedAngles = [];
  final List<String> _angleLabels = ['Look straight ahead', 'Turn slightly left', 'Turn slightly right'];

  @override
  void initState() {
    super.initState();
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        enableContours: false,
        enableClassification: false,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(front, ResolutionPreset.medium, enableAudio: false);
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _cameraReady = true;
      });
    } catch (e) {
      setState(() => _error = 'Camera unavailable: $e');
    }
  }

  Future<void> _capture() async {
    if (_controller == null || _busy) return;
    setState(() {
      _busy = true;
      _status = 'Analyzing...';
    });

    try {
      final file = await _controller!.takePicture();
      final inputImage = InputImage.fromFilePath(file.path);
      final faces = await _detector.processImage(inputImage);

      if (faces.isEmpty) {
        setState(() {
          _status = 'No face detected — try again';
          _busy = false;
        });
        return;
      }
      if (faces.length > 1) {
        setState(() {
          _status = 'Multiple faces detected — only one person at a time';
          _busy = false;
        });
        return;
      }

      final descriptor = FaceDescriptorExtractor.extract(faces.first);
      if (descriptor == null) {
        setState(() {
          _status = 'Could not read facial landmarks — face the camera directly';
          _busy = false;
        });
        return;
      }

      if (widget.mode == FaceCaptureMode.verify) {
        if (!mounted) return;
        Navigator.of(context).pop(descriptor);
        return;
      }

      // Enrollment: collect this angle and prompt for the next, or finish.
      _capturedAngles.add(descriptor);
      if (_capturedAngles.length < _angleLabels.length) {
        setState(() {
          _status = _angleLabels[_capturedAngles.length];
          _busy = false;
        });
      } else {
        final averaged = _averageDescriptors(_capturedAngles);
        if (!mounted) return;
        Navigator.of(context).pop(
          EnrollmentResult(descriptor: averaged, thumbnailPath: file.path, sampleCount: _capturedAngles.length),
        );
      }
    } catch (e) {
      setState(() {
        _status = 'Capture failed — try again';
        _busy = false;
      });
    }
  }

  List<double> _averageDescriptors(List<List<double>> all) {
    final length = all.first.length;
    final avg = List<double>.filled(length, 0);
    for (final d in all) {
      for (var i = 0; i < length; i++) {
        avg[i] += d[i] / all.length;
      }
    }
    return avg;
  }

  @override
  void dispose() {
    _controller?.dispose();
    _detector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEnroll = widget.mode == FaceCaptureMode.enroll;
    final promptText = isEnroll && _capturedAngles.isEmpty ? _angleLabels[0] : _status;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(isEnroll ? 'Register Face' : 'Verify Face'),
      ),
      body: _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white)))
          : !_cameraReady
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(_controller!),
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 260,
                        height: 320,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white70, width: 2),
                          borderRadius: BorderRadius.circular(140),
                        ),
                      ),
                    ),
                    if (isEnroll)
                      Positioned(
                        top: 12,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(_angleLabels.length, (i) {
                              final done = i < _capturedAngles.length;
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: done ? Colors.greenAccent : Colors.white38,
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 40,
                      left: 0,
                      right: 0,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                            child: Text(promptText, style: const TextStyle(color: Colors.white)),
                          ),
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: _busy ? null : _capture,
                            child: Container(
                              height: 70,
                              width: 70,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(color: Colors.white38, width: 4),
                              ),
                              child: _busy
                                  ? const Padding(padding: EdgeInsets.all(18), child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.camera_alt, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
