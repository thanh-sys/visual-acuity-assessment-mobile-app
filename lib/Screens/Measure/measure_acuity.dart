import 'dart:async';
import 'dart:math';
import 'package:flutter_application_1/Screens/ShowScore/show_score.dart';
import 'package:flutter_application_1/Screens/Instructions/cover_eye_instruction.dart';
import 'package:flutter_application_1/SnellenChart/snellen_chart_widget.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_application_1/services/classifier.dart'; 
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
  // Buffer for partial speech results and silence timer to commit a sentence
  String _lastWords = '';
  Timer? _silenceTimer;


  // Project MobileBERT classifier instance
  Classifier? _classifier;
  // Text-to-speech
  FlutterTts? _flutterTts;
  // Pending confirmation state: when we detect a letter, ask user to confirm
  String? _pendingRecognizedLetter;
  bool _awaitingConfirmation = false;
  
  // Virtual nurse messages
  String _nurseMessage = 'Please say the letter you see.';

  // Simple debug logger that includes a tag, timestamp and some context
  void _debugLog(String tag, String message) {
    final ts = DateTime.now().toIso8601String();
    final stage = _currentStage.toString().split('.').last;
    final pending = _pendingRecognizedLetter ?? '-';
    final listening = _isListening ? 'listening' : 'idle';
    print('DEBUG [$tag] [$ts] [stage=$stage] [pending=$pending] [mic=$listening] $message');
  }

  Future<void> _startListening() async {
    // 1. Nếu đang nghe thì dừng lại trước khi bắt đầu phiên mới (tránh crash)
    // if (_speech.isListening) {
    //   _debugLog('K VAO', '_speech.isListening');
    //   await _speech.stop();
    //   await Future.delayed(const Duration(milliseconds: 200));
    // }
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    }
    _debugLog('_startListening', '-3');
    // 2. Reset trạng thái
    setState(() {
      _isListening = true;
      _text = '';
      _lastWords = '';
      _silenceTimer?.cancel(); // Hủy timer cũ nếu có
    });

    try {
      await _speech.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 1200),
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      );
    } catch (e) {

      _debugLog('Speech', 'Error starting speech recognition: $e');
    }
  }

  Future<void> _onSpeechResult(SpeechRecognitionResult result) async {
    // Update partial buffer and reset silence timer. If finalResult is true
    // commit immediately; otherwise commit after a short silence timeout.
    final String recognized = result.recognizedWords;
    _silenceTimer?.cancel();

    setState(() {
      _lastWords = recognized;
      _text = _lastWords;
      // Keep _isListening as-is; we'll set it to false when we stop
    });

    // If platform signals finalResult, commit immediately
    if (result.finalResult) {
      _commitSentence(_lastWords.trim());
      return;
    }

    // Start/refresh silence timer; when it fires we'll commit the current buffer
    // Nếu người dùng dừng nói 3s thì tự động tắt STT
    _silenceTimer = Timer(const Duration(seconds: 2), () {
      try {
      _debugLog('_silenceTimer', 'Stopping speech recognition');
      _speech.stop();
      Future.delayed(const Duration(milliseconds: 10));
      setState(() => _isListening = false);
      
    } catch (_) {_debugLog('_onSpeechResult', 'Stopping speech recognition');}
  
    });
  }

  Future<void> _commitSentence(String sentence) async {
    // Stop active listening session (ignore errors)
    _debugLog('_commitSentence', sentence);

    // Update UI to show committed sentence and mark not listening
    if (!mounted) return;
    setState(() {
      _text = sentence;
      _isListening = false;
      _lastWords = '';
      _silenceTimer?.cancel();
    });
    
    // Process the committed sentence using existing flow (confirmation/intent)
    await _handleFinalSpokenText(sentence.toLowerCase());
  }

  /// Unified final-spoken-text handler: routes the final committed sentence
  /// into the existing confirmation/intent flow.
  Future<void> _handleFinalSpokenText(String spokenText) async {

    if (_classifier != null) {
      final intent = await _classifyIntent(spokenText);
      _debugLog("_classifyIntent", intent);
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
      _debugLog('Classifier', 'Error classifying intent: $e');
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
            _debugLog(' "$resolved"', '-4');
            if (resolved != null && resolved.length == 1) {
              _pendingRecognizedLetter = resolved;
              _awaitingConfirmation = true;
              // Ask via TTS and then listen for confirmation
              _debugLog('_speakThenListen', '-4');
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
        _debugLog('_speakThenListen', '-4');
        await _speakThenListen('Take your time and Just say it when you ready ', lang: 'en-US');
        break;

      case 'Irrelevant':
        // setState(() {
        //   _nurseMessage = 'I didn\'t catch that. Please say something relate to the test.';
        // });
        // _startListening();
        await _speakThenListen('I did not catch that Please say something relate to the test.', lang: 'en-US');
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
          'That\'s correct let\'s move on to the next row and say the letter you see on the screen',
          lang: 'en-US',
        ).then((_) => _moveToNextSize());
      } else {
        // Chưa đúng > 50% → hiện chữ tiếp theo
        _speakThenListen(
          'That\'s correct how about this one what letter do you see on the screen',
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
           _speakThenListen('That\'s one wrong answer for this row let\'s try another one and tell me what letter do you see', lang: 'en-US');
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
          'leftEyeScore': widget.leftEyeScore,
          'rightEyeScore': _rightEyeScore,
          'testDate': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      _debugLog('Firestore', 'Error saving test results: $e');
    }
  }

  void _endTest() async {
    if (!mounted) return;

    // Stop listening and speak
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    }

    // Store the current score
    if (_testingRightEye) {
       await _speak('That\'s another wrong answer for this row and that\'s the end of the eye test you can see both eye score on the screen', lang: 'en-US');
      // Finished testing right eye, save and show results
      _rightEyeScore = _lastSuccessfulSize ~/ 2; // Use last successful size
      
      // Save results to Firestore
      await _saveTestResults(); 
      if (!mounted) return;
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ShowScore(
            rightEyeScore: _rightEyeScore,
            leftEyeScore: widget.leftEyeScore,
          ),
        ),
      );
    } else {
       await _speak('That\'s another wrong answer for this row and that\'s the end of the test for this eye, please cover your left eye', lang: 'en-US');
      // Finished testing left eye, now prepare for right eye
      _leftEyeScore = _lastSuccessfulSize~/ 2; // Use last successful size
      
      // Reset for next eye
      _lastSuccessfulSize = 200;
      
      // Navigate to cover eye instruction for left eye (to test right eye)
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => CoverEyeInstruction(
            eyeToCover: 'left',
            leftEyeScore: _leftEyeScore,
            // onCoverConfirmed: _startTestingEye,
          ),
        ),
      );
    }
  }

  // Function to start testing a specific eye after cover confirmation
  // void _startTestingEye(String eyeToTest) {
  //   if (!mounted) return;
    
  //   setState(() {
  //     _testingRightEye = eyeToTest == 'right';
  //     _currentStage = TestStage.testing;
  //     _snellenLetter = '';
  //     _correctRead = 0;
  //     _incorrectRead = 0;
  //     _rowCount = 0;
  //     _currentSize = 200; // Reset to 20/200
  //     _lastSuccessfulSize = 200; // Reset tracking
  //   });

  //   _speakThenListen('Please read the letter you see on the screen.', lang: 'en-US');
  //   _showNextLetter();
  // }

  Widget _coverLeftEyeInstruction() {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Please cover your left eye.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                ),
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.03,
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.4,
                child: Image.asset(
                  'assets/images/Lefteye.png',
                  fit: BoxFit.fitHeight,
                ),
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.03,
              ),
              const Text(
                "Test will start in 10 seconds",
                style: TextStyle(
                  fontSize: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tryAgainWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Try Again',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
            ),
          ),
          const SizedBox(
            height: 15,
          ),
          Image.asset(
            'assets/images/try_again.png',
          ),
        ],
      ),
    );
  }

  String _getSnellenLetter(int length) {
    const _chars = 'EFPTOZLDC';
    Random random = Random();

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
      onError: (error) => _debugLog('Speech', 'recognition error: $error'),
      onStatus: (status) => _debugLog('Speech', 'recognition status: $status'),
    );
  }

  Future<void> _speakThenListen(String text, {String? lang = 'en-US'}) async {
    if (!mounted) return;

    if (_isListening) {
      _debugLog('no vo. top luc did you say ', 'speak erro');
      await _speech.stop();
      setState(() => _isListening = false);
    }
    setState(() {
      _nurseMessage = text;
    });
    
    try {
      _flutterTts ??= FlutterTts();
      if (lang != null) await _flutterTts!.setLanguage(lang);
      await _flutterTts!.setSpeechRate(0.5);
      await _flutterTts!.setVolume(1.0);
      await _flutterTts!.setPitch(1.0);
      await _flutterTts!.awaitSpeakCompletion(true);
      await Future.delayed(const Duration(milliseconds: 100));
      await _flutterTts!.speak(text);
      await Future.delayed(const Duration(milliseconds: 250));
      // Đợi cho đến khi TTS hoàn thành nói
      
    } catch (e) {
      _debugLog('TTS', 'speak error: $e');
    }

    // Pause thêm để đảm bảo mic ổn định trước khi bắt đầu listening
    // await Future.delayed(const Duration(milliseconds: 50));
    
    _debugLog('_speakThenListen', '-2');
    
    // Chỉ bắt đầu nghe khi chắc chắn đã yên lặng
    if (mounted) {
       _startListening();
    }
  }

  Future<void> _speak(String text, {String? lang = 'en-US'}) async {
    if (!mounted) return;

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    }
    setState(() {
      _nurseMessage = text;
    });
    
    try {
      _flutterTts ??= FlutterTts();
      if (lang != null) await _flutterTts!.setLanguage(lang);
      await _flutterTts!.setSpeechRate(0.5);
      await _flutterTts!.setVolume(1.0);
      await _flutterTts!.setPitch(1.0);
      await _flutterTts!.awaitSpeakCompletion(true);
      await Future.delayed(const Duration(milliseconds: 100));
      await _flutterTts!.speak(text);
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      _debugLog('TTS', 'speak error: $e');
    }

  }


  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    // Determine which eye we're testing based on the parameter
    _testingRightEye = widget.eyeToTest == 'right';
    _setupTestEnvironment();
  }
  Future<void> _setupTestEnvironment() async {
    await _initializeSpeech();
    
    try {
      _classifier = Classifier();
      await _classifier!.loadModel();
    } catch (e) {
      _debugLog('Classifier', 'initialization error: $e');
    }
    
    try {
      _flutterTts = FlutterTts();
      await _flutterTts!.setLanguage('en-US');
      await _flutterTts!.setSpeechRate(0.45);
      await _flutterTts!.setVolume(1.0);
      await _flutterTts!.setPitch(1.0);
      await _flutterTts!.awaitSpeakCompletion(true);
    } catch (e) {
      _debugLog('TTS', 'init error: $e');
    }

    if (mounted) {
      setState(() {
        _currentStage = TestStage.testing;
        // Lúc này _isSpeechEnabled đã là true (nếu khởi tạo thành công)
        _debugLog('1', '-1');
        _speakThenListen('Please read the letter you see on the screen.', lang: 'en-US');
        _showNextLetter(); 
      });
    }
  }
  @override
  void dispose() {
    _classifier?.close();
    _flutterTts?.stop();
    WakelockPlus.disable();
    super.dispose();
  }

  // ignore: unused_element
  Widget _buildTestingUI() {
    return SafeArea(
      child: Column(
        children: [
          // Test info header
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.blue.withOpacity(0.1),
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Virtual nurse message
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _nurseMessage,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                // Current test size
                Text(
                  '20/${_currentSize}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Snellen chart
                SnellenChartWidget(
                  feet: _currentSize,
                  letterToDisplay: _snellenLetter,
                ),
                
                const SizedBox(height: 20),
                
                // Speech recognition status
                if (_isListening)
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mic, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Listening...'),
                    ],
                  ),
                
                // Recognized text
                if (_text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Heard: $_text',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    
    if (_testingRightEye && _coverLeftEye) {
      content = _coverLeftEyeInstruction();
    } else if (_isTryAgain) {
      content = _tryAgainWidget();
    } else {
      content = _buildTestingUI();
    }

    return Scaffold(body: content);
  }
}
