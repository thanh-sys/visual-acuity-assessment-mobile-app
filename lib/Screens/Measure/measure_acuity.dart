import 'dart:async';
import 'dart:math';
import 'package:flutter_application_1/Screens/ShowScore/show_score.dart';
import 'package:flutter_application_1/SnellenChart/snellen_chart_widget.dart';
import 'package:flutter/material.dart';

/* To be implemented later:
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
*/

class MeasureAcuity extends StatefulWidget {
  const MeasureAcuity({Key? key}) : super(key: key);

  @override
  State<MeasureAcuity> createState() => _MeasureAcuityState();
}

class _MeasureAcuityState extends State<MeasureAcuity> {
  // state variables
  var _text = '', _snellenLetter = '';
  int _correctRead = 0, _incorrectRead = 0, _rowCount = 0, _sizeOfChart = 70;
  var _isTryAgain = false, _coverLeftEye = false, _testingRightEye = false;
  var _leftEyeScore = 0, _rightEyeScore = 0;

  /* Original STT code - to be implemented later
  final _speech = SpeechToText();
  */

  // Temporary simple version without STT
  void _activateSpeechToText() {
    setState(() {
      _snellenLetter = _getSnellenLetter(1);
      // _isSpeechActive = true;
    });
    _simulateInput();
  }

  // Temporary function to simulate input
  void _simulateInput() {
    // For testing, auto-simulate correct input after 2 seconds
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        _checkLetter(_snellenLetter);
      }
    });
  }

  // Temporary function to check letters without STT
  void _checkLetter(String letter) {
    if (!mounted) return;

    setState(() {
      if (letter == _snellenLetter) {
        _correctRead += 1;
        _rowCount += 1;
      } else {
        _incorrectRead += 1;
        _rowCount += 1;
      }
    });

    if (!mounted) return;

    if (_rowCount < 3) {
      _activateSpeechToText();
    } else {
      if (_incorrectRead <= _correctRead) {
        setState(() {
          // _isSpeechActive = false;
          _snellenLetter = '';
          _correctRead = 0;
          _incorrectRead = 0;
          _rowCount = 0;

          if (_sizeOfChart == 70) _sizeOfChart = 60;
          else if (_sizeOfChart == 60) _sizeOfChart = 50;
          else if (_sizeOfChart == 50) _sizeOfChart = 40;
          else if (_sizeOfChart == 40) _sizeOfChart = 30;
          else if (_sizeOfChart == 30) _sizeOfChart = 20;
          else if (_sizeOfChart == 20) _sizeOfChart = 15;
          else if (_sizeOfChart == 15) _sizeOfChart = 10;
          else if (_sizeOfChart == 10) _sizeOfChart = 7;
          else if (_sizeOfChart == 7) _sizeOfChart = 4;
          else _endTest();
        });

        if (mounted) {
          _activateSpeechToText();
        }
      } else {
        _endTest();
      }
    }
  }

  void _endTest() {
    if (!mounted) return;

    var scoreSize = 0;

    if (_sizeOfChart == 70) scoreSize = 0;
    else if (_sizeOfChart == 60) scoreSize = 70;
    else if (_sizeOfChart == 50) scoreSize = 60;
    else if (_sizeOfChart == 40) scoreSize = 50;
    else if (_sizeOfChart == 30) scoreSize = 40;
    else if (_sizeOfChart == 20) scoreSize = 30;
    else if (_sizeOfChart == 15) scoreSize = 20;
    else if (_sizeOfChart == 10) scoreSize = 15;
    else if (_sizeOfChart == 7) scoreSize = 10;
    else if (_sizeOfChart == 4) scoreSize = 7;
    else scoreSize = 4;

    if (!_testingRightEye) {
      _leftEyeScore = scoreSize;
    } else {
      _rightEyeScore = scoreSize;
    }

    setState(() {
      _testingRightEye = !_testingRightEye;
    });

    if (_testingRightEye) {
      setState(() {
        _coverLeftEye = true;
        // _isSpeechActive = false;
        _snellenLetter = '';
        _correctRead = 0;
        _incorrectRead = 0;
        _rowCount = 0;
        _sizeOfChart = 70;
        _text = '';
      });

      Timer(const Duration(seconds: 10), () {
        if (!mounted) return;
        
        setState(() {
          _coverLeftEye = false;
        });
        _activateSpeechToText();
      });
    } else {
      if (!mounted) return;
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) {
            return ShowScore(
              rightEyeScore: _rightEyeScore,
              leftEyeScore: _leftEyeScore,
            );
          },
        ),
      );
    }
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
    const _chars = 'ABCDEFGHIJKLMNOPQRSTVWXYZ';

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

  @override
  void initState() {
    super.initState();
    _activateSpeechToText();
  }

  @override
  Widget build(BuildContext context) {
    // disbale screen-timeout
    //     // WakelockPlus.disable();

    return _coverLeftEye
        ? _coverLeftEyeInstruction()
        : Scaffold(
            body: _isTryAgain
                ? _tryAgainWidget()
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.1,
                        ),
                        SnellenChartWidget(
                          feet: _sizeOfChart,
                          letterToDisplay: _snellenLetter,
                        ),
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.1,
                        ),
                        Text(
                          _text,
                        ),
                      ],
                    ),
                  ),
          );
  }
}
