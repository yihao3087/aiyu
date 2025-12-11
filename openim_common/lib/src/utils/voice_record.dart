import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

typedef RecordFc = Function(int sec, String path);
typedef AmplitudeCallback = void Function(double amplitude);

class VoiceRecord {
  static const _dir = "voice";
  static const _ext = ".m4a";
  late String _path;
  int _startTimestamp = 0;
  final int _tag;
  final RecordFc onFinished;
  final RecordFc onInterrupt;
  final int maxRecordSec;
  final Function(int duration)? onDuration;
  final AmplitudeCallback? onAmplitude;
  final _audioRecorder = AudioRecorder();
  Timer? _timer;
  Stream<Amplitude>? _amplitudeStream;
  StreamSubscription<Amplitude>? _ampSubscription;

  VoiceRecord({
    required this.maxRecordSec,
    required this.onInterrupt,
    required this.onFinished,
    this.onDuration,
    this.onAmplitude,
  }) : _tag = _now();

  void _startAmplitudeListener() {
    _ampSubscription?.cancel();
    _amplitudeStream ??= _audioRecorder
        .onAmplitudeChanged(const Duration(milliseconds: 120))
        .asBroadcastStream();
    _ampSubscription = _amplitudeStream!.listen((amp) {
      final current = amp.current;
      final normalized =
          current.isFinite ? ((current + 60) / 60).clamp(0.0, 1.0) : 0.0;
      onAmplitude?.call(normalized);
    });
  }

  void _stopAmplitudeListener() {
    _ampSubscription?.cancel();
    _ampSubscription = null;
    onAmplitude?.call(0);
  }

  start() async {
    if (await _audioRecorder.hasPermission()) {
      var path = (await getApplicationDocumentsDirectory()).path;
      _path = '$path/$_dir/$_tag$_ext';
      File file = File(_path);
      if (!(await file.exists())) {
        await file.create(recursive: true);
      }
      await _audioRecorder.start(RecordConfig(), path: _path);
      onAmplitude?.call(0);
      _startAmplitudeListener();
      _startTimestamp = _now();
      _timer?.cancel();
      _timer = null;
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        final duration = ((_now() - _startTimestamp) ~/ 1000);
        onDuration?.call(duration);
        if (duration >= maxRecordSec) {
          await stop(isInterrupt: true);
          onInterrupt(maxRecordSec, _path);
        }
      });
    }
  }

  stop({bool isInterrupt = false}) async {
    _timer?.cancel();
    _timer = null;
    if (await _audioRecorder.isRecording()) {
      await _audioRecorder.stop();
      _stopAmplitudeListener();
      if (isInterrupt) return;
      onFinished((_now() - _startTimestamp) ~/ 1000, _path);
    } else {
      _stopAmplitudeListener();
    }
  }

  static int _now() => DateTime.now().millisecondsSinceEpoch;
}
