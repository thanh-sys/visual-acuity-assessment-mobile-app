  import 'package:flutter/material.dart';
  import 'package:arkit_plugin/arkit_plugin.dart';
  import 'package:vector_math/vector_math_64.dart' hide Colors;  // hide Colors to avoid conflict
  import 'package:flutter_tts/flutter_tts.dart';
  import 'package:flutter_application_1/Screens/Instructions/cover_eye_instruction.dart';
  import 'package:flutter_application_1/Screens/Measure/measure_acuity.dart';

  class DistanceCheckScreen extends StatefulWidget {
    final VoidCallback? onSuccess;

    // If skipDistanceCheck is true, the screen will only verify that the right eye
    // is covered and will not enforce the 3m distance requirement.
    final bool skipDistanceCheck;

    const DistanceCheckScreen({Key? key, this.onSuccess, this.skipDistanceCheck = false}) : super(key: key);

    @override
    _DistanceCheckScreenState createState() => _DistanceCheckScreenState();
  }

  class _DistanceCheckScreenState extends State<DistanceCheckScreen> {
    ARKitController? arkitController;
    Vector3 cameraPosition = Vector3.zero();
    bool isAtCorrectDistance = false;
    static const double TARGET_DISTANCE = 3.0; // 3 meters
    static const double DISTANCE_TOLERANCE = 0.2; // ±20cm tolerance

    final FlutterTts _tts = FlutterTts();
    bool _spokenTooClose = false;
    bool _spokenTooFar = false;
    bool _previouslyAtCorrectDistance = false;
    bool _hasSpokenSuccess = false;
    DateTime? _correctDistanceStartTime;
    bool _isNavigating = false; // Prevent multiple navigation attempts
    static const int CORRECT_DISTANCE_DURATION_MS = 4000; // 3 seconds

    @override
    void initState() {
      super.initState();
      _initTTS();
    }

    Future<void> _initTTS() async {
      await _tts.setLanguage("en-US"); // English voice
      await _tts.setSpeechRate(0.5);  // natural speed
      await _tts.setPitch(1.0);
    }

    @override
    void dispose() {
      arkitController?.dispose();
      _tts.stop();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Distance Check'),
          backgroundColor: Colors.blue,
        ),
        body: Column(
          children: [
            Expanded(
              child: ARKitSceneView(
                enableTapRecognizer: true,
                onARKitViewCreated: onARKitViewCreated,
                configuration: ARKitConfiguration.faceTracking,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              color: isAtCorrectDistance ? Colors.green : Colors.red,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isAtCorrectDistance
                        ? 'Perfect! You are at 3 meters'
                        : 'Please adjust your position to be 3 meters away',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Current distance: ${_formatDistance(cameraPosition.length)} meters',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    void onARKitViewCreated(ARKitController controller) {
      this.arkitController = controller;

      final referenceNode = ARKitNode(
        geometry: ARKitSphere(
          radius: 0.05,
          materials: [
            ARKitMaterial(
              diffuse: ARKitMaterialProperty.color(Colors.yellow),
              lightingModelName: ARKitLightingModel.constant,
            )
          ],
        ),
        position: Vector3.zero(),
      );
      arkitController?.add(referenceNode);

      final textNode = ARKitNode(
        geometry: ARKitText(
          text: '3m Reference Point',
          extrusionDepth: 1,
          materials: [
            ARKitMaterial(
              diffuse: ARKitMaterialProperty.color(Colors.blue),
              lightingModelName: ARKitLightingModel.constant,
            )
          ],
        ),
        position: Vector3(0, 0.1, 0),
        scale: Vector3.all(0.01),
      );
      arkitController?.add(textNode);

      arkitController?.onUpdateNodeForAnchor = (ARKitAnchor anchor) async {
        if (anchor is ARKitFaceAnchor) {
          final pos = anchor.transform.getTranslation();
          final distance = pos.length;

          if (!mounted) return;
          setState(() {
            cameraPosition = Vector3(pos.x, pos.y, pos.z);
            isAtCorrectDistance = (distance - TARGET_DISTANCE).abs() <= DISTANCE_TOLERANCE;
          });

          // --- SPEAK LOGIC ---
          // Nếu từng đúng khoảng cách nhưng giờ lại sai, reset flags để phát âm lại
          if (_previouslyAtCorrectDistance && !isAtCorrectDistance) {
            _spokenTooClose = false;
            _spokenTooFar = false;
          }

          if (!widget.skipDistanceCheck && !isAtCorrectDistance && distance < TARGET_DISTANCE - DISTANCE_TOLERANCE) {
            if (!_spokenTooClose) {
              _spokenTooClose = true;
              _spokenTooFar = false;
              await _tts.stop();
              await _tts.speak('Please move back. You are too close.');
            }
          } else if (!widget.skipDistanceCheck && !isAtCorrectDistance && distance > TARGET_DISTANCE + DISTANCE_TOLERANCE) {
            if (!_spokenTooFar) {
              _spokenTooFar = true;
              _spokenTooClose = false;
              await _tts.stop();
              await _tts.speak('Please move closer. You are too far.');
            }
          }

          // Cập nhật trạng thái trước đó
          _previouslyAtCorrectDistance = isAtCorrectDistance;

          // Determine success condition depending on whether distance check is required
          final bool distanceOk = widget.skipDistanceCheck ? true : isAtCorrectDistance;
          
          if (distanceOk) {
            // Nếu vừa đúng khoảng cách, bắt đầu đếm thời gian
            if (_correctDistanceStartTime == null) {
              _correctDistanceStartTime = DateTime.now();
              
              if (!_hasSpokenSuccess) {
                _hasSpokenSuccess = true;
                await _tts.stop();
                await _tts.speak('Please stand still 3 seconds.');
              }
            }
            await Future.delayed(const Duration(milliseconds: 500));
            // Kiểm tra xem đã đúng khoảng cách 3 giây chưa
            if (_correctDistanceStartTime == null) return; // guard against null
            final elapsedTime = DateTime.now().difference(_correctDistanceStartTime!).inMilliseconds;
            if (elapsedTime >= CORRECT_DISTANCE_DURATION_MS && !_isNavigating) {
              if (!mounted) return;
              _isNavigating = true;
              
              // Stop TTS immediately before navigation
              await _tts.stop();
              
              // Add small delay to ensure TTS is stopped
              await Future.delayed(const Duration(milliseconds: 100));
              
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => MeasureAcuity(eyeToTest: "left",leftEyeScore: 0,   // TRUYỀN QUA TIẾP
      ),
              
            ),
          );
            }
          } else {
            // Nếu sai khoảng cách, reset timer
            _correctDistanceStartTime = null;
            _hasSpokenSuccess = false;
          }
        }
      };
    }

    String _formatDistance(double distance) {
      return distance.toStringAsFixed(2);
    }
  }
