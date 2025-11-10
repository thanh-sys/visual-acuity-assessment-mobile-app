import 'package:flutter/material.dart';
import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:fluttertoast/fluttertoast.dart';

class DistanceCheckScreen extends StatefulWidget {
  const DistanceCheckScreen({Key? key}) : super(key: key);

  @override
  _DistanceCheckScreenState createState() => _DistanceCheckScreenState();
}

class _DistanceCheckScreenState extends State<DistanceCheckScreen> {
  ARKitController? arkitController;
  Vector3 cameraPosition = Vector3.zero();
  bool isAtCorrectDistance = false;
  static const double TARGET_DISTANCE = 3.0; // 3 meters
  static const double DISTANCE_TOLERANCE = 0.1; // ±10cm tolerance

  @override
  void dispose() {
    arkitController?.dispose();
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
              configuration: ARKitConfiguration.worldTracking,
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
    
    // Add a reference point at origin
    final referenceNode = ARKitNode(
      geometry: ARKitSphere(radius: 0.05),
      position: Vector3.zero(),
      materials: [
        ARKitMaterial(
          diffuse: ARKitMaterialProperty.color(Colors.yellow),
          lightingModelName: ARKitLightingModel.constant,
        )
      ],
    );
    arkitController?.add(referenceNode);

    // Add text node to show instructions
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

    // Start tracking camera position
    arkitController?.onUpdateNodeForAnchor = (ARKitAnchor anchor) {
      if (anchor is ARKitCameraAnchor) {
        final position = anchor.transform.getTranslation();
        setState(() {
          cameraPosition = Vector3(position.x, position.y, position.z);
          double distance = cameraPosition.length;
          isAtCorrectDistance = (distance - TARGET_DISTANCE).abs() <= DISTANCE_TOLERANCE;
          
          // Show toast when reaching correct distance
          if (isAtCorrectDistance) {
            Fluttertoast.showToast(
              msg: "Perfect distance reached!",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.CENTER,
              backgroundColor: Colors.green,
              textColor: Colors.white,
            );
          }
        });
      }
    };

    // Add plane detection feedback
    arkitController?.onAddNodeForAnchor = (ARKitAnchor anchor) {
      if (anchor is ARKitPlaneAnchor) {
        _showPlaneDetectionToast();
      }
    };
  }

  String _formatDistance(double distance) {
    return distance.toStringAsFixed(2);
  }

  void _showPlaneDetectionToast() {
    Fluttertoast.showToast(
      msg: "Surface detected. Please stand and hold the device steady.",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.TOP,
      backgroundColor: Colors.blue,
      textColor: Colors.white,
    );
  }
}