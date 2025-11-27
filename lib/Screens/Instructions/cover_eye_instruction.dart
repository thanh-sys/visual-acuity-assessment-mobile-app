import 'package:flutter/material.dart';
import 'package:flutter_application_1/Screens/Measure/measure_acuity.dart';
import 'package:flutter_application_1/Screens/Test/distance_check_screen.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:camera/camera.dart';
import 'package:arkit_plugin/arkit_plugin.dart';
import 'dart:math' as math;
import 'dart:async';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../vision_detector_views/detector_view.dart';

class CoverEyeInstruction extends StatefulWidget {
  final String eyeToCover; // 'left' or 'right'
  // final Function(String) onCoverConfirmed; // Callback with eye to test ('left' or 'right')
  final int leftEyeScore;
  const CoverEyeInstruction({
    Key? key,
    required this.eyeToCover,
    required this.leftEyeScore,
    // required this.onCoverConfirmed,
  }) : super(key: key);

  @override
  State<CoverEyeInstruction> createState() => _CoverEyeInstructionState();
}

class _CoverEyeInstructionState extends State<CoverEyeInstruction> {
  ARKitController? _arkitController;
  final FlutterTts _tts = FlutterTts();
  // Pose detection members
  final PoseDetector _poseDetector = PoseDetector(options: PoseDetectorOptions());
  bool _canProcess = true;
  bool _isBusy = false;
  DateTime? _lastAnnounceAt;
  String? _lastAnnouncement;
  bool _detectedCorrectCover = false;
  bool _navigated = false;
  
  // Timer and state tracking
  Timer? _noDetectionTimer;
  bool _hasShownInitialPrompt = false;
  bool _hasShownWarning = false;
  bool _confirmingCover = false;
  int _consecutiveFramesDetected = 0;
  int _missedFrames = 0; // Đếm số frame bị mất liên tiếp
  static const int _maxMissedFramesAllowed = 30; // Cho phép mất tín hiệu 10 frame (khoảng 0.3s) mà không bị reset
  // Constants
  static const double _distanceThresholdRatio = 0.011;
  static const int _noDetectionWaitSeconds = 10;
  static const int _requiredConsecutiveFrames = 35;

  // Determine which eye to cover and which to test
  late String _eyeToCover;
  late String _eyeToTest;

  @override
  void initState() {
    super.initState();
    _eyeToCover = widget.eyeToCover.toLowerCase();
    _eyeToTest = _eyeToCover == 'left' ? 'right' : 'left';
    
    _initTts().then((_) {
      final coverMsg = _eyeToCover == 'left' 
        ? 'I will check that you have covered the left eye.'
        : 'I will check that you have covered the right eye.';
      _tts.speak(coverMsg);
    });
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
  }

