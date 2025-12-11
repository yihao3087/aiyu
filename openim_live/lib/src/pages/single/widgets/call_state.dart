import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:just_audio/just_audio.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:openim_common/openim_common.dart';
import 'package:openim_live/src/utils/live_utils.dart';
import 'package:openim_live/src/utils/call_background.dart';
import 'package:openim_live/src/utils/foreground_call_service.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sprintf/sprintf.dart';

import '../../../../openim_live.dart';
import '../../../widgets/small_window.dart';
import 'controls.dart';
import 'participant.dart';

abstract class SignalView extends StatefulWidget {
  const SignalView({
    super.key,
    required this.callType,
    required this.initState,
    this.roomID,
    required this.userID,
    required this.callEventSubject,
    this.onDial,
    this.onSyncUserInfo,
    this.onTapCancel,
    this.onTapHangup,
    this.onTapPickup,
    this.onTapReject,
    this.onClose,
    required this.autoPickup,
    this.onBindRoomID,
    this.onWaitingAccept,
    this.onBusyLine,
    this.onStartCalling,
    this.onError,
    this.onRoomDisconnected,
  });
  final CallType callType;
  final CallState initState;
  final String? roomID;
  final String userID;
  final PublishSubject<CallEvent> callEventSubject;
  final Future<SignalingCertificate> Function()? onDial;
  final Future<SignalingCertificate> Function()? onTapPickup;
  final Future Function()? onTapCancel;
  final Future Function(int duration, bool isPositive)? onTapHangup;
  final Future Function()? onTapReject;
  final Function()? onClose;
  final bool autoPickup;
  final Function(String roomID)? onBindRoomID;
  final Function()? onWaitingAccept;
  final Function()? onBusyLine;
  final Function()? onStartCalling;
  final Function()? onRoomDisconnected;
  final Function(dynamic error, dynamic stack)? onError;
  final Future<UserInfo?> Function(String userID)? onSyncUserInfo;
}

