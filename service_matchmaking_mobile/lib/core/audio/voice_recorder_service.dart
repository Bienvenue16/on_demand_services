import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceRecorderException implements Exception {
  const VoiceRecorderException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Enregistre un message vocal au format AAC/M4A (leger, largement supporte).
class VoiceRecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  Future<String> startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw const VoiceRecorderException('Permission microphone refusee.');
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().microsecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 96000),
      path: path,
    );
    return path;
  }

  Future<String?> stopRecording() => _recorder.stop();

  Future<void> cancelRecording() => _recorder.cancel();

  Future<bool> isRecording() => _recorder.isRecording();

  Future<void> dispose() => _recorder.dispose();
}
