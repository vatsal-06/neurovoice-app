import 'dart:async';
import 'package:neurovoice_app/core/network/voice_ml_api.dart';
import 'package:flutter/material.dart';
import 'package:neurovoice_app/core/utils/audio_helper.dart';
import 'package:hive/hive.dart';

/// ===============================
/// Test Type Registry (Extensible)
/// ===============================
class TestTypes {
  static const String voice = 'voice';
  static const String face = 'face';
  static const String tremors = 'tremors';
}

/// ===============================
/// Hive Constants
/// ===============================
const String kResultsBox = 'voice_results';

class VoiceCheckViewModel extends ChangeNotifier {
  final AudioRecorderService _audioService = AudioRecorderService();

  Timer? _recordingTimer;
  Timer? _progressTimer;

  int remainingSeconds = 12;
  String? recordedFilePath;
  double processProgress = 0.0;

  bool _isRecording = false;
  bool _navigateToProcessing = false;
  bool _navigateToResults = false;
  bool _disposed = false;

  /// ===============================
  /// ML OUTPUT
  /// ===============================
  bool isUploading = false;
  double? confidence; // risk_score
  String? riskLevel; // risk_level
  String? errorMessage;

  /// ===============================
  /// CLINICAL INPUTS (NEW)
  /// ===============================
  int? ac; // age category (binary)
  int? nth; // neurological test history
  int? htn; // hypertension
  final int updrs = 0; // fixed for current model

  // ===============================
  // GETTERS
  // ===============================

  bool get isRecording => _isRecording;
  bool get shouldNavigateToProcessing => _navigateToProcessing;
  bool get shouldNavigateToResults => _navigateToResults;

  void resetNavigationFlags() {
    _navigateToProcessing = false;
    _navigateToResults = false;
  }

  // ===============================
  // CLINICAL INPUT SETTER
  // ===============================

  void setClinicalInputs({
    required int ac,
    required int nth,
    required int htn,
  }) {
    this.ac = ac;
    this.nth = nth;
    this.htn = htn;
  }

  // ===============================
  // RECORDING
  // ===============================

  Future<void> startRecording() async {
    if (_isRecording) return;

    // 🔒 Ensure clinical form was filled
    if (ac == null || nth == null || htn == null) {
      errorMessage = 'Clinical information missing.';
      notifyListeners();
      return;
    }

    remainingSeconds = 12;
    errorMessage = null;
    notifyListeners();

    recordedFilePath = await _audioService.startRecording();
    _isRecording = true;

    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (remainingSeconds <= 0) {
        await stopRecording();
      } else {
        remainingSeconds--;
        notifyListeners();
      }
    });
  }

  Future<void> stopRecording() async {
    if (!_isRecording) return;

    _recordingTimer?.cancel();
    _recordingTimer = null;

    recordedFilePath = await _audioService.stopRecording();
    _isRecording = false;

    if (_disposed || recordedFilePath == null) return;

    _navigateToProcessing = true;
    notifyListeners();

    _uploadAndAnalyze();
  }

  // ===============================
  // BACKEND / ML
  // ===============================

  Future<void> _uploadAndAnalyze() async {
    isUploading = true;
    processProgress = 0.1;
    notifyListeners();

    try {
      // Smooth progress animation
      _progressTimer?.cancel();
      _progressTimer = Timer.periodic(const Duration(milliseconds: 300), (
        timer,
      ) {
        if (!isUploading || _disposed) {
          timer.cancel();
          return;
        }
        if (processProgress < 0.9) {
          processProgress += 0.03;
          notifyListeners();
        }
      });

      final response = await VoiceMlApi.uploadWav(
        wavPath: recordedFilePath!,
        ac: ac!,
        nth: nth!,
        htn: htn!,
        updrs: updrs,
      );

      debugPrint('🧠 Raw ML response: $response');

      confidence = (response['risk_score'] as num).toDouble();
      riskLevel = response['risk_level'] as String;

      // ===============================
      // SAVE RESULT TO HISTORY
      // ===============================
      final box = Hive.box(kResultsBox);
      box.add({
        'riskScore': confidence,
        'riskLevel': riskLevel,
        'timestamp': DateTime.now().toIso8601String(),
        'testType': TestTypes.voice,
        'ac': ac,
        'nth': nth,
        'htn': htn,
        'updrs': updrs,
      });

      isUploading = false;
      processProgress = 1.0;

      _navigateToResults = true;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Voice analysis failed: $e');
      isUploading = false;
      processProgress = 0.0;
      errorMessage = 'Unable to analyze voice.';
      notifyListeners();
    }
  }

  // ===============================
  // UI HELPERS
  // ===============================

  String get formattedTime =>
      '00:${remainingSeconds.toString().padLeft(2, '0')}';

  // ===============================
  // CLEANUP
  // ===============================

  @override
  void dispose() {
    _disposed = true;
    _recordingTimer?.cancel();
    _progressTimer?.cancel();
    _audioService.dispose();
    super.dispose();
  }
}
