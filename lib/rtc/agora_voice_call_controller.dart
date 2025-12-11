import 'package:agora_rtc_engine/agora_rtc_engine.dart';

/// 简单封装声网语音通话控制逻辑。
class AgoraVoiceCallController {
  AgoraVoiceCallController();

  final RtcEngine _engine = createAgoraRtcEngine();

  bool _initialized = false;

  Future<void> initialize({
    required String appId,
    RtcEngineEventHandler? eventHandler,
  }) async {
    if (_initialized) return;

    await _engine.initialize(
      RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );
    if (eventHandler != null) {
      _engine.registerEventHandler(eventHandler);
    }
    await _engine.enableAudio();
    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine.setDefaultAudioRouteToSpeakerphone(true);
    await _engine.enableAudioVolumeIndication(
      interval: 200,
      smooth: 3,
      reportVad: true,
    );
    _initialized = true;
  }

  Future<void> joinChannel({
    required String token,
    required String channelName,
    required int uid,
  }) async {
    await _engine.joinChannel(
      token: token,
      channelId: channelName,
      uid: uid,
      options: const ChannelMediaOptions(),
    );
  }

  Future<void> enableSpeakerphone(bool enabled) async {
    await _engine.setEnableSpeakerphone(enabled);
  }

  Future<void> muteLocalAudio(bool muted) async {
    await _engine.muteLocalAudioStream(muted);
  }

  Future<void> leaveChannel() async {
    await _engine.leaveChannel();
  }

  Future<void> dispose() async {
    if (!_initialized) return;
    await _engine.release();
    _initialized = false;
  }
}
