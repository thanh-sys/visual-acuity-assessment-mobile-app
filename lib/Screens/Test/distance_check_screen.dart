import 'package:flutter/material.dart';
import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;  // hide Colors to avoid conflict
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_tts/flutter_tts.dart';

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
  static const double DISTANCE_TOLERANCE = 0.3; // ±30cm tolerance

  final FlutterTts _tts = FlutterTts();
  bool _spokenTooClose = false;
  bool _spokenTooFar = false;
  bool _spokenCoverEye = false;

  @override
  void initState() {
    super.initState();
    _initTTS();
  }

  Future<void> _initTTS() async {
    await _tts.setLanguage("en-US"); // English voice
    await _tts.setSpeechRate(0.45);  // natural speed
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

        double rightBlink = anchor.blendShapes['eyeBlinkRight'] ?? 0.0;
        final isRightEyeCovered = rightBlink > 0.6;

        if (!mounted) return;
        setState(() {
          cameraPosition = Vector3(pos.x, pos.y, pos.z);
          isAtCorrectDistance = (distance - TARGET_DISTANCE).abs() <= DISTANCE_TOLERANCE;
        });

        // --- SPEAK LOGIC FIXED ---
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
        } else if ((!widget.skipDistanceCheck && isAtCorrectDistance && !_spokenCoverEye) || (widget.skipDistanceCheck && !_spokenCoverEye)) {
          _spokenCoverEye = true;
          await _tts.stop();
          // If skipping distance check, we still instruct user to cover right eye
          await _tts.speak('Please cover your right eye.');
        }

        // Determine success condition depending on whether distance check is required
        final bool distanceOk = widget.skipDistanceCheck ? true : isAtCorrectDistance;
        if (distanceOk) {
          if (isRightEyeCovered) {
            if (widget.onSuccess != null) {
              if (!mounted) return;
              widget.onSuccess!();
            } else {
              Fluttertoast.showToast(
                msg: "Ready. Proceeding...",
                toastLength: Toast.LENGTH_SHORT,
                gravity: ToastGravity.CENTER,
                backgroundColor: Colors.green,
                textColor: Colors.white,
              );
            }
          } else {
            await _tts.stop();
            await _tts.speak('Please cover your right eye with your hand.');
          }
        }
      }
    };
  }

  String _formatDistance(double distance) {
    return distance.toStringAsFixed(2);
  }
}
