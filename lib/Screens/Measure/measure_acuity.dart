import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:flutter_application_1/Screens/ShowScore/show_score.dart';
import 'package:flutter_application_1/SnellenChart/snellen_chart_widget.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MeasureAcuity extends StatefulWidget {
  const MeasureAcuity({Key? key}) : super(key: key);

  @override
  State<MeasureAcuity> createState() => _MeasureAcuityState();
}

enum TestStage {
  initial,
  positionCheck,
  eyeCoverCheck,
  testing,
  switching,
  completed
}

class _MeasureAcuityState extends State<MeasureAcuity> {
  // Test state
  TestStage _currentStage = TestStage.initial;
  var _text = '', _snellenLetter = '';
  int _correctRead = 0, _incorrectRead = 0, _rowCount = 0;
  var _isTryAgain = false, _coverLeftEye = false, _testingRightEye = false;
  var _leftEyeScore = 0, _rightEyeScore = 0;
  
  // Vision test parameters
  final Map<int, int> _snellenSizes = {
    200: 5, // 20/200 - show 5 optotypes
    100: 5, // 20/100
    70: 5,  // 20/70
    50: 5,  // 20/50
    40: 5,  // 20/40
    30: 5,  // 20/30
    20: 5,  // 20/20
    15: 5,  // 20/15
    13: 5,  // 20/13
    10: 5,  // 20/10
  };
  int _currentSize = 200; // Start with 20/200
  
  // Camera and MediaPipe (temporarily disabled)
  /*
  CameraController? _cameraController;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );
  bool _isFaceDetecting = false;
  */
  
  // Temporary variables for simulation
  double _faceDistance = 3.0;
  bool _isCorrectDistance = true;
  bool _isEyeProperlyVisible = true;

  // Speech recognition
  final SpeechToText _speech = SpeechToText();
  bool _isSpeechEnabled = false;
  bool _isListening = false;

  // TFLite model
  late Interpreter _interpreter;
  bool _isModelLoaded = false;
  
  // Virtual nurse messages
  String _nurseMessage = 'Please position your phone at eye level in a well-lit room.';

