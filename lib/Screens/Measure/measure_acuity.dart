import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_application_1/Screens/ShowScore/show_score.dart';
import 'package:flutter_application_1/SnellenChart/snellen_chart_widget.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_application_1/services/classifier.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../vision_detector_views/detector_view.dart';

class MeasureAcuity extends StatefulWidget {
  final String eyeToTest; // 'left' or 'right' - the eye being tested (uncovered)
  final int leftEyeScore;

  const MeasureAcuity({
    Key? key,
    required this.eyeToTest,
    required this.leftEyeScore,
    
  }) : super(key: key);

  @override
  State<MeasureAcuity> createState() => _MeasureAcuityState();
}

enum TestStage {
  eyeCoverCheck,
  testing,
  switching,
  completed
}

class _MeasureAcuityState extends State<MeasureAcuity> {
  // Test state
  TestStage _currentStage = TestStage.testing;
  var _text = '', _snellenLetter = '';
  int _correctRead = 0;
  // ignore: unused_field
  int _incorrectRead = 0;
  int _rowCount = 0;
  var _isTryAgain = false, _coverLeftEye = false, _testingRightEye = false;
  var _leftEyeScore = 0, _rightEyeScore = 0;
  int _lastSuccessfulSize = 200; // Track the last size where user read correctly
  
  // Eye coverage monitoring
  late PoseDetector _poseDetector;
  bool _poseDetectorInitialized = false;
  bool _canProcessEyeCover = true;
  bool _isBusyEyeCover = false;
  bool _eyeCovered = true; // Assume eye is covered initially
  bool _showEyeCoverWarning = false;
  bool _faceTooClose = false; // Face proximity warning flag
  int _faceTooCloseFrames = 0;
  int _faceSafeFrames = 0;
  static const double _faceTooCloseEyeRatio = 0.014; // eye-eye distance / diag threshold
  static const int _faceTooCloseTriggerFrames = 5; // debounce to avoid flicker
  static const int _faceSafeTriggerFrames = 6; // frames to clear warning
  // Throttle pose processing to avoid overloading the device 
  DateTime? _lastPoseProcessedAt;
  static const int _poseProcessIntervalMs = 200;
  Timer? _eyeCoverWarningTimer;
  static const double _distanceThresholdRatio =0.012;
  static const int _requiredFramesForWarning = 7; 
  int _uncoveredFrameCount = 0;
  
  // Pre-test eye cover verification (from cover_eye_instruction.dart)
  static const int _requiredConsecutiveFrames = 5; // Required frames for successful pre-test verification
  static const int _maxMissedFramesAllowed = 20; // Glitch protection - allow missed frames
  static const int _guidanceCooldownMs = 1000; // 1 second cooldown between guidance messages
  
  int _preTestConsecutiveFrames = 0; // Consecutive frames with correct eye covered
  int _consecutiveFramesDetectedWrongEye = 0; // Consecutive frames with wrong eye covered
  int _missedFrames = 0; // Lost detection counter for glitch protection
  bool _confirmingCover = false; // Currently confirming cover
  bool _preTestVerificationComplete = false; // Pre-test verification done
  bool _isResumingAfterPause = false; // Track if we're resuming after test pause
  bool _isSpeakingProcess = false;
  // TTS cooldown tracking for warnings and guidance
  DateTime? _lastWarningAt;
  String? _lastWarningMessage;
  DateTime? _lastGuidanceAt;
  String? _lastGuidanceMessage;
  
  // Vision test parameters
  final Map<int, int> _snellenSizes = {
    200: 1, // 20/200 - show 5 optotypes
    100: 2, // 20/100
    70: 3,  // 20/70
    50: 4,  // 20/50
    40: 5,  // 20/40
    30: 6,
    25: 7,  // 20/30
    20: 8,  // 20/20
    15: 8,  // 20/15
    13: 8,  // 20/13
    10: 8,  // 20/10
  };
  int _currentSize = 200; // Start with 20/200

  // Speech recognition
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  bool _showListeningIndicator = false; // Visual cue for active listening
  // Buffer for partial speech results and silence timer to commit a sentence
  String _lastWords = '';
  Timer? _silenceTimer;
  Timer? _listeningIndicatorTimer; // Delay before showing listening banner


  // Project MobileBERT classifier instance
  Classifier? _classifier;
  // Text-to-speech
  FlutterTts? _flutterTts;
  // Pending confirmation state: when we detect a letter, ask user to confirm
  String? _pendingRecognizedLetter;
  bool _awaitingConfirmation = false;
  
  // Virtual nurse messages
  // ignore: unused_field
  String _nurseMessage = 'Please say the letter you see.';
  String _lastNurseMessage = 'Please say the letter you see on the screen.';
  
  // Screen brightness control
  double? _originalBrightness;
  final ScreenBrightness _screenBrightness = ScreenBrightness();

  // Simple debug logger that includes a tag, timestamp and some context
  void _debugLog(String tag, String message) {
    // final ts = DateTime.now().toIso8601String();
    // final stage = _currentStage.toString().split('.').last;
    // final pending = _pendingRecognizedLetter ?? '-';
    // final listening = _isListening ? 'listening' : 'idle';
    // print('DEBUG [$tag] [$ts] [stage=$stage] [pending=$pending] [mic=$listening] $message');
  }

  Future<void> _startListening() async {
    // 1. Nếu đang nghe thì dừng lại trước khi bắt đầu phiên mới (tránh crash)
    // if (_speech.isListening) {
    //   _debugLog('K VAO', '_speech.isListening');
    //   await _speech.stop();
    //   await Future.delayed(const Duration(milliseconds: 200));
    // }
    if (_isListening) {
      // print(' Stopping speech recognition in _startListening first');
      await _speech.stop();
      setState(() {
        _isListening = false;
        _showListeningIndicator = false;
      });
    }
    // _debugLog('_startListening', '-3');
    // 2. Reset trạng thái
    setState(() {
      _isListening = true;
      _showListeningIndicator = false; // will turn true after delay
      _text = '';
      _lastWords = '';
      _silenceTimer?.cancel(); // Hủy timer cũ nếu có
    });

    // Delay showing the listening banner to avoid flashing during transition
    

    try {
      await _speech.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 1200),
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      );

