import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class SpeechTestScreen extends StatefulWidget {
  const SpeechTestScreen({Key? key}) : super(key: key);

  @override
  State<SpeechTestScreen> createState() => _SpeechTestScreenState();
}

class _SpeechTestScreenState extends State<SpeechTestScreen> {
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _lastWords = '';
  String _recognizedLetter = '';
  List<String> _recognitionHistory = [];
  String _currentLanguage = 'en-US'; // Default to English

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  /// Khởi tạo speech recognition
  Future<void> _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  /// Mỗi khi nhận được kết quả nhận diện
  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords.toUpperCase();
      if (_lastWords.isNotEmpty) {
        _recognizedLetter = _lastWords[0]; // Lấy ký tự đầu tiên
        _recognitionHistory.add('${DateTime.now().toString()}: $_recognizedLetter');
      }
    });
  }

  /// Chuyển đổi ngôn ngữ
  void _toggleLanguage() {
    setState(() {
      _currentLanguage = _currentLanguage == 'en-US' ? 'vi-VN' : 'en-US';
    });
  }

  /// Bắt đầu lắng nghe
  Future<void> _startListening() async {
    // Kiểm tra xem speech recognition đã được khởi tạo chưa
    if (!_speechEnabled) {
      await _initSpeech();
    }

    if (_speechEnabled) {
      try {
        await _speechToText.listen(
          onResult: _onSpeechResult,
          listenFor: const Duration(seconds: 30),
          localeId: _currentLanguage,
          cancelOnError: true,
          partialResults: true,
        );
        setState(() {});
      } catch (e) {
        print('Error starting speech recognition: $e');
        // Thử khởi tạo lại nếu có lỗi
        await _initSpeech();
      }
    } else {
      print('Speech recognition not available');
    }
  }

  /// Dừng lắng nghe
  Future<void> _stopListening() async {
    try {
      await _speechToText.stop();
      setState(() {});
    } catch (e) {
      print('Error stopping speech recognition: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Speech to Text'),
        actions: [
          IconButton(
            icon: Icon(_currentLanguage == 'en-US' ? Icons.language : Icons.translate),
            onPressed: _toggleLanguage,
            tooltip: _currentLanguage == 'en-US' ? 'Switch to Vietnamese' : 'Switch to English',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    _speechEnabled
                        ? 'Speech recognition available'
                        : 'Speech recognition not available',
                    style: const TextStyle(fontSize: 20.0),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Current language: ${_currentLanguage == 'en-US' ? 'English' : 'Vietnamese'}',
                    style: const TextStyle(fontSize: 16.0, color: Colors.blue),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Recognized Letter: $_recognizedLetter',
                style: const TextStyle(fontSize: 40.0, fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Full text: $_lastWords',
                style: const TextStyle(fontSize: 14.0),
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: ListView.builder(
                  reverse: true,
                  itemCount: _recognitionHistory.length,
                  itemBuilder: (context, index) {
                    return Text(_recognitionHistory[index]);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed:
            _speechToText.isNotListening ? _startListening : _stopListening,
        tooltip: 'Listen',
        child: Icon(_speechToText.isNotListening ? Icons.mic_off : Icons.mic),
      ),
    );
  }
}