// import 'package:flutter_application_1/Screens/Measure/measure_acuity.dart';
// import 'package:flutter_application_1/Screens/Test/distance_check_screen.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_tts/flutter_tts.dart';
// import 'package:camera/camera.dart';
// import 'package:arkit_plugin/arkit_plugin.dart';
// import 'dart:math' as math;
// import 'dart:async';

// import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

// import '../../vision_detector_views/detector_view.dart';
// // vector_math not required here

// class RightEyeInstruction extends StatefulWidget {
//   final bool skipDistanceCheck;

//   const RightEyeInstruction({Key? key, this.skipDistanceCheck = false}) : super(key: key);

//   @override
//   State<RightEyeInstruction> createState() => _RightEyeInstructionState();
// }

// class _RightEyeInstructionState extends State<RightEyeInstruction> {
//   ARKitController? _arkitController;
//   final FlutterTts _tts = FlutterTts();
//   // Pose detection members (used when skipDistanceCheck is true)
//   final PoseDetector _poseDetector = PoseDetector(options: PoseDetectorOptions());
//   bool _canProcess = true;
//   bool _isBusy = false;
//   DateTime? _lastAnnounceAt;
//   String? _lastAnnouncement;
//   bool _detectedCorrectCover = false;
//   bool _navigated = false;
  
//   // Timer and state tracking
//   Timer? _noDetectionTimer;
//   Timer? _confirmCoverTimer;
//   bool _hasShownInitialPrompt = false;
//   bool _hasShownWarning = false;
//   bool _confirmingCover = false;
  
//   // Constants
//   static const double _distanceThresholdRatio = 0.011; //0.011 fraction of image diagonal
//   static const int _noDetectionWaitSeconds = 10;
//   static const int _confirmCoverSeconds = 3;


//   @override
//   void initState() {
//     super.initState();
//     _initTts().then((_) {
//       if (widget.skipDistanceCheck) {
//         // initial prompt
//         _tts.speak('Please cover your right eye. Cover your right eye with your hand. I will check that you have covered the right eye.');
//       }
//     });
//     // Coverage detection removed. When skipDistanceCheck is true the UI will
//     // present a Ready button that proceeds to the test.
//   }

//   Future<void> _initTts() async {
//     await _tts.setLanguage('en-US');
//     await _tts.setSpeechRate(0.45);
//   }

//   @override
//   void dispose() {
//     _arkitController?.dispose();
//     _tts.stop();
//     _canProcess = false;
//     _noDetectionTimer?.cancel();
//     _confirmCoverTimer?.cancel();
//     _poseDetector.close();
//     super.dispose();
//   }



  
  
//   @override
// Widget build(BuildContext context) {
//   return Scaffold(
//     body: Stack(
//       children: [
//         // Camera invisible (still processing frames)
//         if (widget.skipDistanceCheck)
//           Opacity(
//             opacity: 0,
//             child: DetectorView(
//               title: 'Right eye coverage',
              
//               onImage: _processImage,
//               initialCameraLensDirection: CameraLensDirection.front,
//             ),
//           ),

//         // FULL SCREEN IMAGE
        

//         // UI OVERLAY
//         Padding(
//           padding: const EdgeInsets.all(8.0),
//           child: Center(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               crossAxisAlignment: CrossAxisAlignment.center,
//               children: [
                
//                 SizedBox(height: MediaQuery.of(context).size.height * 0.03),
//                 Expanded(
//                   child: Image.asset(
//                     'assets/images/righteye.png',
//                     fit: BoxFit.cover,   // hoặc contain
//                   ),
//                 ),
//                 Text(
//                   widget.skipDistanceCheck
//                       ? (_detectedCorrectCover
//                           ? 'Detected: right eye covered'
//                           : 'Detecting... Please cover your right eye')
//                       : "Once done, press 'Ready'",
//                   style: const TextStyle(fontSize: 22),
//                 ),

//                 SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                
//                 if (!widget.skipDistanceCheck)
//                   ElevatedButton(
//                     onPressed: () {
//                       Navigator.of(context).pushReplacement(
//                         MaterialPageRoute(
//                           builder: (context) {
//                             return DistanceCheckScreen(
//                               skipDistanceCheck: false,
//                               onSuccess: () {
//                                 Navigator.of(context).pushReplacement(
//                                   MaterialPageRoute(builder: (_) => const MeasureAcuity()),
//                                 );
//                               },
//                             );
//                           },
//                         ),
//                       );
//                     },
//                     child: const Text(
//                       'Ready',
//                       style: TextStyle(fontSize: 22),
//                     ),
//                     style: ButtonStyle(
//                       elevation: WidgetStateProperty.all(5),
//                       shape: WidgetStateProperty.all(
//                         RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//         ),
//       ],
//     ),
//   );
// }


