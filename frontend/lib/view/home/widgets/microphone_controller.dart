import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

/// Controller that monitors microphone amplitude for the voice wave animation.
///
/// Exposes a normalised [amplitude] value (0.0 – silent, 1.0 – loud) that the
/// UI can read via Provider to drive the wave visualiser.
class MicrophoneController extends ChangeNotifier {
  AudioRecorder? _recorder;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  StreamSubscription<Uint8List>? _recordStreamSubscription;

  double _amplitude = 0.0;

  /// Current normalised amplitude (0.0 – 1.0).
  double get amplitude => _amplitude;

  bool _isListening = false;

  /// Whether the microphone is actively being monitored.
  bool get isListening => _isListening;

  bool _hasPermission = false;

  /// Whether the user has granted microphone permission.
  bool get hasPermission => _hasPermission;

  /// dBFS floor below which the signal is considered silence.
  static const double _dbFloor = -50.0;

  /// Smoothing factor for exponential moving average (0 = no change, 1 = instant).
  static const double _smoothingFactor = 0.35;

  /// Request permission and begin monitoring microphone amplitude.
  Future<void> startListening() async {
    if (_isListening) return;
    _recorder = AudioRecorder();
    _hasPermission = await _recorder!.hasPermission();
    if (!_hasPermission) {
      notifyListeners();
      return;
    }
    // Subscribe to amplitude changes at ~100 ms intervals.
    _amplitudeSubscription = _recorder!
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen(_onAmplitude);
    // Start a stream recording so the recorder is active (no file output).
    final Stream<Uint8List> stream = await _recorder!.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        numChannels: 1,
        sampleRate: 16000,
      ),
    );
    // Consume the stream to prevent backpressure; data is not needed.
    _recordStreamSubscription = stream.listen((_) {});
    _isListening = true;
    notifyListeners();
  }

  /// Stop monitoring and release the recorder.
  Future<void> stopListening() async {
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    await _recordStreamSubscription?.cancel();
    _recordStreamSubscription = null;
    if (_recorder != null) {
      try {
        await _recorder!.cancel();
        await _recorder!.dispose();
      } catch (e) {
        debugPrint('MicrophoneController.stopListening cleanup error: $e');
      }
      _recorder = null;
    }
    _isListening = false;
    _amplitude = 0.0;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _onAmplitude(Amplitude amp) {
    // amp.current is in dBFS (typically -160 to 0).
    // Normalise into 0.0 – 1.0 and apply exponential smoothing.
    final double raw = ((amp.current - _dbFloor) / -_dbFloor).clamp(0.0, 1.0);
    final double smoothed = _amplitude + (raw - _amplitude) * _smoothingFactor;
    if ((_amplitude - smoothed).abs() > 0.005) {
      _amplitude = smoothed;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _amplitudeSubscription?.cancel();
    _recordStreamSubscription?.cancel();
    _recorder?.cancel();
    _recorder?.dispose();
    super.dispose();
  }
}
