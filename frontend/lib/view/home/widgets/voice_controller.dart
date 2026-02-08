import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:frontend/service/agent_api.dart';

/// Controller that manages voice interaction with the backend API.
///
/// Handles recording user audio, sending it to the backend, receiving
/// transcriptions and TTS responses, and playing back assistant audio.
class VoiceController extends ChangeNotifier {
  final AgentApi _api;
  final String _sessionId;

  VoiceController({
    required AgentApi api,
    required String sessionId,
  })  : _api = api,
        _sessionId = sessionId;

  // ── Audio recording ──────────────────────────────────────────────────
  AudioRecorder? _recorder;
  bool _isRecording = false;
  String? _currentRecordingPath;
  bool _isRecorderReady = false;
  String? _tempDirPath;

  /// Whether audio is currently being recorded.
  bool get isRecording => _isRecording;

  // ── Audio playback ───────────────────────────────────────────────────
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  /// Whether TTS audio is currently playing.
  bool get isPlaying => _isPlaying;

  // ── Session state ────────────────────────────────────────────────────
  bool _isSessionStarted = false;
  bool _isLoading = false;
  String? _error;
  String _currentPhase = 'idle';
  String _lastAssistantText = '';
  String _lastUserText = '';

  /// Whether the voice session has been started.
  bool get isSessionStarted => _isSessionStarted;

  /// Whether a request is in progress.
  bool get isLoading => _isLoading;

  /// Current error message, if any.
  String? get error => _error;

  /// Current conversation phase (e.g., 'greeting', 'listening', 'processing').
  String get currentPhase => _currentPhase;

  /// Last text spoken by the assistant.
  String get lastAssistantText => _lastAssistantText;

  /// Last text spoken by the user (transcribed).
  String get lastUserText => _lastUserText;

  /// Whether we're waiting for user input.
  bool get isTalking => _isPlaying;

  // ── Public methods ───────────────────────────────────────────────────

  /// Start a voice session with the hardcoded greeting.
  Future<void> startVoiceSession() async {
    if (_isSessionStarted) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Prepare recorder for instant response
      await _prepareRecorder();
      
      final response = await _api.startVoice(_sessionId);
      
      _isSessionStarted = true;
      _currentPhase = response.phase;
      _lastAssistantText = response.text;
      
      // Play the greeting TTS audio
      await _playTtsAudio(response.audioId);
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to start voice session: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint('VoiceController.startVoiceSession error: $e');
    }
  }

  /// Prepare the recorder for instant recording (call once at session start).
  Future<void> _prepareRecorder() async {
    if (_isRecorderReady) return;
    
    try {
      // Create recorder instance
      _recorder = AudioRecorder();
      
      // Check permissions upfront
      final hasPermission = await _recorder!.hasPermission();
      if (!hasPermission) {
        _error = 'Microphone permission not granted';
        notifyListeners();
        return;
      }
      
      // Cache temp directory path
      final tempDir = await getTemporaryDirectory();
      _tempDirPath = tempDir.path;
      
      _isRecorderReady = true;
      debugPrint('VoiceController: Recorder prepared and ready');
    } catch (e) {
      _error = 'Failed to prepare recorder: $e';
      debugPrint('VoiceController._prepareRecorder error: $e');
    }
  }

  /// Start recording user audio (optimized for instant response).
  Future<void> startRecording() async {
    if (_isRecording || _isPlaying || !_isRecorderReady) return;

    try {
      // Use cached temp directory path for instant file creation
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '$_tempDirPath/voice_input_$timestamp.wav';

      // Update UI immediately before starting actual recording
      _isRecording = true;
      _error = null;
      notifyListeners();

      // Start recording (this is still async but UI already updated)
      await _recorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _currentRecordingPath!,
      );
    } catch (e) {
      _error = 'Failed to start recording: $e';
      _isRecording = false;
      notifyListeners();
      debugPrint('VoiceController.startRecording error: $e');
    }
  }

  /// Stop recording and send audio to backend.
  Future<void> stopRecordingAndSend() async {
    if (!_isRecording || _recorder == null) return;

    try {
      final path = await _recorder!.stop();
      _isRecording = false;
      notifyListeners();

      if (path == null || path.isEmpty) {
        _error = 'Recording failed: no audio file';
        notifyListeners();
        // Re-prepare recorder for next use
        await _prepareRecorder();
        return;
      }

      // Send the audio file to backend
      await _sendVoiceInput(File(path));
      
      // Re-prepare recorder for next use
      await _prepareRecorder();
    } catch (e) {
      _error = 'Failed to stop recording: $e';
      _isRecording = false;
      notifyListeners();
      debugPrint('VoiceController.stopRecordingAndSend error: $e');
      // Re-prepare recorder for next use
      await _prepareRecorder();
    }
  }

  /// Cancel recording without sending.
  Future<void> cancelRecording() async {
    if (!_isRecording || _recorder == null) return;

    try {
      await _recorder!.cancel();
      _isRecording = false;
      _currentRecordingPath = null;
      notifyListeners();
      
      // Re-prepare recorder for next use
      await _prepareRecorder();
    } catch (e) {
      _isRecording = false;
      notifyListeners();
      debugPrint('VoiceController.cancelRecording error: $e');
    }
  }

  /// End the voice session and clean up.
  Future<void> endSession() async {
    await cancelRecording();
    await _audioPlayer.stop();
    
    // Clean up recorder
    _recorder?.dispose();
    _recorder = null;
    _isRecorderReady = false;
    _tempDirPath = null;
    
    _isSessionStarted = false;
    _isPlaying = false;
    _isLoading = false;
    _error = null;
    _currentPhase = 'idle';
    _lastAssistantText = '';
    _lastUserText = '';
    
    notifyListeners();
  }

  // ── Private methods ──────────────────────────────────────────────────

  /// Send recorded audio to backend and handle response.
  Future<void> _sendVoiceInput(File audioFile) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.sendVoiceInput(_sessionId, audioFile);
      
      _currentPhase = response.phase;
      _lastAssistantText = response.text;
      _lastUserText = response.transcribedText;
      
      // Play the assistant's TTS response
      await _playTtsAudio(response.audioId);
      
      _isLoading = false;
      notifyListeners();

      // Clean up the temporary audio file
      try {
        if (await audioFile.exists()) {
          await audioFile.delete();
        }
      } catch (e) {
        debugPrint('VoiceController: Failed to delete temp file: $e');
      }
    } catch (e) {
      _error = 'Failed to send voice input: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint('VoiceController._sendVoiceInput error: $e');
    }
  }

  /// Play TTS audio from backend.
  Future<void> _playTtsAudio(String audioId) async {
    try {
      _isPlaying = true;
      notifyListeners();

      final audioUrl = _api.getTtsAudioUrl(audioId);

      await _audioPlayer.play(
        UrlSource(audioUrl),
        ctx: AudioContext(
          android: AudioContextAndroid(
            contentType: AndroidContentType.speech,
            usageType: AndroidUsageType.voiceCommunication,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {},
          ),
        ),
      );

      // Wait for playback to complete
      await _audioPlayer.onPlayerComplete.first;
      
      _isPlaying = false;
      notifyListeners();
    } catch (e) {
      _isPlaying = false;
      _error = 'Failed to play TTS audio: $e';
      notifyListeners();
      debugPrint('VoiceController._playTtsAudio error: $e');
    }
  }

  @override
  void dispose() {
    _recorder?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}