  @override
  void dispose() {
    _arkitController?.dispose();
    _tts.stop();
    _canProcess = false;
    _noDetectionTimer?.cancel();
    _poseDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imagePath = _eyeToCover == 'left' 
      ? 'assets/images/Lefteye.png' 
      : 'assets/images/righteye.png';
    
    final promptText = _detectedCorrectCover
      ? 'Detected: ${_eyeToCover} eye covered'
      : 'Detecting... Please cover your ${_eyeToCover} eye';

    return Scaffold(
      body: Stack(
        children: [
          // Camera invisible (still processing frames)
          Opacity(
            opacity: 0,
            child: DetectorView(
              title: '${_eyeToCover} eye coverage',
              onImage: _processImage,
              initialCameraLensDirection: CameraLensDirection.front,
            ),
          ),

          // UI OVERLAY
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                  Expanded(
                    child: Image.asset(
                      imagePath,
                      fit: BoxFit.fitWidth,
                    ),
                  ),
                  Text(
                    promptText,
                    style: const TextStyle(fontSize: 22),
                  ),

                  SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processImage(InputImage inputImage) async {
    if (!_canProcess || _isBusy) return;
    _isBusy = true;

    try {
      final poses = await _poseDetector.processImage(inputImage);
      final imageSize = inputImage.metadata?.size ?? const Size(480, 360);
      final diag = math.sqrt(imageSize.width * imageSize.width + imageSize.height * imageSize.height);
      

      final threshold = diag * 0.011; 

      bool isCoveringAnyEye = false;
      String? coveredEyeSide; // 'LEFT' hoặc 'RIGHT'

      // 1. Tìm xem có tay nào đang che mắt không
      for (final pose in poses) {
        final leftEye = pose.landmarks[PoseLandmarkType.leftEye];
        final rightEye = pose.landmarks[PoseLandmarkType.rightEye];
        final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
        final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

        if (leftEye == null || rightEye == null) continue;

        double dist(PoseLandmark a, PoseLandmark b) => 
            math.sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y));

        // Kiểm tra cổ tay trái
        if (leftWrist != null) {
          double dL = dist(leftWrist, leftEye);
          double dR = dist(leftWrist, rightEye);
          if (dL < threshold) { isCoveringAnyEye = true; coveredEyeSide = 'LEFT'; }
          else if (dR < threshold) { isCoveringAnyEye = true; coveredEyeSide = 'RIGHT'; }
        }

        // Kiểm tra cổ tay phải (nếu chưa tìm thấy ở tay trái)
        if (!isCoveringAnyEye && rightWrist != null) {
          double dL = dist(rightWrist, leftEye);
          double dR = dist(rightWrist, rightEye);
          if (dL < threshold) { isCoveringAnyEye = true; coveredEyeSide = 'LEFT'; }
          else if (dR < threshold) { isCoveringAnyEye = true; coveredEyeSide = 'RIGHT'; }
        }
      }

      // 2. Logic xử lý Đếm và Reset (Quan trọng)
      if (isCoveringAnyEye && coveredEyeSide != null) {
        // --- TRƯỜNG HỢP PHÁT HIỆN TAY ---
        _missedFrames = 0; // Reset biến đếm lỗi vì đã thấy tay lại rồi
        _noDetectionTimer?.cancel();
        _hasShownWarning = false;

        final targetEyeUpper = _eyeToCover.toUpperCase();
        final expectedCameraEye = (targetEyeUpper == 'LEFT') ? 'RIGHT' : 'LEFT';
        if (coveredEyeSide == expectedCameraEye) {
          // A. CHE ĐÚNG MẮT
          _consecutiveFramesDetected++; // Tăng biến đếm
          print("Correct Eye: $_consecutiveFramesDetected"); // Log để kiểm tra

          // Nói nhắc nhở giữ tay (chỉ nói 1 lần khi bắt đầu chuỗi)
          if (!_confirmingCover && !_detectedCorrectCover) {
            _confirmingCover = true;
            final msg = _eyeToCover == 'left'
                ? 'Please keep your left eye covered.'
                : 'Please keep your right eye covered.';
            await _tts.speak(msg);
          }

          // Kiểm tra hoàn thành
          if (_consecutiveFramesDetected >= _requiredConsecutiveFrames && !_detectedCorrectCover && mounted) {
            _handleSuccess();
          }
        } else {
          // B. CHE SAI MẮT
          // Nếu che sai mắt thì reset ngay lập tức, không khoan nhượng
          // _consecutiveFramesDetected = 0;
          _confirmingCover = false;
          
          final wrongEyeName = coveredEyeSide == 'LEFT' ? 'left' : 'right';
          final correctEyeName = _eyeToCover;
          final announcement = 'You are covering your $wrongEyeName eye. Please cover your $correctEyeName eye.';
          _speakWarning(announcement);
        }
      } else {
        // --- TRƯỜNG HỢP KHÔNG THẤY TAY (HOẶC BỊ NHIỄU 1-2 FRAME) ---
        if (!_detectedCorrectCover) {
          _missedFrames++; // Tăng biến đếm lỗi
          
          // Chỉ reset nếu mất tín hiệu quá lâu (quá 10 frame liên tiếp)
          if (_missedFrames > _maxMissedFramesAllowed) {
            if (_consecutiveFramesDetected > 0) {
              print("Lost detection for too long. Resetting counter.");
            }
            _consecutiveFramesDetected = 0;
            _confirmingCover = false;
            
            // Logic nhắc nhở nếu chưa từng detect được gì
            if (!_hasShownInitialPrompt) {
              _hasShownInitialPrompt = true;
              final msg = 'Please cover your $_eyeToCover eye.';
              await _tts.speak(msg);
              _startNoDetectionTimer();
            }
          } else {
            // Nếu mới mất tín hiệu vài frame thì KHÔNG LÀM GÌ CẢ (giữ nguyên _consecutiveFramesDetected)
            print("Frame skipped (Glitch protection): $_missedFrames");
          }
        }
      }
    } catch (e) {
      print("Error: $e");
    }

    _isBusy = false;
    if (mounted) setState(() {});
  }

  // Tách hàm xử lý thành công cho gọn
  void _handleSuccess() {
    _detectedCorrectCover = true;
    _canProcess = false;

    final msg = 'Correct eye covered. Proceeding.';
    _tts.speak(msg);

    Future.delayed(const Duration(milliseconds: 800)).then((_) {
      if (!_navigated && mounted) {
        _navigated = true;
        // Call the callback with the eye to test
        // widget.onCoverConfirmed(_eyeToTest);
        Navigator.of(context).pushReplacement(
           MaterialPageRoute(
            builder: (_) => MeasureAcuity(eyeToTest: _eyeToTest,leftEyeScore: widget.leftEyeScore,   // TRUYỀN QUA TIẾP
     ),
            
           ),
        );
      }
    });
  }

  // Tách hàm nói cảnh báo cho gọn
  Future<void> _speakWarning(String text) async {
    final now = DateTime.now();
    if (_lastAnnouncement != text || _lastAnnounceAt == null || now.difference(_lastAnnounceAt!).inSeconds > 3) {
      _lastAnnouncement = text;
      _lastAnnounceAt = now;
      await _tts.speak(text);
    }
  }

  void _startNoDetectionTimer() {
    _noDetectionTimer?.cancel();
    _noDetectionTimer = Timer(const Duration(seconds: _noDetectionWaitSeconds), () {
      if (!_hasShownWarning && !_detectedCorrectCover && mounted) {
        _hasShownWarning = true;
        _tts.speak(
          'I haven\'t seen you covering your eye yet. Please try again by Remove your hand and bring it from below up to your eye.'
        );
      }
    });
  }
}