  Future<void> _startListening() async {
    if (!_isSpeechEnabled) return;

    setState(() {
      _isListening = true;
      _text = '';
    });

    try {
      await _speech.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        partialResults: false,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      );
    } catch (e) {
      print('Error starting speech recognition: $e');
    }
  }

  Future<void> _onSpeechResult(SpeechRecognitionResult result) async {
    if (!result.finalResult) return;

    final String spokenText = result.recognizedWords.toLowerCase();
    setState(() {
      _text = spokenText;
      _isListening = false;
    });

    if (_isModelLoaded) {
      final intent = await _classifyIntent(spokenText);
      _handleUserIntent(intent, spokenText);
    }
  }

  Future<String> _classifyIntent(String text) async {
    // Convert text to embeddings (simplified for example)
    List<double> embeddings = List.filled(50, 0.0); // Adjust size based on your model
    final words = text.split(' ');
    for (var i = 0; i < words.length && i < 50; i++) {
      embeddings[i] = words[i].codeUnitAt(0).toDouble();
    }

    List<double> outputs = List.filled(3, 0.0);
    _interpreter.run([embeddings], [outputs]);

    final maxIndex = outputs.indexOf(outputs.reduce(max));
    switch (maxIndex) {
      case 0:
        return 'RecognizeLetter';
      case 1:
        return 'Cannot_See';
      case 2:
        return 'Wait';
      default:
        return 'Unknown';
    }
  }

  void _handleUserIntent(String intent, String spokenText) {
    switch (intent) {
      case 'RecognizeLetter':
        final letterMatch = RegExp(r'the letter (\w)').firstMatch(spokenText);
        if (letterMatch != null) {
          final recognizedLetter = letterMatch.group(1)?.toUpperCase();
          _confirmLetter(recognizedLetter ?? '');
        } else {
          setState(() {
            _nurseMessage = 'Please say "the letter" followed by the letter you see.';
          });
          _startListening();
        }
        break;

      case 'Cannot_See':
        _endTest();
        break;

      case 'Wait':
        setState(() {
          _nurseMessage = 'Take your time. Say "ready" when you want to continue.';
        });
        _startListening();
        break;

      default:
        setState(() {
          _isTryAgain = true;
          _nurseMessage = 'Please try again, saying "the letter" followed by what you see.';
        });
        Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => _isTryAgain = false);
            _startListening();
          }
        });
    }
  }

  void _confirmLetter(String recognizedLetter) {
    setState(() {
      if (recognizedLetter == _snellenLetter) {
        _correctRead++;
        _rowCount++;
        _nurseMessage = 'Correct!';
      } else {
        _incorrectRead++;
        _rowCount++;
        _nurseMessage = 'Not quite right. Let\'s continue.';
      }
    });

    final currentRowSize = _snellenSizes[_currentSize] ?? 5;
    
    if (_rowCount < currentRowSize) {
      _showNextLetter();
    } else {
      if (_correctRead > currentRowSize / 2) {
        _moveToNextSize();
      } else {
        _endTest();
      }
    }
  }

  void _showNextLetter() {
    setState(() {
      _snellenLetter = _getSnellenLetter(1);
      _nurseMessage = 'Please read the next letter.';
    });
    _startListening();
  }

  void _moveToNextSize() {
    final sizes = _snellenSizes.keys.toList()..sort();
    final currentIndex = sizes.indexOf(_currentSize);
    
    setState(() {
      _snellenLetter = '';
      _correctRead = 0;
      _incorrectRead = 0;
      _rowCount = 0;
      
      if (currentIndex < sizes.length - 1) {
        _currentSize = sizes[currentIndex + 1];
        _nurseMessage = 'Good! Let\'s try smaller letters.';
        _showNextLetter();
      } else {
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
          'deviceInfo': {
            'screenPPI': MediaQuery.of(context).devicePixelRatio * 160,
            'deviceModel': Platform.isIOS ? 'iOS Device' : 'Android Device',
          }
        });
      }
    } catch (e) {
      print('Error saving test results: $e');
      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save test results. Please try again later.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _endTest() async {
    if (!mounted) return;

    // Store the current score
    if (!_testingRightEye) {
      _leftEyeScore = _currentSize;
      setState(() {
        _testingRightEye = true;
        _currentStage = TestStage.eyeCoverCheck;
        _coverLeftEye = true;
        _snellenLetter = '';
        _correctRead = 0;
        _incorrectRead = 0;
        _rowCount = 0;
        _currentSize = 200; // Reset to 20/200
        _nurseMessage = 'Now let\'s test your right eye. Please cover your left eye.';
      });

      // Wait for proper eye covering before continuing
      _startRightEyeTest();
    } else {
      _rightEyeScore = _currentSize;
      
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
    }
  }

  void _startRightEyeTest() {
    // Simple delay to simulate eye check
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _coverLeftEye = false;
          _currentStage = TestStage.testing;
          _nurseMessage = 'Now let\'s begin testing your right eye.';
        });
        _showNextLetter();
      }
    });
  }

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

  // void _tryAgain() {
  //   setState(() {
  //     _isTryAgain = true;
  //   });
  //   Timer(const Duration(seconds: 3), () {
  //     setState(() {
  //       _isTryAgain = false;
  //     });
  //     _activateSpeechToText();
  //   });
  // }

  String _getSnellenLetter(int length) {
    // the list of characters
    const _chars = 'EFPTOZLDCZ';

    // initialize the random class
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

  // Future<void> _initializeCamera() async {
  //   final cameras = await availableCameras();
  //   final frontCamera = cameras.firstWhere(
  //     (camera) => camera.lensDirection == CameraLensDirection.front,
  //     orElse: () => cameras.first,
  //   );

  //   _cameraController = CameraController(
  //     frontCamera,
  //     ResolutionPreset.high,
  //     enableAudio: false,
  //   );

  //   await _cameraController!.initialize();
  //   if (!mounted) return;

  //   _cameraController!.startImageStream(_processImage);
  //   setState(() {});
  // }

  Future<void> _initializeSpeech() async {
    _isSpeechEnabled = await _speech.initialize(
      onError: (error) => print('Speech recognition error: $error'),
      onStatus: (status) => print('Speech recognition status: $status'),
    );
    setState(() {});
  }

  Future<void> _initializeTFLite() async {
    try {
      _interpreter = await Interpreter.fromAsset('intent_model.tflite');
      _isModelLoaded = true;
    } catch (e) {
      print('Error loading TFLite model: $e');
    }
  }

  // Future<void> _processImage(CameraImage image) async {
  //   if (_isFaceDetecting) return;
  //   _isFaceDetecting = true;

  //   try {
  //     final inputImage = InputImage.fromBytes(
  //       bytes: image.planes[0].bytes,
  //       metadata: InputImageMetadata(
  //         rotation: InputImageRotation.rotation0deg,
  //         format: InputImageFormat.bgra8888,
  //         size: Size(image.width.toDouble(), image.height.toDouble()),
  //         bytesPerRow: image.planes[0].bytesPerRow,
  //       ),
  //     );

  //     final faces = await _faceDetector.processImage(inputImage);
      
  //     if (faces.isNotEmpty) {
  //       final face = faces.first;
  //       _processFaceDetection(face);
  //     } else {
  //       setState(() {
  //         _isCorrectDistance = false;
  //         _isEyeProperlyVisible = false;
  //         _nurseMessage = 'Please face the camera directly.';
  //       });
  //     }
  //   } catch (e) {
  //     print('Error processing image: $e');
  //   } finally {
  //     _isFaceDetecting = false;
  //   }
  // }

  // void _processFaceDetection(Face face) {
  //   // Calculate distance using face size
  //   final faceWidth = face.boundingBox.width;
  //   _faceDistance = _calculateDistance(faceWidth);
  //   _isCorrectDistance = (_faceDistance >= 2.8 && _faceDistance <= 3.2);

  //   // Check eye coverage when needed
  //   if (_currentStage == TestStage.eyeCoverCheck) {
  //     final leftEye = face.landmarks[FaceLandmarkType.leftEye];
  //     final rightEye = face.landmarks[FaceLandmarkType.rightEye];
      
  //     if (_testingRightEye) {
  //       _isEyeProperlyVisible = leftEye == null && rightEye != null;
  //     } else {
  //       _isEyeProperlyVisible = leftEye != null && rightEye == null;
  //     }
  //   }

  //   setState(() {
  //     _nurseMessage = _isCorrectDistance 
  //         ? 'Perfect distance! Keep your phone steady.'
  //         : _faceDistance < 3.0 
  //             ? 'Move back slowly...'
  //             : 'Move closer slowly...';
  //   });
  // }

  double _calculateDistance(double faceWidth) {
    // This is a simplified calculation - needs calibration
    const double KNOWN_FACE_WIDTH = 0.15; // Average face width in meters
    const double FOCAL_LENGTH = 1000; // Focal length in pixels
    return (KNOWN_FACE_WIDTH * FOCAL_LENGTH) / faceWidth;
  }

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _initializeSpeech();
    _initializeTFLite();
    // Start directly with testing instead of position check
    _currentStage = TestStage.testing;
    _showNextLetter();
  }

  @override
  void dispose() {
    _interpreter.close();
    WakelockPlus.disable();
    super.dispose();
  }

  Widget _buildPositionCheckUI() {
    // Simple UI without camera
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.remove_red_eye,
            size: 48,
            color: Colors.blue,
          ),
          const SizedBox(height: 20),
          Text(
            _nurseMessage,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _currentStage = TestStage.testing;
                _showNextLetter();
              });
            },
            child: const Text('Start Test'),
          ),
        ],
      ),
    );
  }

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