abstract class SignalState<T extends SignalView> extends State<T>
    with WidgetsBindingObserver {
  final callStateSubject = BehaviorSubject<CallState>();
  final roomDidUpdateSubject = PublishSubject<Room>();
  late CallState callState;
  late SignalingCertificate certificate;
  String? roomID;
  UserInfo? userInfo;
  StreamSubscription? callEventSub;
  bool minimize = false;
  int duration = 0;
  bool enabledMicrophone = true;
  bool enabledSpeaker = true;

  ParticipantTrack? remoteParticipantTrack;
  ParticipantTrack? localParticipantTrack;

  AudioSession? _audioSession;
  StreamSubscription<AudioInterruptionEvent>? _audioInterruptionSub;
  StreamSubscription<void>? _becomingNoisySub;
  final AudioPlayer _ringPlayer = AudioPlayer();
  bool _ringInitialized = false;
  int _callStartTs = DateTime.now().millisecondsSinceEpoch;
  CallState? _lastNotifiedState;
  String? _lastNotifiedStatus;
  bool _lastNotifiedIsCalling = false;
  String? _lastNotifiedAvatar;

  void _handleBackgroundForState(CallState state) {
    if (state == CallState.calling) {
      unawaited(CallBackgroundManager.start(peerName: _peerDisplayName()));
      unawaited(ForegroundCallService.start(
        peerName: _peerDisplayName(),
        avatarUrl: userInfo?.faceURL,
        startTs: _callStartTs,
        status: StrRes.calling,
        isCalling: true,
      ));
    } else if (state == CallState.connecting || state == CallState.call || state == CallState.beCalled) {
      unawaited(ForegroundCallService.start(
        peerName: _peerDisplayName(),
        avatarUrl: userInfo?.faceURL,
        startTs: DateTime.now().millisecondsSinceEpoch,
        status: state == CallState.beCalled ? StrRes.invitedYouToCall : StrRes.waitingToAnswer,
        isCalling: false,
      ));
    } else if (_shouldStopBackground(state)) {
      unawaited(CallBackgroundManager.stop());
      unawaited(ForegroundCallService.stop());
    }
    if (state == CallState.beCalled) {
      _startIncomingRing();
    } else {
      _stopIncomingRing();
    }
  }

  bool _shouldStopBackground(CallState state) => {
        CallState.hangup,
        CallState.beHangup,
        CallState.cancel,
        CallState.beCanceled,
        CallState.reject,
        CallState.beRejected,
        CallState.otherReject,
        CallState.otherAccepted,
        CallState.timeout,
        CallState.networkError,
      }.contains(state);

  String _peerDisplayName() {
    final info = userInfo;
    final remark = IMUtils.emptyStrToNull(info?.remark);
    final nickname = IMUtils.emptyStrToNull(info?.nickname);
    return remark ?? nickname ?? widget.userID;
  }

  @override
  void initState() {
    roomID ??= widget.roomID;
    callState = widget.initState;
    WidgetsBinding.instance.addObserver(this);
    _configureAudioSession();
    callEventSub = sameRoomSignalStream.listen(_onStateDidUpdate);
    widget.onSyncUserInfo?.call(widget.userID).then(_onUpdateUserInfo);
    ForegroundCallService.registerNotificationHangupHandler(() async {
      await onTapHangup(true);
    });
    onDail();
    autoPickup();
    if (widget.initState == CallState.beCalled) {
      _startIncomingRing();
    }
    super.initState();
  }

  @override
  void dispose() {
    callStateSubject.close();
    callEventSub?.cancel();
    unawaited(CallBackgroundManager.stop());
    unawaited(ForegroundCallService.stop());
    unawaited(_deactivateAudioSession());
    _audioInterruptionSub?.cancel();
    _becomingNoisySub?.cancel();
    unawaited(_ringPlayer.dispose());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
    ForegroundCallService.clearNotificationHangupHandler();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (callState == CallState.calling) {
      if (state == AppLifecycleState.resumed) {
        _reactivateAudioSession();
      } else if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.inactive ||
          state == AppLifecycleState.detached) {
        unawaited(CallBackgroundManager.start(peerName: _peerDisplayName()));
        unawaited(_audioSession?.setActive(true));
      }
    }
  }

  Future<void> _configureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      _audioSession = session;
      _audioInterruptionSub?.cancel();
      _audioInterruptionSub =
          session.interruptionEventStream.listen((event) async {
        if (event.begin) {
          if (event.type == AudioInterruptionType.duck) {
            return;
          }
          await session.setActive(false);
        } else {
          await session.setActive(true);
          await _restoreAudioOutputs();
        }
      });
      _becomingNoisySub?.cancel();
      _becomingNoisySub =
          session.becomingNoisyEventStream.listen((_) async {
        Logger.print('audio becoming noisy event');
        await _restoreAudioOutputs();
      });
      final options = AVAudioSessionCategoryOptions.allowBluetooth |
          AVAudioSessionCategoryOptions.allowBluetoothA2dp |
          AVAudioSessionCategoryOptions.defaultToSpeaker;
      final config = AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: options,
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
        avAudioSessionSetActiveOptions:
            AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
          flags: AndroidAudioFlags.none,
        ),
        androidAudioFocusGainType:
            AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      );
      await session.configure(config);
      await session.setActive(
        true,
        avAudioSessionSetActiveOptions: config.avAudioSessionSetActiveOptions,
        androidAudioAttributes: config.androidAudioAttributes,
        androidAudioFocusGainType: config.androidAudioFocusGainType,
        androidWillPauseWhenDucked: config.androidWillPauseWhenDucked,
      );
      await _restoreAudioOutputs();
    } catch (e, s) {
      Logger.print('configure audio session failed: $e\n$s');
    }
  }

  Future<void> _deactivateAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (_) {}
  }

  Future<void> _reactivateAudioSession() async {
    try {
      final session = _audioSession ?? await AudioSession.instance;
      await session.setActive(true);
      await _restoreAudioOutputs();
    } catch (e, s) {
      Logger.print('reactivate audio session failed: $e\n$s');
    }
  }

  Future<void> _restoreAudioOutputs() async {
    try {
      await Hardware.instance.setSpeakerphoneOn(enabledSpeaker);
    } catch (e, s) {
      Logger.print('restore speakerphone failed: $e\n$s');
    }
  }

  Stream<CallEvent> get sameRoomSignalStream => widget.callEventSubject.stream
      .where((event) => LiveUtils.isSameRoom(event, roomID));

  void _updateForegroundNotification(CallState state) {
    if (_shouldStopBackground(state)) {
      _lastNotifiedState = null;
      _lastNotifiedStatus = null;
      _lastNotifiedAvatar = null;
      _lastNotifiedIsCalling = false;
      unawaited(ForegroundCallService.stop());
      return;
    }
    String status;
    bool isCalling = false;
    switch (state) {
      case CallState.calling:
        status = StrRes.calling;
        isCalling = true;
        break;
      case CallState.call:
      case CallState.connecting:
        status = StrRes.waitingToAnswer;
        break;
      case CallState.beCalled:
        status = StrRes.invitedYouToCall;
        break;
      default:
        status = StrRes.calling;
    }
    final avatar = userInfo?.faceURL;
    if (_lastNotifiedState == state &&
        _lastNotifiedStatus == status &&
        _lastNotifiedIsCalling == isCalling &&
        _lastNotifiedAvatar == avatar) {
      return;
    }
    _lastNotifiedState = state;
    _lastNotifiedStatus = status;
    _lastNotifiedIsCalling = isCalling;
    _lastNotifiedAvatar = avatar;
    unawaited(ForegroundCallService.start(
      peerName: _peerDisplayName(),
      avatarUrl: avatar,
      startTs: isCalling ? _callStartTs : DateTime.now().millisecondsSinceEpoch,
      status: status,
      isCalling: isCalling,
    ));
  }
  _onUpdateUserInfo(UserInfo? info) {
    if (!mounted && null != info) return;
    setState(() {
      userInfo = info;
    });
  }

  _onStateDidUpdate(CallEvent event) {
    Logger.print("CallEvent current閿?callState  event閿?event");
    if (!mounted) return;

    if (event.state == CallState.call ||
        event.state == CallState.beCalled ||
        event.state == CallState.connecting ||
        event.state == CallState.calling) {
      callStateSubject.add(event.state);
    }

    if (event.state == CallState.beRejected ||
        event.state == CallState.beCanceled) {
      widget.onClose?.call();
    } else if (event.state == CallState.otherReject ||
        event.state == CallState.otherAccepted) {
      if (existParticipants()) {
        return;
      }
      widget.onClose?.call();
      IMViews.showToast(sprintf(StrRes.otherCallHandle, [
        event.state == CallState.otherReject ? StrRes.rejectCall : StrRes.accept
      ]));
    } else if (event.state == CallState.timeout) {
      widget.onClose?.call();
    } else if (event.state == CallState.beAccepted) {
      if (null != remoteParticipantTrack) {
        onParticipantConnected();
      }
    }
    _updateForegroundNotification(event.state);
    _handleBackgroundForState(event.state);
  }

  onParticipantConnected() {
    _callStartTs = DateTime.now().millisecondsSinceEpoch;
    callStateSubject.add(CallState.calling);
    widget.onStartCalling?.call();
    _handleBackgroundForState(CallState.calling);
    unawaited(_restoreAudioOutputs());
  }

  onParticipantDisconnected() {
    onTapHangup(false);
  }

  onDail() async {
    if (widget.initState == CallState.call) {
      // callStateSubject.add(CallState.connecting);
      certificate = await widget.onDial!.call();
      widget.onBindRoomID?.call(roomID = certificate.roomID!);
      await connect();
    }
  }

  autoPickup() {
    if (widget.autoPickup) {
      onTapPickup();
    }
  }

  onTapPickup() async {
    Logger.print('connecting');
    callStateSubject.add(CallState.connecting);
    _stopIncomingRing();
    certificate = await widget.onTapPickup!.call();
    widget.onBindRoomID?.call(roomID = certificate.roomID!);
    await connect();
    callStateSubject.add(CallState.calling);
    widget.onStartCalling?.call();
    _callStartTs = DateTime.now().millisecondsSinceEpoch;
    _handleBackgroundForState(CallState.calling);
    unawaited(_restoreAudioOutputs());
    Logger.print('connected');
  }

  onTapHangup(bool isPositive) async {
    _stopIncomingRing();
    await widget.onTapHangup
        ?.call(duration, isPositive)
        .whenComplete(() => /*isPositive ? {} : */ widget.onClose?.call());
  }

  onTapCancel() async {
    _stopIncomingRing();
    await widget.onTapCancel?.call().whenComplete(() => widget.onClose?.call());
  }

  onTapReject() async {
    _stopIncomingRing();
    await widget.onTapReject?.call().whenComplete(() => widget.onClose?.call());
  }

  Future<void> onTapMinimize() async {
    if (!mounted) return;
    setState(() {
      minimize = true;
    });
  }

  Future<void> _startIncomingRing() async {
    if (_ringPlayer.playing) return;
    try {
      if (!_ringInitialized) {
        await _ringPlayer.setAsset('assets/audio/live_ring.wav',
            package: 'openim_common');
        await _ringPlayer.setLoopMode(LoopMode.all);
        _ringInitialized = true;
      }
      await _ringPlayer.play();
    } catch (e, s) {
      Logger.print('start incoming ring failed: $e\n$s');
    }
  }

  Future<void> _stopIncomingRing() async {
    if (_ringPlayer.playing) {
      await _ringPlayer.stop();
    }
  }

  onTapMaximize() {
    setState(() {
      minimize = false;
    });
  }

  callingDuration(int duration) {
    this.duration = duration;
  }

  onChangedMicStatus(bool enabled) {
    enabledMicrophone = enabled;
  }

  onChangedSpeakerStatus(bool enabled) {
    enabledSpeaker = enabled;
    unawaited(_restoreAudioOutputs());
  }

  //Alignment(0.9, -0.9),
  double alignX = 0.9;
  double alignY = -0.9;

  Alignment get moveAlign => Alignment(alignX, alignY);

  onMoveSmallWindow(DragUpdateDetails details) {
    final globalDy = details.globalPosition.dy;
    final globalDx = details.globalPosition.dx;
    setState(() {
      alignX = (globalDx - .5.sw) / .5.sw;
      alignY = (globalDy - .5.sh) / .5.sh;
    });
  }

  Future<void> connect();

  bool existParticipants();

  bool smallScreenIsRemote = true;

  @override
  Widget build(BuildContext context) {
    return Stack(
        children: [
          AnimatedScale(
            scale: minimize ? 0 : 1,
            alignment: moveAlign,
            duration: const Duration(milliseconds: 200),
            onEnd: () {},
            child: Container(
              color: Styles.c_000000,
              child: Stack(
                children: [
                  // ImageRes.liveBg.toImage
                  //   ..fit = BoxFit.cover
                  //   ..width = 1.sw
                  //   ..height = 1.sh,
                  if (null != remoteParticipantTrack)
                    ParticipantWidget.widgetFor(smallScreenIsRemote
                        ? remoteParticipantTrack!
                        : localParticipantTrack!),

                  if (null != localParticipantTrack)
                    Positioned(
                      top: 97.h,
                      right: 12.w,
                      child: GestureDetector(
                        child: SizedBox(
                          width: 120.w,
                          height: 180.h,
                          child: ParticipantWidget.widgetFor(smallScreenIsRemote
                              ? localParticipantTrack!
                              : remoteParticipantTrack!),
                        ),
                        onTap: () {
                          if (remoteParticipantTrack != null) {
                            setState(() {
                              smallScreenIsRemote = !smallScreenIsRemote;
                            });
                          }
                        },
                      ),
                    ),

                  ControlsView(
                    callStateStream: callStateSubject.stream,
                    roomDidUpdateStream: roomDidUpdateSubject.stream,
                    initState: widget.initState,
                    callType: widget.callType,
                    userInfo: userInfo,
                    onMinimize: onTapMinimize,
                    onCallingDuration: callingDuration,
                    onEnabledMicrophone: onChangedMicStatus,
                    onEnabledSpeaker: onChangedSpeakerStatus,
                    onHangUp: onTapHangup,
                    onPickUp: onTapPickup,
                    onReject: onTapReject,
                    onCancel: onTapCancel,
                    onChangedCallState: (state) => callState = state,
                  ),
                ],
              ),
            ),
          ),
          if (minimize)
            Align(
              alignment: moveAlign,
              child: AnimatedOpacity(
                opacity: minimize ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: SmallWindowView(
                  opacity: minimize ? 1 : 0,
                  userInfo: userInfo,
                  callState: callState,
                  onTapMaximize: onTapMaximize,
                  onPanUpdate: onMoveSmallWindow,
                  child: (state) {
                    // if (null != remoteParticipantTrack &&
                    //     state == CallState.calling &&
                    //     widget.callType == CallType.video) {
                    //   return SizedBox(
                    //     width: 120.w,
                    //     height: 180.h,
                    //     child: ParticipantWidget.widgetFor(
                    //         remoteParticipantTrack!),
                    //   );
                    // }
                    return null;
                  },
                ),
              ),
            ),
        ],
      );
  }







}