      _listeningIndicatorTimer?.cancel();
    _listeningIndicatorTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (_isListening) {
        setState(() => _showListeningIndicator = true);
      }
    });
    } catch (e) {
      
      // _debugLog('Speech', 'Error starting speech recognition: $e');
      if (mounted) {
        setState(() {
          _isListening = false;
          _showListeningIndicator = false;
        });
      }
      _listeningIndicatorTimer?.cancel();
    }
  }

  Future<void> _onSpeechResult(SpeechRecognitionResult result) async {
    // Update partial buffer and reset silence timer. If finalResult is true
    // commit immediately; otherwise commit after a short silence timeout.
    // final String recognized = result.recognizedWords;
    // Pick the highest-confidence alternative to avoid low-confidence phrasing
    final String recognized = (result.alternates.isNotEmpty)
        ? result.alternates.reduce(
            (a, b) => (a.confidence >= (b.confidence)) ? a : b,
          ).recognizedWords
        : result.recognizedWords;
    _silenceTimer?.cancel();

    setState(() {
      _lastWords = recognized;
      _text = _lastWords;
      // Keep _isListening as-is; we'll set it to false when we stop
      _listeningIndicatorTimer?.cancel();
    });

    // If platform signals finalResult, commit immediately
    if (result.finalResult) {
      _commitSentence(_lastWords.trim());
      return;
    }

    // Start/refresh silence timer; when it fires we'll commit the current buffer
    // Nếu người dùng dừng nói 3s thì tự động tắt STT
    _silenceTimer = Timer(const Duration(milliseconds: 1200), () {
      try {
      // _debugLog('_silenceTimer', 'Stopping speech recognition in _onSpeechResult');
      _speech.stop();
      Future.delayed(const Duration(milliseconds: 100));
      setState(() {
        _isListening = false;
        _showListeningIndicator = false;
      });
      _listeningIndicatorTimer?.cancel();
      
    } catch (_) {/* _debugLog('_onSpeechResult', 'Stopping speech recognition'); */}
  
    });
  }

  Future<void> _commitSentence(String sentence) async {
    // Stop active listening session (ignore errors)
    // _debugLog('_commitSentence', sentence);

    // Update UI to show committed sentence and mark not listening
    if (!mounted) return;
    setState(() {
      _text = sentence;
      _isListening = false;
      _showListeningIndicator = false;
      _lastWords = '';
      _silenceTimer?.cancel();
      _listeningIndicatorTimer?.cancel();
    });
    
    // Process the committed sentence using existing flow (confirmation/intent)
    await _handleFinalSpokenText(sentence.toLowerCase());
  }

  /// Unified final-spoken-text handler: routes the final committed sentence
  /// into the existing confirmation/intent flow.
  Future<void> _handleFinalSpokenText(String spokenText) async {

    if (_classifier != null) {
      final intent = await _classifyIntent(spokenText);
      // _debugLog("_classifyIntent", intent);
      if (_awaitingConfirmation) {
        final confirmation = intent;
        // Xử lý confirmation cho Cannot_See
        if (_pendingRecognizedLetter == 'CANNOT_SEE') {
          if (confirmation == 'Yes') {
            // Người dùng xác nhận không thấy → tính là trả lời sai
            _pendingRecognizedLetter = null;
            _awaitingConfirmation = false;
            _confirmLetter('');
          } else if (confirmation == 'No') {
            // Người dùng nói không → hỏi lại từ nào
            _pendingRecognizedLetter = null;
            _awaitingConfirmation = false;
            if (!mounted) return;
            await _speakThenListen('Then please tell me what letter you see on the screen', lang: 'en-US');
          } else {
            // Intent không rõ → hỏi lại
            _pendingRecognizedLetter = null;
            _awaitingConfirmation = false;
            if (!mounted) return;
            await _speakThenListen('I don\'t understand. Please answer with the letter displayed on the screen', lang: 'en-US');
          }
          return;
        }
        
        // Xử lý confirmation cho letter recognition
        if (confirmation == 'Yes') {
          final letter = _pendingRecognizedLetter ?? '';
          _pendingRecognizedLetter = null;
          _awaitingConfirmation = false;
          _confirmLetter(letter);
        } else {
          _pendingRecognizedLetter = null;
          _awaitingConfirmation = false;
          if (!mounted) return;
      
          await _speakThenListen('Okay so lets try again', lang: 'en-US');
        }
        return;
      }else{
        await _handleUserIntent(intent, spokenText);}
    } else {
      await _handleUserIntent('Irrelevant', spokenText);
    }
  }


  Future<String> _classifyIntent(String text) async {
    // Prefer using the project's `Classifier` (MobileBERT) if available.
    try {
      if (_classifier != null) {
        final prediction = await _classifier!.classify(text);

        if (prediction.isEmpty) return 'RecognizeLetter';

        final topLabel = prediction.keys.first;

        switch (topLabel) {
          case 'RecognizeLetter':
            return 'RecognizeLetter';
          case 'CannotSee':
            return 'Cannot_See';
          case 'Wait':
            return 'Wait';
          case 'Repeat':
            return 'Repeat';
          case 'Yes':
            return 'Yes';
          case 'No':
            return 'No';
          case 'Irrelevant':
            return 'Irrelevant';
          default:
            return 'Unknown';
        }
      }
    } catch (e) {
      // _debugLog('Classifier', 'Error classifying intent: $e');
    }

    // Fallback when Classifier isn't ready
    return 'RecognizeLetter';
  }

  Future<void> _handleUserIntent(String intent, String spokenText) async {
    switch (intent) {
      case 'RecognizeLetter':
        // Robustly extract what follows "the letter" and normalize it to a single
        // alphabetic character. Handles repeated letters ("aaa"), and common
        // homophones like "see" -> C.
        final lower = spokenText.toLowerCase();
        final match = RegExp(r'the letter\s+(.+)', caseSensitive: false).firstMatch(lower);

        if (match != null) {
          final after = match.group(1)!.trim();

          // Find first alphabetic token
          final tokenMatch = RegExp(r'([a-zA-Z]+)').firstMatch(after);
          if (tokenMatch != null) {
            final token = tokenMatch.group(1)!.toLowerCase();

            // If token is repeated same letter (e.g. "aaa" or "ccc")
              final repeatedLetter = RegExp(r'^([a-zA-Z])\1*').firstMatch(token);
            String? resolved;
            if (repeatedLetter != null) {
              resolved = repeatedLetter.group(1)!.toUpperCase();
            } else {
              const Map<String, String> homophoneMap = {
                'see': 'C', 'sea': 'C', 'cee': 'C', 'say': 'C',
                'bee': 'B', 'be': 'B',
                'you': 'U', 'u': 'U',
                'why': 'Y', 'y': 'Y',
                'eye': 'I', 'i': 'I',
                'jay': 'J', 'kay': 'K',
                'el': 'L', 'ell': 'L',
                'ar': 'R', 'are': 'R',
                'ess': 'S', 'es': 'S',
                'tee': 'T', 'tea': 'T',
                'dee': 'D',
                'oh': 'O', 'owe': 'O',
              };

              if (homophoneMap.containsKey(token)) {
                resolved = homophoneMap[token];
              } else if (token.length == 1 && RegExp(r'^[a-z]$').hasMatch(token)) {
                resolved = token.toUpperCase();
              }
            }
            // _debugLog(' "$resolved"', '-4');
            if (resolved != null && resolved.length == 1) {
              _pendingRecognizedLetter = resolved;
              _awaitingConfirmation = true;
              // Ask via TTS and then listen for confirmation
              // _debugLog('_speakThenListen', '-4');
              await _speakThenListen('Did you say "$resolved"?', lang: 'en-US');
            } else {
            
              await _speakThenListen('I did not catch a single letter Please say "the letter" followed by a single letter for example the letter A', lang: 'en-US');
            }
          } else {
            // setState(() {
            //   _nurseMessage = 'Please say "the letter" followed by the letter you see.';
            // });
            // _startListening();
            await _speakThenListen('Please say the letter followed by the letter you see', lang: 'en-US');
          }
        } else {
            await _speakThenListen('Please say the letter followed by the letter you see', lang: 'en-US');

        }
        break;

      case 'Cannot_See':
        // Xác nhận lại: "Did you say you cannot see?"
        _pendingRecognizedLetter = 'CANNOT_SEE'; // Mark as pending
        _awaitingConfirmation = true;
        await _speakThenListen('Did you say you cannot see?', lang: 'en-US');
        break;

      case 'Wait':  
        // _debugLog('_speakThenListen', '-4');
        await _speakThenListen('Okay Just say it when you ready ', lang: 'en-US');
        break;

      case 'Irrelevant':
        // setState(() {
        //   _nurseMessage = 'I didn\'t catch that. Please say something relate to the test.';
        // });
        // _startListening();
        await _speakThenListen('I did not catch that Please say something relate to the test.', lang: 'en-US');
        break;

      case 'Repeat':
        // Repeat the last nurse message
        await _speakThenListen('i said ,$_lastNurseMessage', lang: 'en-US', saveAsLastMessage: false);
        break;

      default:
        await _speakThenListen('I don\'t understand. Please answer with the letter displayed on the screen', lang: 'en-US');
        break;
    }
  }

  void _confirmLetter(String recognizedLetter) {
    final isCorrect = recognizedLetter == _snellenLetter;
    
    setState(() {
      if (isCorrect) {
        _correctRead++;
        _rowCount++;
        
      } else {
        _incorrectRead++;
        _rowCount++;
      }
    });

    final currentRowSize = _snellenSizes[_currentSize] ?? 5;
    
    if (isCorrect) {
      // Nếu trả lời đúng
      if (_correctRead > currentRowSize / 2) {
        // Đã đúng > 50% dòng → qua dòng tiếp theo
        _speakThenListen(
          'Let\'s move on to the next row and say the letter on the screen',
          lang: 'en-US',
        ).then((_) => _moveToNextSize());
      } else {
        // Chưa đúng > 50% → hiện chữ tiếp theo
        _speakThenListen(
          'How about this one ?',
          lang: 'en-US',
        ).then((_) => _showNextLetter());
      }
    } else {
      // Nếu trả lời sai
      if (_incorrectRead >= currentRowSize / 2) {
        // Đã sai ≥ 50% → kết thúc mắt này
         _endTest();
      } else {
        // Chưa sai ≥ 50% → hiện chữ tiếp theo
        if (_rowCount < currentRowSize) {
           _speakThenListen('Let\'s try another one and tell me what letter do you see', lang: 'en-US');
          _showNextLetter();
        } else {
          _endTest();
        }
      }
    }
  }

  void _showNextLetter() {
    setState(() {
      _snellenLetter = _getSnellenLetter(1);
    });
   
  }

  void _moveToNextSize() {
    
    final sizes = _snellenSizes.keys.toList()..sort((b, a) => a.compareTo(b));
    
    final currentIndex = sizes.indexOf(_currentSize);
    
    setState(() {
      _lastSuccessfulSize = _currentSize; // Save current size as the last successful one
      _snellenLetter = '';
      _correctRead = 0;
      _incorrectRead = 0;
      _rowCount = 0;
      
      // Kiểm tra xem còn size nhỏ hơn ở phía sau không
      if (currentIndex < sizes.length - 1) {
        _currentSize = sizes[currentIndex + 1]; // Lấy size tiếp theo (ví dụ 200 -> 100)
        
        _showNextLetter();
        // _debugLog('Snellen', 'Advance to size $_currentSize');
      } else {
        // Đã hết các size để test (đã đến size nhỏ nhất 20/10)
        _endTest();
      }
    });
  }

  Future<void> _saveTestResults() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('vision_tests').add({
          'userId': user.uid,
          'timestamp': FieldValue.serverTimestamp(),
          'leftEyeScore': _leftEyeScore,
          'rightEyeScore': _rightEyeScore,
          'testDate': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      // _debugLog('Firestore', 'Error saving test results: $e');
    }
  }

  void _endTest() async {
    if (!mounted) return;

    // Stop listening and speak
    if (_isListening) {
      await _speech.stop();
      setState(() {
        _isListening = false;
        _showListeningIndicator = false;
      });
      _listeningIndicatorTimer?.cancel();
    }

    // Store the current score
    if (_testingRightEye) {
       await _speak('That\'s another wrong answer for this row and that\'s the end of the eye test. You can see both eye scores on the screen', lang: 'en-US');
      // Finished testing right eye, save and show results
      _rightEyeScore = _lastSuccessfulSize ~/ 2; // Use last successful size
      // _debugLog('Test', 'End right eye score=$_rightEyeScore lastSize=$_lastSuccessfulSize');
      
      // Save results to Firestore
      await _saveTestResults(); 
      if (!mounted) return;
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ShowScore(
            rightEyeScore: _rightEyeScore,
            leftEyeScore: _leftEyeScore,
          ),
        ),
      );
    } else {
       await _speak('That\'s another wrong answer for this row and that\'s the end of the test for this eye, please cover your left eye', lang: 'en-US');
      // Finished testing left eye, now prepare for right eye inline (no navigation)
      _leftEyeScore = _lastSuccessfulSize ~/ 2; // Use last successful size
      // _debugLog('Test', 'Switching to right eye, left score=$_leftEyeScore lastSize=$_lastSuccessfulSize');

      if (!mounted) return;

      // Reset state for right-eye test and re-enter in-page eye-cover check
      setState(() {
        _testingRightEye = true;
        _currentStage = TestStage.eyeCoverCheck;
        _preTestVerificationComplete = false;
        _preTestConsecutiveFrames = 0;
        _consecutiveFramesDetectedWrongEye = 0;
        _missedFrames = 0;
        _confirmingCover = false;
        _isResumingAfterPause = false;
        _canProcessEyeCover = true;
        _eyeCovered = true;
        _showEyeCoverWarning = false;
        _faceTooClose = false;
        _uncoveredFrameCount = 0;

        _currentSize = 200;
        _lastSuccessfulSize = 200;
        _snellenLetter = '';
        _correctRead = 0;
        _incorrectRead = 0;
        _rowCount = 0;
        _text = '';
        _pendingRecognizedLetter = null;
        _awaitingConfirmation = false;

        _lastGuidanceAt = null;
        _lastGuidanceMessage = null;
        _lastWarningAt = null;
        _lastWarningMessage = null;
      });

      // Kick off the in-page pre-test cover check for the left eye (to test right eye)
      await _speak('I will check that you have covered the left eye.', lang: 'en-US');
    }
  }

  String _getSnellenLetter(int length) {
    const _chars = 'EFPTOZLDC';
    math.Random random = math.Random();

    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => _chars.codeUnitAt(
          random.nextInt(_chars.length),
        ),
      ),
    );
  }

  Future<void> _initializeSpeech() async {
    await _speech.initialize(
      onError: (error) => null, // _debugLog('Speech', 'recognition error: $error'),
      onStatus: (status) => null, // _debugLog('Speech', 'recognition status: $status'),
    );
  }

  Future<void> _speakThenListen(String text, {String? lang = 'en-US', bool saveAsLastMessage = true}) async {
    if (!mounted) return;
    if (_isSpeakingProcess) {
        await _flutterTts?.stop();
        await Future.delayed(const Duration(milliseconds: 600));
    }
    _isSpeakingProcess = true;
    if (_isListening) {
      // _debugLog('no vo. top luc did you say ', 'speak erro');
      await _speech.stop();
      setState(() {
        _isListening = false;
        _showListeningIndicator = false;
      });
      _listeningIndicatorTimer?.cancel();
      await Future.delayed(const Duration(milliseconds: 600));
    }
    setState(() {
      if (saveAsLastMessage) {
        _lastNurseMessage = _nurseMessage;
      }
      _nurseMessage = text;
    });
    
    try {
      _flutterTts ??= FlutterTts();
      if (lang != null) await _flutterTts!.setLanguage(lang);
      await _flutterTts!.setSpeechRate(0.53);
      await _flutterTts!.setVolume(1.0);
      await _flutterTts!.setPitch(1.0);
      await _flutterTts!.awaitSpeakCompletion(true);
      await Future.delayed(const Duration(milliseconds: 100));
      // print('vo 1_speakThenListen ne');
      await _flutterTts!
          .speak(text)
          .timeout(const Duration(seconds: 3), onTimeout: () {
        // _debugLog('TTS', 'speakThenListen timeout, continuing');
      });
      // print('vo 2_speakThenListen ne');
      await Future.delayed(const Duration(milliseconds: 250));
      // Đợi cho đến khi TTS hoàn thành nói
      
    } catch (e) {
      // _debugLog('TTS', 'speak error: $e');
    }

    // Pause thêm để đảm bảo mic ổn định trước khi bắt đầu listening
    // await Future.delayed(const Duration(milliseconds: 50));
    
    // _debugLog('_speakThenListen', '-2');
    
    // Chỉ bắt đầu nghe khi chắc chắn đã yên lặng
    if (mounted) {
       _startListening();
    }
  }

  Future<void> _speak(String text, {String? lang = 'en-US', bool saveAsLastMessage = true}) async {
    if (!mounted) return;
    if (_isSpeakingProcess) {
        await _flutterTts?.stop();
        await Future.delayed(const Duration(milliseconds: 500));
    }
    _isSpeakingProcess = true;
    if (_isListening) {
      await _speech.stop();
      setState(() {
        _isListening = false;
        _showListeningIndicator = false;
      });
      _listeningIndicatorTimer?.cancel();
      await Future.delayed(const Duration(milliseconds: 600));
    }
    setState(() {
      if (saveAsLastMessage) {
        _lastNurseMessage = _nurseMessage;
      }
      _nurseMessage = text;
    });
    
    try {
      _flutterTts ??= FlutterTts();
      if (lang != null) await _flutterTts!.setLanguage(lang);
      await _flutterTts!.setSpeechRate(0.53);
      await _flutterTts!.setVolume(1.0);
      await _flutterTts!.setPitch(1.0);
      await _flutterTts!.awaitSpeakCompletion(true);
      await Future.delayed(const Duration(milliseconds: 100));
      // await Future.delayed(const Duration(milliseconds: 100));
      // print('vo 1_speak ne');
      await _flutterTts!
          .speak(text)
          .timeout(const Duration(seconds: 3), onTimeout: () {
        // _debugLog('TTS', 'speakThenListen timeout, continuing');
      });
      // print('vo 2_speak  ne');
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      // _debugLog('TTS', 'speak error: $e');
    }

  }

  /// Speak warning with cooldown (from cover_eye_instruction.dart)
  Future<void> _speakWarning(String text) async {
    if (_isSpeakingProcess) {
        await _flutterTts?.stop();
    }
    _isSpeakingProcess = true;
    final now = DateTime.now();
    if (_lastWarningMessage != text || 
        _lastWarningAt == null || 
        now.difference(_lastWarningAt!).inSeconds > 3) {
      _lastWarningMessage = text;
      _lastWarningAt = now;
      try {
        _flutterTts ??= FlutterTts();
        await _flutterTts!.setSpeechRate(0.52);
         await _flutterTts!
          .speak(text)
          .timeout(const Duration(seconds: 3), onTimeout: () {
        // _debugLog('TTS', 'speakThenListen timeout, continuing');
      });
        // await _flutterTts!.speak(text);
      } catch (e) {
        // _debugLog('TTS', 'warning speak error: $e');
      }
    }
  }

  /// Provides directional guidance to move the user's hand to the correct eye position.
  /// Analyzes the vector between wrist and target eye to determine guidance direction.
  /// (Adapted from cover_eye_instruction.dart)
  Future<void> _provideHandGuidance(PoseLandmark wrist, PoseLandmark targetEye) async {
    final now = DateTime.now();
    
    // Check cooldown: only speak guidance every 1 second
    if (_lastGuidanceAt != null && now.difference(_lastGuidanceAt!).inMilliseconds < _guidanceCooldownMs) {
      return;
    }

    // Calculate the vector from wrist to target eye
    double deltaX = targetEye.x - wrist.x;
    double deltaY = targetEye.y - wrist.y;
    double distance = math.sqrt(deltaX * deltaX + deltaY * deltaY);

    // Determine which guidance to provide
    String? guidance;

    // If hand is too far, prompt to move closer
    if (distance > 100) {
      guidance = 'Move your hand closer to your eye.';
    } else {
      // Normalize deltas relative to distance to determine dominant direction
      double normalizedDeltaX = deltaX / distance;
      double normalizedDeltaY = deltaY / distance;

      // Determine which axis has more significant deviation
      double absDeltaX = normalizedDeltaX.abs();
      double absDeltaY = normalizedDeltaY.abs();

      // Direction threshold: if deviation is significant enough, provide directional guidance
      const double directionThreshold = 0.1;

      if (absDeltaY > absDeltaX) {
        // Vertical adjustment is more significant
        if (normalizedDeltaY > directionThreshold) {
          guidance = 'Move your hand straight down slowly.';
        } else if (normalizedDeltaY < -directionThreshold) {
          guidance = 'Move your hand straight up slowly.';
        } else {
          guidance = 'Move your hand closer to your eye.';
        }
      } else if (absDeltaX > absDeltaY) {
        // Horizontal adjustment is more significant
        if (normalizedDeltaX > directionThreshold) {
          guidance = 'Move your hand straight to the right slowly.';
        } else if (normalizedDeltaX < -directionThreshold) {
          guidance = 'Move your hand straight to the left slowly.';
        } else {
          guidance = 'Move your hand closer to your eye.';
        }
      } else {
        // Both axes are roughly equal, just move closer
        guidance = 'Move your hand closer to your eye.';
      }
    }

    // Only speak if the guidance is different from the last message
    if (guidance != _lastGuidanceMessage) {
      _lastGuidanceMessage = guidance;
      _lastGuidanceAt = now;
      try {
        _flutterTts ??= FlutterTts();
        await _flutterTts!.setSpeechRate(0.52);
        await _flutterTts!.speak(guidance);
      } catch (e) {
        // _debugLog('TTS', 'guidance speak error: $e');
      }
    }
  }

  /// Handle successful pre-test eye cover verification
  void _handleEyeCoverSuccess() {
    if (!mounted) return;
    
    _preTestVerificationComplete = true;
    _canProcessEyeCover = false; // Temporarily stop processing
    // _debugLog('PreTest', 'Success -> testing stage');
    
    _speak('Correct eye covered. Proceeding to test.', lang: 'en-US').then((_) {
      if (!mounted) return;
      
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        
        setState(() {
          _currentStage = TestStage.testing;
          _canProcessEyeCover = true; // Re-enable for during-test monitoring
          _eyeCovered = true;
          _uncoveredFrameCount = 0;
        });
        
        _speakThenListen('Please read the letter you see on the screen.', lang: 'en-US');
        _showNextLetter();
      });
    });
  }

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _setBrightness();
    // Determine which eye we're testing based on the parameter
    _testingRightEye = widget.eyeToTest == 'right';
    _setupTestEnvironment();
  }
  
  Future<void> _setBrightness() async {
    try {
      // Save original brightness
      _originalBrightness = await _screenBrightness.current;
      // Set to 70%
      await _screenBrightness.setScreenBrightness(0.7);
    } catch (e) {
      // Failed to set brightness, ignore
    }
  }
  Future<void> _setupTestEnvironment() async {
    // Initialize eye coverage monitoring
    _initializePoseDetector();
    
    await _initializeSpeech();
    
    try {
      _classifier = Classifier();
      await _classifier!.loadModel();
    } catch (e) {
      // _debugLog('Classifier', 'initialization error: $e');
    }
    
    try {
      _flutterTts = FlutterTts();
      await _flutterTts!.setLanguage('en-US');
      await _flutterTts!.setSpeechRate(0.53);
      await _flutterTts!.setVolume(1.0);
      await _flutterTts!.setPitch(1.0);
      await _flutterTts!.awaitSpeakCompletion(true);
    } catch (e) {
      // _debugLog('TTS', 'init error: $e');
    }

    if (mounted) {
      // Start with eye cover verification instead of directly testing
      setState(() {
        _currentStage = TestStage.eyeCoverCheck;
        _preTestVerificationComplete = false;
        _preTestConsecutiveFrames = 0;
        _consecutiveFramesDetectedWrongEye = 0;
        _missedFrames = 0;
        _confirmingCover = false;
      });
      
      // Determine which eye to cover based on which eye is being tested
      final eyeToCover = _testingRightEye ? 'left' : 'right';
      await _speak('I will check that you have covered the $eyeToCover eye.', lang: 'en-US');
    }
  }
  @override
  void dispose() {
    _classifier?.close();
    _flutterTts?.stop();
    _canProcessEyeCover = false;
    _eyeCoverWarningTimer?.cancel();
    _listeningIndicatorTimer?.cancel();
    if (_poseDetectorInitialized) {
      _poseDetector.close();
    }
    WakelockPlus.disable();
    _restoreBrightness();
    super.dispose();
  }
  
  Future<void> _restoreBrightness() async {
    try {
      if (_originalBrightness != null) {
        await _screenBrightness.setScreenBrightness(_originalBrightness!);
      } else {
        // Reset to system brightness
        await _screenBrightness.resetScreenBrightness();
      }
    } catch (e) {
      // Failed to restore brightness, ignore
    }
  }

  void _initializePoseDetector() {
    if (!_poseDetectorInitialized) {
      _poseDetector = PoseDetector(options: PoseDetectorOptions());
      _poseDetectorInitialized = true;
      // _debugLog('Pose', 'Pose detector initialized');
    }
  }

  Future<void> _processEyeCoverImage(InputImage inputImage) async {
    if (!_poseDetectorInitialized) {
      // _debugLog('Pose', 'Skip frame: detector not initialized');
      return;
    }
    if (!_canProcessEyeCover) {
      // _debugLog('Pose', 'Skip frame: _canProcessEyeCover=false stage=$_currentStage');
      return;
    }

    // Throttle processing: skip if too soon since last processed frame
    final now = DateTime.now();
    if (_lastPoseProcessedAt != null &&
        now.difference(_lastPoseProcessedAt!).inMilliseconds < _poseProcessIntervalMs) {
      return;
    }

    // if (!_canProcessEyeCover || _isBusyEyeCover || !_poseDetectorInitialized) return;
    if (_isBusyEyeCover) {
      // _debugLog('Pose', 'Skip frame: detector busy');
      return;
    }
    // _debugLog('Pose', 'Processing frame stage=$_currentStage testingRight=$_testingRightEye');
    _isBusyEyeCover = true;
    _lastPoseProcessedAt = now;

    try {
      final poses = await _poseDetector.processImage(inputImage);
      // _debugLog('Pose', 'Poses detected=${poses.length}');
      final imageSize = inputImage.metadata?.size ?? const Size(480, 360);
      final diag = math.sqrt(imageSize.width * imageSize.width + imageSize.height * imageSize.height);
      final threshold = diag * _distanceThresholdRatio;
      final guidanceZone = diag * 0.04; // Larger zone for hand guidance

      bool isCoveringAnyEye = false;
      String? coveredEyeSide;
      
      // Track if we should provide guidance and which wrist is near the target eye
      bool shouldProvideGuidance = false;
      PoseLandmark? guidanceWrist;
      PoseLandmark? targetEyeForGuidance;
      
      // Determine which eye should be covered based on which eye is being tested
      // If testing right eye, left eye should be covered
      final eyeToCover = _testingRightEye ? 'left' : 'right';
      final expectedCameraEye = _testingRightEye ? 'RIGHT' : 'LEFT'; // Reversed for camera

      for (final pose in poses) {
        final leftEye = pose.landmarks[PoseLandmarkType.leftEye];
        final rightEye = pose.landmarks[PoseLandmarkType.rightEye];
        final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
        final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
        
        if (leftEye == null || rightEye == null) continue;

        double dist(PoseLandmark a, PoseLandmark b) =>
            math.sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y));

        // --- Face proximity detection (applies to both pre-test and during-test) ---
        final eyeDist = dist(leftEye, rightEye);
        final eyeRatio = eyeDist / diag;
        final zAvg = (leftEye.z + rightEye.z) / 2.0;
        final bool tooCloseByRatio = eyeRatio >= _faceTooCloseEyeRatio;
        // ML Kit z is device-dependent; keep it as a secondary hint only when clearly close
        final bool tooCloseByZ = zAvg < -300; // negative z tends to mean closer on many devices
        final bool isTooCloseNow = tooCloseByRatio || tooCloseByZ;

        // _debugLog('FaceDist', 'eyeRatio=${eyeRatio.toStringAsFixed(3)} diag=$diag zAvg=${zAvg.toStringAsFixed(1)} ratioThr=$_faceTooCloseEyeRatio zThr=-20 tooClose=$isTooCloseNow');

        if (isTooCloseNow) {
          _faceTooCloseFrames++;
          _faceSafeFrames = 0;
          // _debugLog('FaceDist', 'tooCloseFrames=$_faceTooCloseFrames safeFrames=$_faceSafeFrames');
          if (!_faceTooClose && _faceTooCloseFrames >= _faceTooCloseTriggerFrames) {
            await _handleFaceTooClose(eyeToCover);
          }
        } else {
          _faceSafeFrames++;
          _faceTooCloseFrames = 0;
          // _debugLog('FaceDist', 'tooCloseFrames=$_faceTooCloseFrames safeFrames=$_faceSafeFrames');
          if (_faceTooClose && _faceSafeFrames >= _faceSafeTriggerFrames) {
            await _handleFaceSafe();
          }
        }

        // Determine target eye based on eyeToCover setting (reversed for camera)
        final targetEye = (eyeToCover == 'left') ? rightEye : leftEye;

        // Check left wrist
        if (leftWrist != null) {
          double dL = dist(leftWrist, leftEye);
          double dR = dist(leftWrist, rightEye);
          if (dL < threshold) { isCoveringAnyEye = true; coveredEyeSide = 'LEFT'; }
          else if (dR < threshold) { isCoveringAnyEye = true; coveredEyeSide = 'RIGHT'; }
          
          // Check if in guidance zone for target eye (only during pre-test)
          if (_currentStage == TestStage.eyeCoverCheck) {
            double distToTarget = dist(leftWrist, targetEye);
            if (distToTarget < guidanceZone && distToTarget >= threshold && !_preTestVerificationComplete) {
              shouldProvideGuidance = true;
              guidanceWrist = leftWrist;
              targetEyeForGuidance = targetEye;
            }
          }
        }

        // Check right wrist (if not already found)
        if (!isCoveringAnyEye && rightWrist != null) {
          double dL = dist(rightWrist, leftEye);
          double dR = dist(rightWrist, rightEye);
          if (dL < threshold) { isCoveringAnyEye = true; coveredEyeSide = 'LEFT'; }
          else if (dR < threshold) { isCoveringAnyEye = true; coveredEyeSide = 'RIGHT'; }
          
          // Check if in guidance zone for target eye (only during pre-test)
          if (_currentStage == TestStage.eyeCoverCheck) {
            double distToTarget = dist(rightWrist, targetEye);
            if (distToTarget < guidanceZone && distToTarget >= threshold && !_preTestVerificationComplete) {
              shouldProvideGuidance = true;
              guidanceWrist = rightWrist;
              targetEyeForGuidance = targetEye;
            }
          }
        }
      }

      // Handle based on current stage
      if (_currentStage == TestStage.eyeCoverCheck) {
        // PRE-TEST VERIFICATION LOGIC
        await _handlePreTestEyeCover(
          isCoveringAnyEye: isCoveringAnyEye,
          coveredEyeSide: coveredEyeSide,
          expectedCameraEye: expectedCameraEye,
          eyeToCover: eyeToCover,
          shouldProvideGuidance: shouldProvideGuidance,
          guidanceWrist: guidanceWrist,
          targetEyeForGuidance: targetEyeForGuidance,
        );
      } else if (_currentStage == TestStage.testing) {
        // DURING-TEST MONITORING LOGIC
        await _handleDuringTestEyeCover(
          isCoveringAnyEye: isCoveringAnyEye,
          coveredEyeSide: coveredEyeSide,
          expectedCameraEye: expectedCameraEye,
          eyeToCover: eyeToCover,
        );
      }
    } catch (e) {
      // _debugLog('EyeCover', 'Error processing eye coverage: $e');
    }

    _isBusyEyeCover = false;
    if (mounted) setState(() {});
  }

  /// Handle pre-test eye cover verification with full logic from cover_eye_instruction.dart
  Future<void> _handlePreTestEyeCover({
    required bool isCoveringAnyEye,
    required String? coveredEyeSide,
    required String expectedCameraEye,
    required String eyeToCover,
    required bool shouldProvideGuidance,
    required PoseLandmark? guidanceWrist,
    required PoseLandmark? targetEyeForGuidance,
  }) async {
    // _debugLog('PreTest', 'covering=$isCoveringAnyEye coveredEye=$coveredEyeSide expected=$expectedCameraEye frames=$_preTestConsecutiveFrames missed=$_missedFrames wrong=$_consecutiveFramesDetectedWrongEye');
    if (isCoveringAnyEye && coveredEyeSide != null) {
      // --- HAND DETECTED ---
      _missedFrames = 0; // Reset glitch protection counter
      
      if (coveredEyeSide == expectedCameraEye) {
        // A. CORRECT EYE COVERED
        _preTestConsecutiveFrames++;
        _consecutiveFramesDetectedWrongEye = 0;
        
        // Speak confirmation message once when starting confirmation
        if (!_confirmingCover && !_preTestVerificationComplete) {
          _confirmingCover = true;
          final msg = 'Please keep your $eyeToCover eye covered.';
          _speakWarning(msg);
          _lastGuidanceAt = null; // Reset guidance cooldown
        }
        
        // Check for success
        if (_preTestConsecutiveFrames >= _requiredConsecutiveFrames && !_preTestVerificationComplete && mounted) {
          if (_isResumingAfterPause) {
            _handleEyeCoverResumeSuccess();
          } else {
            _handleEyeCoverSuccess();
          }
        }
      } else {
        // B. WRONG EYE COVERED
        _lastGuidanceAt = null;
        _consecutiveFramesDetectedWrongEye++;
        
        if (_consecutiveFramesDetectedWrongEye >= 20) {
          _confirmingCover = false;
          _preTestConsecutiveFrames = 0;
          _consecutiveFramesDetectedWrongEye = 0;
          
          final wrongEyeName = coveredEyeSide == 'LEFT' ? 'right' : 'left';
          final announcement = 'You are covering your $wrongEyeName eye. Please cover your $eyeToCover eye.';
          _speakWarning(announcement);
        }
      }
    } else {
      // --- NO HAND DETECTED (or glitch) ---
      if (!_preTestVerificationComplete) {
        _missedFrames++;
        
        // Only reset if lost detection for too long (glitch protection)
        if (_missedFrames > _maxMissedFramesAllowed) {
          _preTestConsecutiveFrames = 0;
          _confirmingCover = false;
          _lastGuidanceAt = null;
        }
      }
      
      // Provide guidance if hand is in guidance zone but not yet covering eye
      if (shouldProvideGuidance && guidanceWrist != null && targetEyeForGuidance != null && !_confirmingCover) {
        await _provideHandGuidance(guidanceWrist, targetEyeForGuidance);
      }
    }
  }

  /// Handle during-test eye cover monitoring (warning when eye becomes uncovered)
  Future<void> _handleDuringTestEyeCover({
    required bool isCoveringAnyEye,
    required String? coveredEyeSide,
    required String expectedCameraEye,
    required String eyeToCover,
  }) async {
    // _debugLog('DuringTest', 'covering=$isCoveringAnyEye coveredEye=$coveredEyeSide expected=$expectedCameraEye eyeCovered=$_eyeCovered frames=$_uncoveredFrameCount');
    if (isCoveringAnyEye && coveredEyeSide == expectedCameraEye) {
      // Correct eye is still covered
      _uncoveredFrameCount = 0;
      if (!_eyeCovered && mounted) {
        setState(() {
          _eyeCovered = true;
          _showEyeCoverWarning = false;
        });
        _eyeCoverWarningTimer?.cancel();
      }
    } else {
      // Eye not properly covered
      _uncoveredFrameCount++;
      if (_uncoveredFrameCount >= _requiredFramesForWarning && _eyeCovered) {
        // Pause test and go back to eye cover check
        await _pauseTestAndRecheckEyeCover(eyeToCover);
      }
    }
  }
  
  /// Pause the test and go back to eye cover verification
  Future<void> _pauseTestAndRecheckEyeCover(String eyeToCover) async {
    if (!mounted) return;
    // _debugLog('Pause', 'Pausing test to recheck cover for $eyeToCover');
    
    // Stop speech recognition
    if (_isListening || _speech.isListening) {
      // print('stopping listening due to eye uncover');
      
      await _speech.stop();
    }
    
    // Update state to pause test and show eye cover check UI
    setState(() {
      _eyeCovered = false;
      _showEyeCoverWarning = true;
      _isListening = false;
      _showListeningIndicator = false;
      _listeningIndicatorTimer?.cancel();
      
      // Reset pre-test verification state for re-check
      _currentStage = TestStage.eyeCoverCheck;
      _preTestVerificationComplete = false;
      _preTestConsecutiveFrames = 0;
      _consecutiveFramesDetectedWrongEye = 0;
      _missedFrames = 0;
      _confirmingCover = false;
      _uncoveredFrameCount = 0;
      _isResumingAfterPause = true; // Mark that we're resuming after pause
      
      // Keep _currentSize unchanged - we'll continue from here
      // Keep _snellenLetter - but we'll generate new one after re-verification
    });
    
    // Speak warning and instruction
    await _speak('Test paused. Please cover your $eyeToCover eye again to continue.', lang: 'en-US');
  }

  /// Pause flow because face is too close; applies in both stages.
  Future<void> _handleFaceTooClose(String eyeToCover) async {
    if (!mounted) return;
    _faceTooClose = true;
    // _debugLog('Face', 'Too close - pausing visuals');

    // Stop speech recognition while warning
    if (_isListening || _speech.isListening) {
      // print('stopping listening due _handleFaceTooClose');
      await _speech.stop();
      setState(() {
        _isListening = false;
        _showListeningIndicator = false;
      });
      _listeningIndicatorTimer?.cancel();
    }

    // Speak warning (debounced inside)
    await _speakWarning('Please keep your face further from the screen');

    // If we are currently testing, mirror the pause behavior: hide chart and stay in stage
    setState(() {
      _isBusyEyeCover = false;
      _showEyeCoverWarning = true; // reuse overlay flag to hide chart
      _eyeCovered = false; // hide chart rendering
    });
  }

  /// Resume flow after face distance is safe again.
  Future<void> _handleFaceSafe() async {
    if (!mounted) return;
    _faceTooClose = false;
    _faceTooCloseFrames = 0;
    _faceSafeFrames = 0;
    // _debugLog('Face', 'Safe distance restored');

    setState(() {
      _isBusyEyeCover = false;
      _eyeCovered = true;
      _showEyeCoverWarning = false;
    });

    // Resume listening if we were in testing stage
    if (_currentStage == TestStage.testing) {
      // Keep current size/letter, just prompt again
      _showNextLetter();
      await _speakThenListen('Please read the letter you see on the screen.', lang: 'en-US');
    }
  }
  
  /// Handle successful eye cover re-verification (after pause during test)
  void _handleEyeCoverResumeSuccess() {
    if (!mounted) return;
    
    _preTestVerificationComplete = true;
    _canProcessEyeCover = false; // Temporarily stop processing
    // _debugLog('PreTest', 'Resume success, returning to testing');
    
    _speak('Eye covered. Resuming test.', lang: 'en-US').then((_) {
      if (!mounted) return;
      
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        
        setState(() {
          _currentStage = TestStage.testing;
          _canProcessEyeCover = true; // Re-enable for during-test monitoring
          _eyeCovered = true;
          _showEyeCoverWarning = false;
          _uncoveredFrameCount = 0;
          _isResumingAfterPause = false; // Reset flag
          _awaitingConfirmation = false;
        });
        
        // Generate new letter with current size (don't reset size)
        _showNextLetter();
        _speakThenListen('Please read the letter you see on the screen.', lang: 'en-US');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use a single DetectorView for the entire widget lifecycle to avoid 
    // CameraController disposal issues when switching stages
    return Scaffold(
      body: Stack(
        children: [
          // Single persistent DetectorView - hidden but always active
          Opacity(
            opacity: 0,
            child: SizedBox(
              width: 1,
              height: 1,
              child: DetectorView(
                title: 'Eye coverage monitoring',
                onImage: _processEyeCoverImage,
                initialCameraLensDirection: CameraLensDirection.front,
              ),
            ),
          ),
          
          // Content overlay based on current stage
          if (_currentStage == TestStage.eyeCoverCheck)
            _buildEyeCoverCheckContent()
          else
            _buildTestingContent(),
        ],
      ),
    );
  }
  
  /// Build eye cover check content (without DetectorView - it's in parent)
  Widget _buildEyeCoverCheckContent() {
    final eyeToCover = _testingRightEye ? 'left' : 'right';
    final imagePath = eyeToCover == 'left' 
      ? 'assets/images/Lefteye.png' 
      : 'assets/images/righteye.png';
    
    final promptText = _confirmingCover
      ? 'Detected: $eyeToCover eye covered'
      : 'Detecting... Please cover your $eyeToCover eye';

    final faceTooCloseNotice = _faceTooClose
      ? 'Face too close — please move back'
      : null;

    return Padding(
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
              faceTooCloseNotice ?? promptText,
              style: const TextStyle(fontSize: 22),
            ),
            if (_confirmingCover)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Hold... ${(_preTestConsecutiveFrames * 100 / _requiredConsecutiveFrames).clamp(0, 100).toInt()}%',
                      style: const TextStyle(fontSize: 16, color: Colors.green),
                    ),
                  ],
                ),
              ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.03),
          ],
        ),
      ),
    );
  }
  
  /// Build testing content (without DetectorView - it's in parent)
  Widget _buildTestingContent() {
    return SafeArea(
      child: Column(
        children: [
          // Test info header
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.blue.withValues(alpha: 0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.remove_red_eye,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  'Testing ${_testingRightEye ? "Right" : "Left"} Eye',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Center the Snellen chart/warning in available space
                Expanded(
                  child: Center(
                    child: _eyeCovered && !_faceTooClose
                        ? SnellenChartWidget(
                            feet: _currentSize,
                            letterToDisplay: _snellenLetter,
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16.0),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  border: Border.all(color: Colors.red, width: 2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.warning,
                                      color: Colors.red,
                                      size: 48,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _faceTooClose
                                          ? 'Please move your face further from the screen'
                                          : 'Please keep your head and your ${_testingRightEye ? "left" : "right"} eye still',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            'Heard: $_text',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      // Listening banner styled like a status card and pinned to bottom
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _showListeningIndicator
                            ? Container(
                                key: const ValueKey('listening-banner'),
                                width: double.infinity,
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Text(
                                      'Listening now — please say the letter you see',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      'Microphone is on and waiting for your answer',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
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