//   Future<void> _processImage(InputImage inputImage) async {
//     if (!_canProcess) return;
//     if (_isBusy) return;
//     _isBusy = true;

//     try {
//       final poses = await _poseDetector.processImage(inputImage);
//       final imageSize = inputImage.metadata?.size ?? Size(480, 360);
//       final diag = math.sqrt(imageSize.width * imageSize.width + imageSize.height * imageSize.height);
//       final threshold = diag * _distanceThresholdRatio;

//       bool anyClose = false;

//       for (final pose in poses) {
//         final leftEye = pose.landmarks[PoseLandmarkType.leftEye];
//         final rightEye = pose.landmarks[PoseLandmarkType.rightEye];
//         final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
//         final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

//         double dist(a, b) => math.sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y));

//         Future<void> checkWrist(PoseLandmark? wrist) async {
//           if (wrist == null) return;
//           if (leftEye == null || rightEye == null) return;
//           final dLeft = dist(wrist, leftEye);
//           final dRight = dist(wrist, rightEye);
//           final minD = dLeft < dRight ? dLeft : dRight;
          
//           if (minD < threshold) {
//             anyClose = true;
//             // Reset timer nếu phát hiện được hand covering eye
//             _noDetectionTimer?.cancel();
//             _hasShownWarning = false;
            
//             final eye = dLeft < dRight ? 'LEFT' : 'RIGHT';
//             if (eye == 'RIGHT') {
//               // correct eye - start confirmation timer
//               if (!_confirmingCover && !_detectedCorrectCover) {
//                 _confirmingCover = true;
//                 await _tts.speak('Please keep your right eye covered for 3 seconds.');
//                 _startConfirmCoverTimer();
//               }
//             } else {
//               // wrong eye
//               _confirmCoverTimer?.cancel();
//               _confirmingCover = false;
              
//               final announcement = 'You are covering your left eye. Please cover your right eye instead.';
//               final now = DateTime.now();
//               if (_lastAnnouncement != announcement || _lastAnnounceAt == null || now.difference(_lastAnnounceAt!).inSeconds > 3) {
//                 _lastAnnouncement = announcement;
//                 _lastAnnounceAt = now;
//                 await _tts.speak(announcement);
//               }
//             }
//           }
//         }

//         await checkWrist(leftWrist);
//         await checkWrist(rightWrist);
//       }

//       // Nếu không phát hiện được hand covering eye
//       if (!anyClose && !_detectedCorrectCover) {
//         // Reset confirmation timer nếu mất detection
//         if (_confirmingCover) {
//           _confirmCoverTimer?.cancel();
//           _confirmingCover = false;
//         }
        
//         // Nói lần đầu
//         if (!_hasShownInitialPrompt) {
//           _hasShownInitialPrompt = true;
//           await _tts.speak('Please cover your right eye.');
//           // Bắt đầu timer 10 giây
//           _startNoDetectionTimer();
//         }
//       }
//     } catch (e) {
//       // ignore
//     }

//     _isBusy = false;
//     if (mounted) setState(() {});
//   }

//   void _startNoDetectionTimer() {
//     _noDetectionTimer?.cancel();
//     _noDetectionTimer = Timer(const Duration(seconds: _noDetectionWaitSeconds), () {
//       if (!_hasShownWarning && !_detectedCorrectCover && mounted) {
//         _hasShownWarning = true;
//         _tts.speak(
//           'I haven\'t seen you covering your eye yet. Please try again. Remove your hand and bring it from below up to your eye.'
//         );
//       }
//     });
//   }

//   void _startConfirmCoverTimer() {
//     _confirmCoverTimer?.cancel();
//     _confirmCoverTimer = Timer(const Duration(seconds: _confirmCoverSeconds), () {
//       if (_confirmingCover && !_detectedCorrectCover && mounted) {
//         _detectedCorrectCover = true;
//         _canProcess = false;
//         _tts.speak('Right eye detected as covered. Proceeding to the visual acuity test.');
//         // small delay to let TTS start
//         Future.delayed(const Duration(milliseconds: 800)).then((_) {
//           if (!_navigated && mounted) {
//             _navigated = true;
//             Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MeasureAcuity()));
//           }
//         });
//       }
//     });
//   }
// }
