// import 'dart:io';
import 'dart:math'; // Cần cái này để tính hàm exp() chuẩn
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../utils/feature_convert.dart'; 
import '../utils/feature.dart'; 
class Classifier {
  // Tên file model mới (đã đổi tên cho khớp với code train Python)
  final _modelFile = 'assets/models/mobilebert_int32.tflite';
  final _vocabFile = 'assets/models/vocab.txt'; // Cần thêm file này vào assets

  Interpreter? _interpreter;
  FeatureConverter? _featureConverter;
  
  // Labels khớp với Python
  static const List<String> _labels = [
    'CannotSee',       // 0
    'Irrelevant',      // 1
    'No',              // 2
    'RecognizeLetter', // 3
    'Repeat',          // 4
    'Wait',            // 5
    'Yes'              // 6
  ];

  static const int _maxSeqLen = 32; // Phải khớp với MAX_SEQ_LEN bên Python

  Classifier() {
    loadModel();
  }

  Future<void> loadModel() async {
    try {
      // 1. Load Interpreter
      final options = InterpreterOptions();
      // Model input int32 rất nhẹ, chạy CPU (mặc định) là nhanh nhất và ổn định nhất
      // Không cần cấu hình delegate phức tạp.
      
      _interpreter = await Interpreter.fromAsset(_modelFile, options: options);
      debugPrint('MobileBERT Model loaded successfully');

      // 2. Load Vocab và khởi tạo FeatureConverter
      final vocabString = await rootBundle.loadString(_vocabFile);
      final vocabMap = _loadVocab(vocabString);
      
      // Khởi tạo bộ chuyển đổi text -> số
      _featureConverter = FeatureConverter(vocabMap, true, _maxSeqLen);
      debugPrint('Vocab loaded successfully. Size: ${vocabMap.length}');

    } catch (e) {
      debugPrint('Error loading model or vocab: $e');
    }
  }

  // Hàm phụ trợ đọc file vocab.txt
  Map<String, int> _loadVocab(String content) {
    Map<String, int> vocab = {};
    List<String> lines = content.split('\n');
    for (int i = 0; i < lines.length; i++) {
      String token = lines[i].trim();
      if (token.isNotEmpty) {
        vocab[token] = i;
      }
    }
    return vocab;
  }

  /// Hàm phân loại
  Future<Map<String, double>> classify(String rawText) async {
    if (_interpreter == null || _featureConverter == null) {
      debugPrint('Model or FeatureConverter not initialized');
      return {};
    }

    // --- BƯỚC 1: PREPROCESSING (Dùng code Dart tự viết) ---
    // Chuyển String -> Feature (gồm 3 mảng số)
    Feature feature = _featureConverter!.convert(rawText);

    // --- BƯỚC 2: CHUẨN BỊ INPUT ---
    // Thứ tự inputs phải khớp với thứ tự lúc build model trong Python:
    // inputs=[input_word_ids, input_mask, input_type_ids]
    
    // Input 1: Ids [1, 32]
    var inputIds = [feature.inputIds]; 
    // Input 2: Mask [1, 32]
    var inputMask = [feature.inputMask];
    // Input 3: Segment Ids [1, 32]
    var segmentIds = [feature.segmentIds];

    // Danh sách inputs để đưa vào tflite
    var inputs = [inputIds,segmentIds, inputMask];

    // --- BƯỚC 3: CHUẨN BỊ OUTPUT ---
    // Output shape: [1, _labels.length]
    var outputBuffer = List.filled(1 * _labels.length, 0.0).reshape([1, _labels.length]);
    
    // Map output index 0 vào buffer
    var outputs = {0: outputBuffer};

    // --- BƯỚC 4: CHẠY INFERENCE ---
    try {
      // Dùng runForMultipleInputs vì có 3 đầu vào
      _interpreter!.runForMultipleInputs(inputs, outputs);
    } catch (e) {
      debugPrint('Inference error: $e');
      return {};
    }

    // --- BƯỚC 5: XỬ LÝ KẾT QUẢ ---
    List<double> logits = List<double>.from(outputBuffer[0]);
    List<double> probabilities = _softmax(logits);

    Map<String, double> resultMap = {};
    for (int i = 0; i < _labels.length; i++) {
      resultMap[_labels[i]] = probabilities[i];
    }

    // Sắp xếp giảm dần
    var sortedEntries = resultMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Map.fromEntries(sortedEntries);
  }

  // Hàm Softmax chuẩn toán học
  List<double> _softmax(List<double> logits) {
    if (logits.isEmpty) return [];
    // Tìm max để trừ (tránh tràn số - numerical stability)
    double maxLogit = logits.reduce(max);
    
    List<double> exps = logits.map((x) => exp(x - maxLogit)).toList();
    double sumExps = exps.reduce((a, b) => a + b);
    
    return exps.map((x) => x / sumExps).toList();
  }
  
  void close() {
    _interpreter?.close();
  }
}