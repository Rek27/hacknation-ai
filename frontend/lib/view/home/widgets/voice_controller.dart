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
/// 
/// Features automatic voice detection:
/// - Auto-starts recording when assistant finishes speaking
/// - Auto-stops after 1 second of silence
/// - Enforces minimum 2-second recording duration
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
  
  // Silence detection
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  Timer? _silenceTimer;
  DateTime? _recordingStartTime;
  double _currentAmplitude = 0.0;
  
  /// Minimum recording duration in seconds
  static const int _minRecordingDurationSeconds = 2;
  
  /// Silence detection threshold (in dBFS, typical range is -160 to 0)
  static const double _silenceThreshold = -40.0;
  
  /// Duration of silence before auto-stopping (in seconds)
  static const int _silenceDurationSeconds = 1;

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

  /// Prepare the recorder for instant recording.
  Future<void> _prepareRecorder() async {
    try {
      // Dispose old recorder if exists
      if (_recorder != null) {
        try {
          await _recorder!.dispose();
        } catch (e) {
          debugPrint('VoiceController: Error disposing old recorder: $e');
        }
      }
      
      // Create fresh recorder instance
      _recorder = AudioRecorder();
      
      // Check permissions upfront
      final hasPermission = await _recorder!.hasPermission();
      if (!hasPermission) {
        _error = 'Microphone permission not granted';
        _isRecorderReady = false;
        notifyListeners();
        return;
      }
      
      // Cache temp directory path if not already cached
      if (_tempDirPath == null) {
        final tempDir = await getTemporaryDirectory();
        _tempDirPath = tempDir.path;
      }
      
      _isRecorderReady = true;
      debugPrint('VoiceController: Recorder prepared and ready');
    } catch (e) {
      _error = 'Failed to prepare recorder: $e';
      _isRecorderReady = false;
      debugPrint('VoiceController._prepareRecorder error: $e');
    }
  }

  /// Start recording user audio with automatic silence detection.
  Future<void> startRecording() async {
    if (_isRecording || _isPlaying) return;
    
    // Fallback: prepare recorder if not ready (should rarely happen)
    if (!_isRecorderReady) {
      debugPrint('VoiceController: Recorder not ready, preparing now (fallback)');
      await _prepareRecorder();
      if (!_isRecorderReady) {
        _error = 'Cannot start recording: recorder not ready';
        notifyListeners();
        return;
      }
    }

    try {
      // Use cached temp directory path for instant file creation
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '$_tempDirPath/voice_input_$timestamp.wav';

      // Update UI immediately before starting actual recording
      _isRecording = true;
      _error = null;
      _recordingStartTime = DateTime.now();
      notifyListeners();

      // Start recording (recorder is pre-warmed, should be fast)
      await _recorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _currentRecordingPath!,
      );
      
      debugPrint('VoiceController: Recording started successfully');
      
      // Start monitoring amplitude for silence detection
      _startAmplitudeMonitoring();
    } catch (e) {
      _error = 'Failed to start recording: $e';
      _isRecording = false;
      _recordingStartTime = null;
      notifyListeners();
      debugPrint('VoiceController.startRecording error: $e');
    }
  }
  
  /// Start monitoring amplitude to detect silence.
  void _startAmplitudeMonitoring() {
    _amplitudeSubscription?.cancel();
    
    _amplitudeSubscription = _recorder!
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen((amplitude) {
      _currentAmplitude = amplitude.current;
      
      // Check if we're in silence
      if (_currentAmplitude < _silenceThreshold) {
        // Start silence timer if not already running
        if (_silenceTimer == null || !_silenceTimer!.isActive) {
          _startSilenceTimer();
        }
      } else {
        // Cancel silence timer if we detect sound
        _silenceTimer?.cancel();
        _silenceTimer = null;
      }
    });
  }
  
  /// Start timer for silence detection.
  void _startSilenceTimer() {
    _silenceTimer?.cancel();
    
    _silenceTimer = Timer(
      const Duration(seconds: _silenceDurationSeconds),
      () async {
        // Check if recording duration meets minimum requirement
        if (_recordingStartTime != null) {
          final duration = DateTime.now().difference(_recordingStartTime!);
          if (duration.inSeconds >= _minRecordingDurationSeconds) {
            // Automatically stop and send
            debugPrint('VoiceController: Auto-stopping after silence (duration: ${duration.inSeconds}s)');
            await stopRecordingAndSend();
          } else {
            debugPrint('VoiceController: Silence detected but recording too short (${duration.inSeconds}s), continuing...');
          }
          // If duration is too short, do nothing and wait for more audio
        }
      },
    );
  }
  
  /// Stop amplitude monitoring.
  void _stopAmplitudeMonitoring() {
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    _silenceTimer?.cancel();
    _silenceTimer = null;
  }

  /// Stop recording and send audio to backend.
  Future<void> stopRecordingAndSend() async {
    if (!_isRecording || _recorder == null) return;

    try {
      // Stop amplitude monitoring
      _stopAmplitudeMonitoring();
      
      final path = await _recorder!.stop();
      _isRecording = false;
      _recordingStartTime = null;
      _isRecorderReady = false; // Mark as not ready, will be prepared during next TTS
      notifyListeners();

      if (path == null || path.isEmpty) {
        _error = 'Recording failed: no audio file';
        notifyListeners();
        return;
      }

      // Send the audio file to backend (will trigger TTS which prepares recorder)
      await _sendVoiceInput(File(path));
    } catch (e) {
      _error = 'Failed to stop recording: $e';
      _isRecording = false;
      _recordingStartTime = null;
      _isRecorderReady = false;
      notifyListeners();
      debugPrint('VoiceController.stopRecordingAndSend error: $e');
    }
  }

  /// Cancel recording without sending.
  Future<void> cancelRecording() async {
    if (!_isRecording || _recorder == null) return;

    try {
      // Stop amplitude monitoring
      _stopAmplitudeMonitoring();
      
      await _recorder!.cancel();
      _isRecording = false;
      _recordingStartTime = null;
      _currentRecordingPath = null;
      _isRecorderReady = false; // Mark as not ready, will be prepared during next TTS
      notifyListeners();
    } catch (e) {
      _isRecording = false;
      _recordingStartTime = null;
      _isRecorderReady = false;
      notifyListeners();
      debugPrint('VoiceController.cancelRecording error: $e');
    }
  }

  /// End the voice session and clean up.
  Future<void> endSession() async {
    // Stop amplitude monitoring
    _stopAmplitudeMonitoring();
    
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
    _recordingStartTime = null;
    
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

      // Start preparing the recorder WHILE TTS is playing (parallel operation)
      final recorderPreparation = _prepareRecorder();

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
      
      // Ensure recorder is ready before proceeding
      await recorderPreparation;
      
      _isPlaying = false;
      notifyListeners();
      
      // Automatically start recording after assistant finishes speaking
      // Recorder is already pre-warmed, so this should be instant
      await startRecording();
    } catch (e) {
      _isPlaying = false;
      _error = 'Failed to play TTS audio: $e';
      notifyListeners();
      debugPrint('VoiceController._playTtsAudio error: $e');
    }
  }

  @override
  void dispose() {
    _stopAmplitudeMonitoring();
    _recorder?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}
