import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'detector_view.dart';
import 'painters/pose_painter.dart';

class PoseDetectorView extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _PoseDetectorViewState();
}

class _PoseDetectorViewState extends State<PoseDetectorView> {
  final PoseDetector _poseDetector =
      PoseDetector(options: PoseDetectorOptions());
  final FlutterTts _flutterTts = FlutterTts();
  DateTime? _lastAnnounceAt;
  String? _lastAnnouncement;
  // Configurable constants
  static const double _distanceThresholdRatio = 0.015; // fraction of image diagonal
  static const int _announceDebounceSeconds = 2; // seconds
  bool _canProcess = true;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  String? _text;
  var _cameraLensDirection = CameraLensDirection.back;

  @override
  void dispose() async {
    _canProcess = false;
    _poseDetector.close();
    await _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DetectorView(
      title: 'Pose Detector',
      customPaint: _customPaint,
      text: _text,
      onImage: _processImage,
      initialCameraLensDirection: _cameraLensDirection,
      onCameraLensDirectionChanged: (value) => _cameraLensDirection = value,
    );
  }

  Future<void> _processImage(InputImage inputImage) async {
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;
    setState(() {
      _text = '';
    });
    final poses = await _poseDetector.processImage(inputImage);
    // Detect if a wrist is close to an eye and announce via TTS.
    try {
  final imageSize = inputImage.metadata?.size ?? Size(480, 360);
  final diag = math.sqrt(imageSize.width * imageSize.width + imageSize.height * imageSize.height);
  // threshold relative to image diagonal
  final threshold = diag * _distanceThresholdRatio; // fraction of diagonal

      for (final pose in poses) {
        final leftEye = pose.landmarks[PoseLandmarkType.leftEye];
        final rightEye = pose.landmarks[PoseLandmarkType.rightEye];
        final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
        final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

        Future<void> checkWrist(PoseLandmark? wrist) async {
          if (wrist == null) return;
          if (leftEye == null || rightEye == null) return;
          double dist(a, b) => math.sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y));
          final dLeft = dist(wrist, leftEye);
          final dRight = dist(wrist, rightEye);
          final minD = dLeft < dRight ? dLeft : dRight;
          if (minD < threshold) {
            final eye = dLeft < dRight ? 'LEFT' : 'RIGHT';
            final announcement = ' $eye is being covered';
            final now = DateTime.now();
            if (_lastAnnouncement != announcement || _lastAnnounceAt == null || now.difference(_lastAnnounceAt!).inSeconds > _announceDebounceSeconds) {
              _lastAnnouncement = announcement;
              _lastAnnounceAt = now;
              await _flutterTts.speak(announcement);
            }
          }
        }

        await checkWrist(leftWrist);
        await checkWrist(rightWrist);
      }
    } catch (e) {
      // ignore TTS or detection errors
    }
    if (inputImage.metadata?.size != null &&
        inputImage.metadata?.rotation != null) {
      final painter = PosePainter(
        poses,
        inputImage.metadata!.size,
        inputImage.metadata!.rotation,
        _cameraLensDirection,
      );
      _customPaint = CustomPaint(painter: painter);
    } else {
      _text = 'Poses found: ${poses.length}\n\n';
      // TODO: set _customPaint to draw landmarks on top of image
      _customPaint = null;
    }
    _isBusy = false;
    if (mounted) {
      setState(() {});
    }
  }
}