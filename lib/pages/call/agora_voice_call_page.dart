import 'dart:async';
import 'dart:math' as math;

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:openim/config/agora_config.dart';
import 'package:openim/rtc/agora_token_service.dart';
import 'package:openim/rtc/agora_voice_call_controller.dart';
import 'package:openim_common/openim_common.dart';
import 'package:permission_handler/permission_handler.dart';

class AgoraVoiceCallPage extends StatefulWidget {
  const AgoraVoiceCallPage({
    super.key,
    required this.channelName,
    required this.localUid,
    required this.remoteUserId,
    this.onCallEnded,
    this.isIncomingCall = false,
  });

  final String channelName;
  final int localUid;
  final String remoteUserId;
  final VoidCallback? onCallEnded;
  final bool isIncomingCall;

  @override
  State<AgoraVoiceCallPage> createState() => _AgoraVoiceCallPageState();
}

enum _CallPhase {
  initializing,
  waitingAccept,
  connecting,
  ringing,
  inCall,
  reconnecting,
  ended,
}

enum _BannerType { warning, error }

class _NetworkBanner {
  const _NetworkBanner(this.type, this.message);
  final _BannerType type;
  final String message;
}

enum _NetworkLevel { checking, good, medium, poor, offline }

class _AgoraVoiceCallPageState extends State<AgoraVoiceCallPage>
    with TickerProviderStateMixin {
  final AgoraVoiceCallController _controller = AgoraVoiceCallController();
  final AgoraTokenService _tokenService = AgoraTokenService();

  bool _remoteJoined = false;
  bool _isMuted = false;
  bool _speakerOn = true;
  bool _callStarted = false;
  late bool _hasAccepted;
  double _volumeIntensity = 0;
  bool _callEnded = false;

  _CallPhase _phase = _CallPhase.initializing;
  _NetworkBanner? _banner;
  Timer? _bannerTimer;
  bool _showReconnectingOverlay = false;
  Timer? _autoReconnectTimer;
  bool _isAutoReconnecting = false;
  int _reconnectAttempts = 0;

  late final AnimationController _avatarFloatCtrl;
  late final AnimationController _waveCtrl;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  ConnectivityResult? _connectivityResult;
  _NetworkLevel _localNetworkLevel = _NetworkLevel.checking;
  _NetworkLevel _remoteNetworkLevel = _NetworkLevel.checking;

  @override
  void initState() {
    super.initState();
    _hasAccepted = !widget.isIncomingCall;
    _phase = widget.isIncomingCall ? _CallPhase.waitingAccept : _CallPhase.initializing;
    _avatarFloatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    Connectivity()
        .checkConnectivity()
        .then((values) => _handleConnectivityChange(
              values.isNotEmpty ? values.first : ConnectivityResult.none,
            ));
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((values) => _handleConnectivityChange(
              values.isNotEmpty ? values.first : ConnectivityResult.none,
            ));
    HapticFeedback.mediumImpact();
    if (!_showAcceptButton) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startCallFlow();
      });
    }
  }

  @override
  void dispose() {
    _avatarFloatCtrl.dispose();
    _waveCtrl.dispose();
    _bannerTimer?.cancel();
    _autoReconnectTimer?.cancel();
    _connectivitySub?.cancel();
    unawaited(_controller.leaveChannel());
    unawaited(_controller.dispose());
    super.dispose();
  }

  bool get _showAcceptButton => widget.isIncomingCall && !_hasAccepted;

  Future<void> _startCallFlow() async {
    if (_callStarted) return;
    _callStarted = true;
    setState(() {
      _phase = _CallPhase.connecting;
    });

    if (!AgoraConfig.isConfigured) {
      IMViews.showToast('语音通话未配置，请联系管理员');
      _leaveAndPop();
      return;
    }

    final status = await Permissions.requestSingle(Permission.microphone);
    if (!status.isGranted) {
      IMViews.showToast(StrRes.permissionDeniedTitle);
      _setPhase(_CallPhase.ended);
      _leaveAndPop();
      return;
    }

    try {
      await _controller.initialize(
        appId: AgoraConfig.agoraAppId,
        eventHandler: RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            if (!mounted) return;
            setState(() {
              if (!_remoteJoined) {
                _phase = _CallPhase.ringing;
              }
            });
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            if (!mounted) return;
            HapticFeedback.selectionClick();
            setState(() {
              _remoteJoined = true;
              _phase = _CallPhase.inCall;
              _banner = null;
            });
          },
          onUserOffline: (
            RtcConnection connection,
            int remoteUid,
            UserOfflineReasonType reason,
          ) {
            _handleRemoteOffline(reason);
          },
          onConnectionStateChanged: (
            RtcConnection connection,
            ConnectionStateType state,
            ConnectionChangedReasonType reason,
          ) {
            _handleConnectionState(state, reason);
          },
          onError: (ErrorCodeType error, String message) {
            Logger.print('[AgoraVoiceCall] onError: $error, $message');
            if (mounted) {
              IMViews.showToast('${StrRes.callFail} ($error)');
            }
            _leaveAndPop();
          },
          onNetworkQuality: (
            RtcConnection connection,
            int remoteUid,
            QualityType txQuality,
            QualityType rxQuality,
          ) {
            _handleNetworkQuality(remoteUid, txQuality, rxQuality);
          },
          onAudioVolumeIndication: (
            RtcConnection connection,
            List<AudioVolumeInfo> speakers,
            int speakerNumber,
            int totalVolume,
          ) {
            _handleVolumeIndication(speakers, totalVolume);
          },
        ),
      );
      if (!mounted) return;

      final token = await _acquireRtcToken();
      await _controller.joinChannel(
        token: token,
        channelName: widget.channelName,
        uid: widget.localUid,
      );
      await _controller.enableSpeakerphone(_speakerOn);
    } on AgoraTokenException catch (e) {
      IMViews.showToast(e.message);
      _leaveAndPop();
    } on AgoraRtcException catch (e, s) {
      Logger.print('[AgoraVoiceCall] joinChannel exception: $e\n$s');
      final code = e.code;
      final message = e.message;
      final detail =
          message == null || message.isEmpty ? '$code' : '$code - $message';
      IMViews.showToast('${StrRes.callFail}: $detail');
      _leaveAndPop();
    } catch (e) {
      Logger.print('[AgoraVoiceCall] unexpected error: $e');
      IMViews.showToast('${StrRes.callFail}: $e');
      _leaveAndPop();
    }
  }

  void _handleConnectionState(
    ConnectionStateType state,
    ConnectionChangedReasonType reason,
  ) {
    if (!mounted) return;
    switch (state) {
      case ConnectionStateType.connectionStateReconnecting:
        setState(() {
          _showReconnectingOverlay = true;
          _phase = _CallPhase.reconnecting;
        });
        _showBanner(
          _BannerType.warning,
          StrRes.voiceCallRestoring,
          persistent: true,
        );
        break;
      case ConnectionStateType.connectionStateConnected:
        setState(() {
          _showReconnectingOverlay = false;
          if (_remoteJoined) {
            _phase = _CallPhase.inCall;
          } else if (_callStarted) {
            _phase = _CallPhase.ringing;
          }
        });
        _hideBanner();
        break;
      case ConnectionStateType.connectionStateDisconnected:
        _handleConnectionInterrupted(reason);
        break;
      case ConnectionStateType.connectionStateFailed:
        if (_shouldAutoReconnect(reason)) {
          _handleConnectionInterrupted(reason);
        } else {
          IMViews.showToast(StrRes.callFail);
          _leaveAndPop();
        }
        break;
      default:
        break;
    }
  }

  void _handleNetworkQuality(
    int uid,
    QualityType tx,
    QualityType rx,
  ) {
    final merged = _worstQuality(tx, rx);
    final level = _withConnectivityOverride(_networkLevelFromQuality(merged));
    if (!mounted) return;
    setState(() {
      if (uid == 0 || uid == widget.localUid) {
        _localNetworkLevel = level;
      } else {
        _remoteNetworkLevel = level;
      }
    });
    if (level == _NetworkLevel.poor || merged == QualityType.qualityDown) {
      _showBanner(
        _BannerType.warning,
        merged == QualityType.qualityDown
            ? StrRes.voiceCallNetworkInterrupted
            : StrRes.voiceCallNetworkPoor,
      );
      if (_shouldAutoReconnect(
        ConnectionChangedReasonType.connectionChangedLost,
      )) {
        _scheduleAutoReconnect();
      }
    } else if (level == _NetworkLevel.medium) {
      _showBanner(_BannerType.warning, StrRes.voiceCallNetworkNormal);
    } else if (_banner?.type == _BannerType.warning) {
      _hideBanner();
    }
  }

  void _handleRemoteOffline(UserOfflineReasonType reason) {
    if (!mounted || _callEnded) return;
    _callEnded = true;
    setState(() {
      _remoteJoined = false;
      _phase = _CallPhase.ended;
    });
    _leaveAndPop();
  }

  void _handleConnectivityChange(ConnectivityResult result) {
    if (!mounted) return;
    setState(() {
      _connectivityResult = result;
      _localNetworkLevel = result == ConnectivityResult.none
          ? _NetworkLevel.offline
          : _withConnectivityOverride(_localNetworkLevel);
    });
    if (result == ConnectivityResult.none) {
      _showBanner(
        _BannerType.error,
        StrRes.voiceCallNetworkInterrupted,
        persistent: true,
      );
      setState(() {
        _showReconnectingOverlay = true;
        _phase = _CallPhase.reconnecting;
      });
    } else if (_showReconnectingOverlay || _isAutoReconnecting) {
      _scheduleAutoReconnect(delay: const Duration(milliseconds: 300));
    }
  }

  void _handleConnectionInterrupted(ConnectionChangedReasonType reason) {
    final needReconnect = _shouldAutoReconnect(reason);
    if (needReconnect) {
      setState(() {
        _showReconnectingOverlay = true;
        _phase = _CallPhase.reconnecting;
      });
      _showBanner(
        _BannerType.error,
        StrRes.voiceCallNetworkInterrupted,
        persistent: true,
      );
      _scheduleAutoReconnect();
      return;
    }
    setState(() {
      _showReconnectingOverlay = false;
      _phase = _CallPhase.ended;
    });
    _showBanner(
      _BannerType.error,
      StrRes.voiceCallNetworkInterrupted,
      persistent: true,
    );
    _leaveAndPop();
  }

  bool _shouldAutoReconnect(ConnectionChangedReasonType reason) {
    switch (reason) {
      case ConnectionChangedReasonType.connectionChangedInterrupted:
      case ConnectionChangedReasonType.connectionChangedClientIpAddressChanged:
      case ConnectionChangedReasonType
            .connectionChangedClientIpAddressChangedByUser:
      case ConnectionChangedReasonType.connectionChangedKeepAliveTimeout:
      case ConnectionChangedReasonType.connectionChangedLost:
        return true;
      default:
        return false;
    }
  }

  void _scheduleAutoReconnect({Duration delay = const Duration(seconds: 1)}) {
    if (_callEnded || !_callStarted || _isAutoReconnecting) return;
    _autoReconnectTimer?.cancel();
    _autoReconnectTimer = Timer(delay, _performAutoReconnect);
  }

  Future<void> _performAutoReconnect() async {
    if (_isAutoReconnecting || _callEnded || !mounted) return;
    _isAutoReconnecting = true;
    setState(() {
      _showReconnectingOverlay = true;
      _phase = _CallPhase.reconnecting;
    });
    try {
      _reconnectAttempts += 1;
      await _controller.leaveChannel();
      final token = await _acquireRtcToken();
      await _controller.joinChannel(
        token: token,
        channelName: widget.channelName,
        uid: widget.localUid,
      );
      await _controller.enableSpeakerphone(_speakerOn);
      setState(() {
        _showReconnectingOverlay = false;
        if (_remoteJoined) {
          _phase = _CallPhase.inCall;
        } else {
          _phase = _CallPhase.ringing;
        }
      });
      _reconnectAttempts = 0;
      _hideBanner();
    } catch (e, s) {
      Logger.print('[AgoraVoiceCall] auto reconnect failed: $e\n$s');
      if (_reconnectAttempts < 3 && mounted) {
        _isAutoReconnecting = false;
        final delaySeconds = math.min(4, 1 << _reconnectAttempts);
        _scheduleAutoReconnect(
          delay: Duration(seconds: delaySeconds),
        );
        return;
      }
      IMViews.showToast(StrRes.voiceCallNetworkInterrupted);
      _leaveAndPop();
    } finally {
      _isAutoReconnecting = false;
    }
  }

  Future<String> _acquireRtcToken() async {
    final token = await _tokenService.fetchRtcToken(
      channelName: widget.channelName,
      uid: widget.localUid,
    );
    return token;
  }

  QualityType _worstQuality(QualityType tx, QualityType rx) {
    final maxIndex = math.max(tx.index, rx.index);
    final safeIndex =
        maxIndex.clamp(0, QualityType.values.length - 1).toInt();
    return QualityType.values[safeIndex];
  }

  _NetworkLevel _networkLevelFromQuality(QualityType quality) {
    if (quality == QualityType.qualityUnknown) {
      return _NetworkLevel.checking;
    }
    if (quality.index <= QualityType.qualityGood.index) {
      return _NetworkLevel.good;
    }
    if (quality.index <= QualityType.qualityBad.index) {
      return _NetworkLevel.medium;
    }
    if (quality == QualityType.qualityDown) {
      return _NetworkLevel.offline;
    }
    return _NetworkLevel.poor;
  }

  _NetworkLevel _withConnectivityOverride(_NetworkLevel level) {
    if (_connectivityResult == ConnectivityResult.none) {
      return _NetworkLevel.offline;
    }
    return level;
  }

  String _networkStatusText(_NetworkLevel level) {
    switch (level) {
      case _NetworkLevel.good:
        return StrRes.voiceCallNetworkGood;
      case _NetworkLevel.medium:
        return StrRes.voiceCallNetworkNormal;
      case _NetworkLevel.poor:
        return StrRes.voiceCallNetworkPoor;
      case _NetworkLevel.offline:
        return StrRes.voiceCallNetworkInterrupted;
      case _NetworkLevel.checking:
        break;
    }
    return StrRes.voiceCallNetworkDetecting;
  }

  Color _networkStatusColor(_NetworkLevel level) {
    switch (level) {
      case _NetworkLevel.good:
        return Colors.greenAccent;
      case _NetworkLevel.medium:
        return Colors.orangeAccent;
      case _NetworkLevel.poor:
      case _NetworkLevel.offline:
        return Colors.redAccent;
      case _NetworkLevel.checking:
        break;
    }
    return Colors.white54;
  }


  void _showBanner(
    _BannerType type,
    String message, {
    bool persistent = false,
  }) {
    _bannerTimer?.cancel();
    setState(() {
      _banner = _NetworkBanner(type, message);
    });
    if (!persistent) {
      _bannerTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && _banner?.message == message) {
          setState(() {
            _banner = null;
          });
        }
      });
    }
  }

  void _hideBanner() {
    _bannerTimer?.cancel();
    if (_banner == null) return;
    setState(() {
      _banner = null;
    });
  }

  void _setPhase(_CallPhase phase) {
    if (!mounted || _phase == phase) return;
    setState(() {
      _phase = phase;
    });
  }

  void _leaveAndPop() {
    if (_callEnded) return;
    _callEnded = true;
    widget.onCallEnded?.call();
    final navigator = Get.key.currentState;
    if (navigator?.canPop() ?? false) {
      navigator?.pop();
    }
  }

  Future<void> _acceptCall() async {
    if (!_showAcceptButton) return;
    HapticFeedback.lightImpact();
    setState(() {
      _hasAccepted = true;
    });
    await _startCallFlow();
  }

  Future<void> _toggleMute() async {
    final muted = !_isMuted;
    await _controller.muteLocalAudio(muted);
    if (!mounted) return;
    setState(() {
      _isMuted = muted;
    });
  }

  Future<void> _toggleSpeaker() async {
    final speakerOn = !_speakerOn;
    await _controller.enableSpeakerphone(speakerOn);
    if (!mounted) return;
    setState(() {
      _speakerOn = speakerOn;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Styles.c_0C1C33,
      appBar: AppBar(
        backgroundColor: Styles.c_0C1C33,
        elevation: 0,
        title: Text(StrRes.callVoice, style: Styles.ts_FFFFFF_18sp_medium),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            HapticFeedback.heavyImpact();
            _leaveAndPop();
          },
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildAnimatedAvatar(),
                        const SizedBox(height: 24),
                        Text(
                          widget.remoteUserId,
                          style: Styles.ts_FFFFFF_18sp_medium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Text(
                            _statusLabel,
                            key: ValueKey(_statusLabel),
                            style: Styles.ts_FFFFFF_14sp,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildNetworkOverview(),
                        const SizedBox(height: 16),
                        _buildVoiceVisualizer(),
                      ],
                    ),
                  ),
                ),
                _buildControls(),
              ],
            ),
            _buildNetworkBanner(),
            if (_showReconnectingOverlay) _buildReconnectingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedAvatar() {
    return SizedBox(
      width: 180,
      height: 180,
      child: AnimatedBuilder(
        animation: Listenable.merge([_avatarFloatCtrl, _waveCtrl]),
        builder: (context, child) {
          final floatValue = _avatarFloatCtrl.value;
          final translateY = math.sin(floatValue * 2 * math.pi) * 6;
          final waveIntensity = 0.7 + (_volumeIntensity * 0.8);
          return Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                _buildWave(
                  progress: (_waveCtrl.value + i * 0.2) % 1,
                  intensity: waveIntensity,
                ),
              Transform.translate(
                offset: Offset(0, translateY),
                child: Transform.scale(
                  scale: 0.97 + floatValue * 0.06 + _volumeIntensity * 0.05,
                  child: _buildAvatarCore(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNetworkOverview() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NetworkStatusBadge(
          label: StrRes.voiceCallLocalNetwork,
          status: _networkStatusText(_localNetworkLevel),
          color: _networkStatusColor(_localNetworkLevel),
        ),
        const SizedBox(height: 6),
        _NetworkStatusBadge(
          label: StrRes.voiceCallRemoteNetwork,
          status: _networkStatusText(
            _remoteJoined ? _remoteNetworkLevel : _NetworkLevel.checking,
          ),
          color: _networkStatusColor(
            _remoteJoined ? _remoteNetworkLevel : _NetworkLevel.checking,
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceVisualizer() {
    final intensity = _volumeIntensity.clamp(0.0, 1.0);
    return SizedBox(
      height: 32,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (index) {
          final weight = 1 - (index - 2).abs() * 0.2;
          final barHeight = 8 + (intensity * 24 * weight);
          final threshold = index * 0.15;
          final isActive = intensity >= threshold;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: 6,
            height: barHeight,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.white30,
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildWave({
    required double progress,
    double intensity = 1,
  }) {
    final opacity = ((1 - progress) * (0.25 + _volumeIntensity * 0.35))
        .clamp(0.0, 1.0);
    final size = (110 + (progress * 70)) * intensity;
    return Opacity(
      opacity: opacity * 0.35,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
    );
  }

  Widget _buildAvatarCore() {
    final text = widget.remoteUserId.isNotEmpty
        ? widget.remoteUserId.characters.first.toUpperCase()
        : '?';
    return CircleAvatar(
      radius: 56,
      backgroundColor: Styles.c_0089FF.withValues(alpha: 0.25),
      child: Text(text, style: Styles.ts_FFFFFF_20sp_medium),
    );
  }

  Widget _buildControls() {
    final buttons = <Widget>[
      _CircleActionButton(
        icon: _isMuted ? Icons.mic_off : Icons.mic,
        label: _isMuted ? StrRes.voiceCallUnmute : StrRes.voiceCallMute,
        backgroundColor: Colors.white24,
        onTap: _toggleMute,
      ),
      _CircleActionButton(
        icon: _speakerOn ? Icons.volume_up : Icons.hearing,
        label: _speakerOn ? StrRes.voiceCallSpeaker : StrRes.voiceCallEarpiece,
        backgroundColor: Colors.white24,
        onTap: _toggleSpeaker,
      ),
    ];

    if (_showAcceptButton) {
      buttons.add(
        _CircleActionButton(
          icon: Icons.call,
          label: StrRes.acceptCall,
          backgroundColor: Styles.c_18E875,
          onTap: _acceptCall,
        ),
      );
    }

    buttons.add(
      _CircleActionButton(
        icon: Icons.call_end,
        label: StrRes.hangUp,
        backgroundColor: Colors.redAccent,
        onTap: () {
          HapticFeedback.heavyImpact();
          _setPhase(_CallPhase.ended);
          _leaveAndPop();
        },
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 32, left: 24, right: 24, top: 32),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 28,
        runSpacing: 24,
        children: buttons,
      ),
    );
  }

  Widget _buildNetworkBanner() {
    final banner = _banner;
    return Align(
      alignment: Alignment.topCenter,
      child: AnimatedSlide(
        offset: banner == null ? const Offset(0, -0.5) : Offset.zero,
        duration: const Duration(milliseconds: 250),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: banner == null ? 0 : 1,
          child: banner == null
              ? const SizedBox.shrink()
              : Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: banner.type == _BannerType.warning
                        ? Colors.amber.withValues(alpha: 0.9)
                        : Colors.redAccent.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    banner.message,
                    style: Styles.ts_FFFFFF_12sp,
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildReconnectingOverlay() {
    return AnimatedOpacity(
      opacity: _showReconnectingOverlay ? 1 : 0,
      duration: const Duration(milliseconds: 250),
      child: IgnorePointer(
        ignoring: true,
        child: Container(
          color: Colors.black45,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                StrRes.voiceCallRestoring,
                style: Styles.ts_FFFFFF_14sp,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _statusLabel {
    switch (_phase) {
      case _CallPhase.waitingAccept:
        return StrRes.voiceCallIncoming;
      case _CallPhase.connecting:
        return StrRes.voiceCallConnecting;
      case _CallPhase.ringing:
        return widget.isIncomingCall
            ? StrRes.voiceCallIncoming
            : StrRes.voiceCallCalling;
      case _CallPhase.inCall:
        return StrRes.voiceCallInProgress;
      case _CallPhase.reconnecting:
        return StrRes.voiceCallRestoring;
      case _CallPhase.ended:
        return StrRes.voiceCallEnded;
      case _CallPhase.initializing:
        return StrRes.voiceCallConnecting;
    }
  }

  void _handleVolumeIndication(
    List<AudioVolumeInfo> speakers,
    int totalVolume,
  ) {
    if (!mounted || (speakers.isEmpty && totalVolume == 0)) return;
    int remoteVolume = 0;
    for (final info in speakers) {
      if (info.uid != widget.localUid) {
        remoteVolume = math.max(remoteVolume, info.volume ?? 0);
      }
    }
    if (remoteVolume == 0 && speakers.isNotEmpty) {
      remoteVolume = speakers.first.volume ?? 0;
    }
    if (remoteVolume == 0) {
      remoteVolume = totalVolume;
    }
    final normalized = (remoteVolume.clamp(0, 255)) / 255.0;
    final smoothed = (_volumeIntensity * 0.6) + (normalized * 0.4);
    setState(() {
      _volumeIntensity = smoothed.clamp(0.0, 1.0);
    });
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(48),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: backgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Styles.ts_FFFFFF_12sp,
        ),
      ],
    );
  }
}

class _NetworkStatusBadge extends StatelessWidget {
  const _NetworkStatusBadge({
    required this.label,
    required this.status,
    required this.color,
  });

  final String label;
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: Styles.ts_FFFFFF_12sp),
          const SizedBox(width: 6),
          Text(
            status,
            style:
                Styles.ts_FFFFFF_12sp.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
