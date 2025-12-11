import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:common_utils/common_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:openim_common/openim_common.dart';
import 'package:openim_live/openim_live.dart';
import 'package:path/path.dart' as p;
import 'package:pull_to_refresh_new/pull_to_refresh.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sprintf/sprintf.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_compress/video_compress.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:wechat_camera_picker/wechat_camera_picker.dart';

import '../../config/map_config.dart';
import '../../core/controller/app_controller.dart';
import '../../core/controller/im_controller.dart';
import '../../core/im_callback.dart';
import '../../routes/app_navigator.dart';
import '../contacts/select_contacts/select_contacts_logic.dart';
import '../conversation/conversation_logic.dart';
import 'group_setup/group_member_list/group_member_list_logic.dart';

const _groupSearchPageSize = 20;

class ChatLogic extends SuperController {
  final imLogic = Get.find<IMController>();
  final appLogic = Get.find<AppController>();
  final conversationLogic = Get.find<ConversationLogic>();
  final cacheLogic = Get.find<CacheController>();

  final inputCtrl = TextEditingController();
  final focusNode = FocusNode();
  final scrollController = ScrollController();
  final refreshController = RefreshController();
  bool playOnce = false;

  final forceCloseToolbox = PublishSubject<bool>();
  final sendStatusSub = PublishSubject<MsgStreamEv<bool>>();
  final playingVoiceMsgId = ''.obs;
  final voiceProgress = 0.0.obs;
  int _currentVoiceDurationMs = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();
  OverlayEntry? _messageActionOverlay;

  late ConversationInfo conversationInfo;
  Message? searchMessage;
  final nickname = ''.obs;
  final faceUrl = ''.obs;
  Timer? _debounce;
  final messageList = <Message>[].obs;
  final tempMessages = <Message>[];
  final scaleFactor = Config.textScaleFactor.obs;
  final background = "".obs;
  final memberUpdateInfoMap = <String, GroupMembersInfo>{};
  final groupMessageReadMembers = <String, List<String>>{};
  final groupMemberRoleLevel = 1.obs;
  GroupInfo? groupInfo;
  GroupMembersInfo? groupMembersInfo;
  List<GroupMembersInfo> ownerAndAdmin = [];

  final isInGroup = true.obs;
  final memberCount = 0.obs;
  final privateMessageList = <Message>[];
  final isInBlacklist = false.obs;

  final scrollingCacheMessageList = <Message>[];
  final announcement = ''.obs;
  final replyMessage = Rxn<Message>();
  final replyPreview = RxnString();
  final isMultiSelectMode = false.obs;
  final selectedMessageIds = <String>{}.obs;
  final highlightMsgId = RxnString();
  final Map<String, GlobalKey> _messageKeys = {};
  final inlineSearchCtrl = TextEditingController();
  final inlineSearchFocus = FocusNode();
  final inlineSearchResultCount = 0.obs;
  final inlineSearchResultKeyword = ''.obs;
  final groupSearchKeyword = ''.obs;
  final isInlineSearchResultMode = false.obs;
  final groupSearchResults = <Message>[].obs;
  final isGroupSearchLoading = false.obs;
  final isGroupSearchLoadingMore = false.obs;
  final hasMoreGroupSearchResult = false.obs;
  int _groupSearchPageNumber = 1;  int _groupSearchRequestId = 0;
  late StreamSubscription conversationSub;
  late StreamSubscription memberAddSub;
  late StreamSubscription memberDelSub;
  late StreamSubscription joinedGroupAddedSub;
  late StreamSubscription joinedGroupDeletedSub;
  late StreamSubscription memberInfoChangedSub;
  late StreamSubscription groupInfoUpdatedSub;
  late StreamSubscription friendInfoChangedSub;
  StreamSubscription? userStatusChangedSub;
  StreamSubscription? selfInfoUpdatedSub;

  late StreamSubscription connectionSub;
  final syncStatus = IMSdkStatus.syncEnded.obs;
  int? lastMinSeq;

  final showCallingMember = false.obs;

  bool _isStartSyncing = false;
  bool _isFirstLoad = true;
  bool _skipFirstAutoLoad = false;

  final copyTextMap = <String?, String?>{};

  String? groupOwnerID;

  final _pageSize = 40;

  RTCBridge? get rtcBridge => PackageBridge.rtcBridge;

  bool get rtcIsBusy => rtcBridge?.hasConnection == true;

  String? get userID => conversationInfo.userID;

  String? get groupID => conversationInfo.groupID;

  bool get isSingleChat => null != userID && userID!.trim().isNotEmpty;

  bool get isGroupChat => null != groupID && groupID!.trim().isNotEmpty;

  String get memberStr => isSingleChat ? "" : "($memberCount)";

  String? get senderName => isSingleChat
      ? OpenIM.iMManager.userInfo.nickname
      : groupMembersInfo?.nickname;

  bool get isAdminOrOwner =>
      groupMemberRoleLevel.value == GroupRoleLevel.admin ||
      groupMemberRoleLevel.value == GroupRoleLevel.owner;

  final directionalUsers = <GroupMembersInfo>[].obs;

  bool isCurrentChat(Message message) {
    var senderId = message.sendID;
    var receiverId = message.recvID;
    var groupId = message.groupID;

    var isCurSingleChat = message.isSingleChat &&
        isSingleChat &&
        (senderId == userID ||
            senderId == OpenIM.iMManager.userID && receiverId == userID);
    var isCurGroupChat =
        message.isGroupChat && isGroupChat && groupID == groupId;
    return isCurSingleChat || isCurGroupChat;
  }

  void scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      scrollController.jumpTo(0);
    });
  }

  Future<List<Message>> searchMediaMessage() async {
    final messageList =
        await OpenIM.iMManager.messageManager.searchLocalMessages(
      conversationID: conversationInfo.conversationID,
      messageTypeList: [MessageType.picture, MessageType.video],
      count: 500,
    );
    return messageList.searchResultItems?.first.messageList?.reversed
            .toList() ??
        [];
  }

  @override
  void onReady() {
    _resetGroupAtType();
    _clearUnreadCount();

    scrollController.addListener(() {
      focusNode.unfocus();
    });
    super.onReady();
    if (searchMessage != null) {
      _locateSearchMessage();
    }
  }

  @override
  void onInit() {
    var arguments = Get.arguments;
    conversationInfo = arguments['conversationInfo'];
    searchMessage = arguments['searchMessage'];
    _skipFirstAutoLoad = searchMessage != null;
    nickname.value = conversationInfo.showName ?? '';
    faceUrl.value = conversationInfo.faceURL ?? '';
    scrollController.addListener(_onScroll);
    _initChatConfig();
    _setSdkSyncDataListener();
    _setupAudioPlayer();

    conversationSub = imLogic.conversationChangedSubject.listen((value) {
      final obj = value.firstWhereOrNull(
        (e) => e.conversationID == conversationInfo.conversationID,
      );

      if (obj != null) {
        conversationInfo = obj;
      }
    });

    imLogic.onRecvNewMessage = (Message message) async {
      if (_isInlineSearchMode) {
        return;
      }
      if (isCurrentChat(message)) {
        if (message.contentType == MessageType.typing) {
        } else {
          if (!messageList.contains(message) &&
              !scrollingCacheMessageList.contains(message)) {
            if (scrollController.offset != 0) {
              scrollingCacheMessageList.add(message);
            } else {
              messageList.add(message);
              scrollBottom();
            }
          }
        }
      }
    };

    imLogic.onRecvMessageRevoked = (RevokedInfo info) async {
      if (_isInlineSearchMode) return;
      final index =
          messageList.indexWhere((m) => m.clientMsgID == info.clientMsgID);
      if (index != -1) {
        await _loadHistoryForSyncEnd();
      }
    };

    imLogic.onRecvC2CReadReceipt = (List<ReadReceiptInfo> list) {
      try {
        for (var readInfo in list) {
          if (readInfo.userID == userID) {
            for (var e in messageList) {
              if (readInfo.msgIDList?.contains(e.clientMsgID) == true) {
                e.isRead = true;
                e.hasReadTime = _timestamp;
              }
            }
          }
        }
        messageList.refresh();
      } catch (e) {
        Logger.print('onRecvC2CReadReceipt error: $e');
      }
    };

    joinedGroupAddedSub = imLogic.joinedGroupAddedSubject.listen((event) {
      if (event.groupID == groupID) {
        isInGroup.value = true;
        _queryGroupInfo();
      }
    });

    joinedGroupDeletedSub = imLogic.joinedGroupDeletedSubject.listen((event) {
      if (event.groupID == groupID) {
        isInGroup.value = false;
        inputCtrl.clear();
      }
    });

    memberAddSub = imLogic.memberAddedSubject.listen((info) {
      var groupId = info.groupID;
      if (groupId == groupID) {
        _putMemberInfo([info]);
      }
    });

    memberDelSub = imLogic.memberDeletedSubject.listen((info) {
      if (info.groupID == groupID && info.userID == OpenIM.iMManager.userID) {
        isInGroup.value = false;
        inputCtrl.clear();
      }
    });

    memberInfoChangedSub = imLogic.memberInfoChangedSubject.listen((info) {
      if (info.groupID == groupID) {
        if (info.userID == OpenIM.iMManager.userID) {
          groupMemberRoleLevel.value = info.roleLevel ?? GroupRoleLevel.member;
          groupMembersInfo = info;
          ();
        }
        _putMemberInfo([info]);

        final index = ownerAndAdmin.indexWhere(
          (element) => element.userID == info.userID,
        );
        if (info.roleLevel == GroupRoleLevel.member) {
          if (index > -1) {
            ownerAndAdmin.removeAt(index);
          }
        } else if (info.roleLevel == GroupRoleLevel.admin ||
            info.roleLevel == GroupRoleLevel.owner) {
          if (index == -1) {
            ownerAndAdmin.add(info);
          } else {
            ownerAndAdmin[index] = info;
          }
        }

        for (var msg in messageList) {
          if (msg.sendID == info.userID) {
            if (msg.isNotificationType) {
              final map = json.decode(msg.notificationElem!.detail!);
              final ntf = GroupNotification.fromJson(map);
              ntf.opUser?.nickname = info.nickname;
              ntf.opUser?.faceURL = info.faceURL;
              msg.notificationElem?.detail = jsonEncode(ntf);
            } else {
              msg.senderFaceUrl = info.faceURL;
              msg.senderNickname = info.nickname;
            }
          }
        }

        messageList.refresh();
      }
    });

    groupInfoUpdatedSub = imLogic.groupInfoUpdatedSubject.listen((value) {
      if (groupID == value.groupID) {
        groupInfo = value;
        nickname.value = value.groupName ?? '';
        faceUrl.value = value.faceURL ?? '';
        memberCount.value = value.memberCount ?? 0;
      }
    });

    friendInfoChangedSub = imLogic.friendInfoChangedSubject.listen((value) {
      if (userID == value.userID) {
        nickname.value = value.getShowName();
        faceUrl.value = value.faceURL ?? '';

        for (var msg in messageList) {
          if (msg.sendID == value.userID) {
            msg.senderFaceUrl = value.faceURL;
            msg.senderNickname = value.nickname;
          }
        }

        messageList.refresh();
      }
    });

    selfInfoUpdatedSub = imLogic.selfInfoUpdatedSubject.listen((value) {
      for (var msg in messageList) {
        if (msg.sendID == value.userID) {
          msg.senderFaceUrl = value.faceURL;
          msg.senderNickname = value.nickname;
        }
      }

      messageList.refresh();
    });

    inputCtrl.addListener(() {
      sendTypingMsg(focus: true);
      if (_debounce?.isActive ?? false) _debounce?.cancel();

      _debounce = Timer(1.seconds, () {
        sendTypingMsg(focus: false);
      });
    });

    focusNode.addListener(() {
      focusNodeChanged(focusNode.hasFocus);
    });

    imLogic.onSignalingMessage = (value) {
      if (value.userID == userID) {
        messageList.add(value.message);
        scrollBottom();
      }
    };

    super.onInit();
  }

  Future chatSetup() => isSingleChat
      ? AppNavigator.startChatSetup(conversationInfo: conversationInfo)
      : AppNavigator.startGroupChatSetup(conversationInfo: conversationInfo);

  void _putMemberInfo(List<GroupMembersInfo>? list) {
    list?.forEach((member) {
      memberUpdateInfoMap[member.userID!] = member;
    });

    messageList.refresh();
  }

  void sendTextMsg() async {
    final content = IMUtils.safeTrim(inputCtrl.text);
    if (content.isEmpty) return;
    Message message;
    final replyTarget = replyMessage.value;
    if (replyTarget != null) {
      message = await OpenIM.iMManager.messageManager.createQuoteMessage(
        text: content,
        quoteMsg: replyTarget,
      );
      clearReply(showToast: false);
    } else {
      message = await OpenIM.iMManager.messageManager.createTextMessage(
        text: content,
      );
    }

    _sendMessage(message);
  }

  Future sendPicture({required String path, bool sendNow = true}) async {
    final file = await IMUtils.compressImageAndGetFile(File(path));

    var message = await OpenIM.iMManager.messageManager
        .createImageMessageFromFullPath(imagePath: file!.path);

    if (sendNow) {
      return _sendMessage(message);
    } else {
      messageList.add(message);
      tempMessages.add(message);
    }
  }

  void onVoiceRecordCompleted(ChatVoiceRecordResult result) async {
    try {
      final message =
          await OpenIM.iMManager.messageManager.createSoundMessageFromFullPath(
        soundPath: result.path,
        duration: result.duration,
      );
      _sendMessage(message);
    } catch (e, s) {
      Logger.print('send voice error: $e $s');
      IMViews.showToast(StrRes.sendFailed);
    }
  }

  Future<void> onTapCamera() async {
    try {
      final AssetEntity? entity = await CameraPicker.pickFromCamera(
        Get.context!,
        locale: Get.locale,
        pickerConfig: CameraPickerConfig(
          enableAudio: true,
          enableRecording: true,
          enableScaledPreview: false,
          maximumRecordingDuration: const Duration(minutes: 5),
          onMinimumRecordDurationNotMet: () {
            IMViews.showToast(StrRes.tapTooShort);
          },
        ),
      );
      if (entity == null) return;
      final file = await entity.file;
      if (file == null) return;
      if (entity.type == AssetType.video) {
        await _sendVideo(asset: entity, file: file);
      } else {
        await sendPicture(path: file.path);
      }
    } catch (e, s) {
      Logger.print('capture media error: $e $s');
      IMViews.showToast(StrRes.sendFailed);
    }
  }

  Future<void> onTapFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.single;
      if (picked.path == null) return;
      final file = File(picked.path!);
      final size = await file.length();
      const maxSize = 200 * 1024 * 1024;
      if (size > maxSize) {
        IMViews.showToast(StrRes.fileTooLarge200);
        return;
      }
      final message =
          await OpenIM.iMManager.messageManager.createFileMessageFromFullPath(
        filePath: file.path,
        fileName: picked.name,
      );
      _sendMessage(message);
    } catch (e, s) {
      Logger.print('pick file error: $e $s');
      IMViews.showToast(StrRes.sendFailed);
    }
  }

  Future<void> onTapLocation() async {
    debugPrint('ChatLogic.onTapLocation invoked');
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        IMViews.showToast(StrRes.locationServiceDisabled);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          IMViews.showToast(StrRes.permissionDeniedTitle);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        IMViews.showToast(StrRes.permissionDeniedTitle);
        return;
      }
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(const Duration(seconds: 6));
      } on TimeoutException catch (_) {
        position = await Geolocator.getLastKnownPosition();
      } catch (e, s) {
        Logger.print('current position error: $e $s');
        position = await Geolocator.getLastKnownPosition();
      }
      if (position == null) {
        IMViews.showToast(StrRes.getLocationFailed);
        return;
      }
      var address = '';
      var title = StrRes.location;
      final webKey = MapConfig.amapWebKey;
      if (webKey == null) {
        Logger.print('amap web key missing, skip reverse geocode & static map');
        IMViews.showToast(StrRes.amapKeyMissing);
      } else {
        try {
          final response = await dio.get<Map<String, dynamic>>(
            'https://restapi.amap.com/v3/geocode/regeo',
            queryParameters: {
              'key': webKey,
              'location':
                  '${position.longitude.toStringAsFixed(6)},${position.latitude.toStringAsFixed(6)}',
              'radius': 100,
              'extensions': 'all',
              'output': 'JSON',
            },
          );
          final data = response.data;
          if (data != null && data['status'] == '1') {
            final regeocode = data['regeocode'] as Map<String, dynamic>?;
            address = (regeocode?['formatted_address'] as String?) ?? address;
            final pois = regeocode?['pois'];
            if (pois is List && pois.isNotEmpty) {
              title = (pois.first as Map<String, dynamic>)['name'] as String? ??
                  title;
            } else {
              final comp =
                  regeocode?['addressComponent'] as Map<String, dynamic>?;
              final township = comp?['township'] as String?;
              final streetInfo = comp?['streetNumber'] as Map<String, dynamic>?;
              final street = streetInfo?['street'] as String?;
              if (title == StrRes.location) {
                title = [
                  township,
                  street,
                  address,
                ].whereType<String>().firstWhere(
                      (e) => e.isNotEmpty,
                      orElse: () => StrRes.location,
                    );
              }
            }
          }
        } catch (e, s) {
          Logger.print('amap reverse geocode failed: $e $s');
        }
      }
      if (title.isEmpty) {
        title = address.isNotEmpty ? address : StrRes.location;
      }
      final provider = webKey == null ? 'geolocator' : 'amap_static';
      final payload = <String, dynamic>{
        'provider': provider,
        'title': title,
        if (address.isNotEmpty) 'address': address,
      };
      final staticMap = MapConfig.buildAmapStaticMap(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (staticMap != null && staticMap.isNotEmpty) {
        payload['staticMap'] = staticMap;
      }
      payload['legacy'] = [title, address].where((e) => e.isNotEmpty).join('|');
      final description = jsonEncode(payload);

      final message =
          await OpenIM.iMManager.messageManager.createLocationMessage(
        latitude: position.latitude,
        longitude: position.longitude,
        description: description,
      );
      final exJson = jsonEncode(payload);
      message.ex = exJson;
      message.localEx = exJson;
      debugPrint(
        'ChatLogic.onTapLocation message prepared lat=${position.latitude} lon=${position.longitude} payload=$exJson',
      );
      _sendMessage(message);
    } catch (e, s) {
      Logger.print('location error: $e $s');
      IMViews.showToast(StrRes.getLocationFailed);
    }
  }

  void playVoiceMessage(Message message) async {
    final sound = message.soundElem;
    if (sound == null) return;
    try {
      if (playingVoiceMsgId.value == message.clientMsgID) {
        if (_audioPlayer.playerState.playing) {
          await _audioPlayer.pause();
        } else {
          await _audioPlayer.play();
        }
        return;
      }

      await _audioPlayer.stop();
      voiceProgress.value = 0.0;

      final targetPath = await _prepareVoiceFile(message);
      final targetUrl = sound.sourceUrl;
      if (targetPath?.isNotEmpty == true && await File(targetPath!).exists()) {
        await _audioPlayer.setFilePath(targetPath!);
      } else if (targetUrl?.isNotEmpty == true) {
        final resolved = IMUtils.resolveMediaUrl(targetUrl);
        if (resolved == null || resolved.isEmpty) {
          Logger.print('play voice error: unresolved url => $targetUrl');
          IMViews.showToast(StrRes.networkAnomaly);
          return;
        }
        Logger.print('play voice from url: $resolved');
        await _audioPlayer.setUrl(resolved);
      } else {
        IMViews.showToast(StrRes.unsupportedMessage);
        return;
      }

      _currentVoiceDurationMs = (sound.duration ?? 0) * 1000;
      playingVoiceMsgId.value = message.clientMsgID ?? '';
      await _audioPlayer.play();
      _markMessageAsRead(message);
    } catch (e, s) {
      Logger.print('play voice error: $e $s');
      playingVoiceMsgId.value = '';
      voiceProgress.value = 0.0;
      IMViews.showToast(StrRes.networkAnomaly);
    }
  }

  void seekVoiceMessage(Message message, double ratio) {
    if (playingVoiceMsgId.value != message.clientMsgID) return;
    final totalMs = _currentVoiceDurationMs > 0
        ? _currentVoiceDurationMs
        : _audioPlayer.duration?.inMilliseconds ?? 0;
    if (totalMs <= 0) return;
    final targetMs = (totalMs * ratio).clamp(0, totalMs).toInt();
    _audioPlayer.seek(Duration(milliseconds: targetMs));
  }

  Future<String?> _prepareVoiceFile(Message message) async {
    final sound = message.soundElem;
    if (sound == null) return null;
    final local = sound.soundPath;
    if (local != null && local.isNotEmpty) {
      final file = File(local);
      if (await file.exists()) {
        return local;
      }
    }
    final resolved = IMUtils.resolveMediaUrl(sound.sourceUrl);
    if (resolved == null || resolved.isEmpty) {
      return null;
    }
    final ext = p.extension(resolved);
    final nameSeed = sound.uuid?.isNotEmpty == true
        ? sound.uuid!
        : message.clientMsgID ?? DateTime.now().millisecondsSinceEpoch.toString();
    final fileName = '$nameSeed${ext.isNotEmpty ? ext : '.aac'}';
    final cachePath = await IMUtils.createTempFile(dir: 'voice', name: fileName);
    final headers = <String, String>{};
    final chatToken = DataSp.chatToken;
    final imToken = DataSp.imToken;
    final token = (chatToken?.isNotEmpty ?? false) ? chatToken : imToken;
    if (token?.isNotEmpty == true) {
      headers['token'] = token!;
    }
    try {
      await HttpUtil.download(
        resolved,
        cachePath: cachePath,
        headers: headers.isEmpty ? null : headers,
      );
      sound.soundPath = cachePath;
      message.soundElem?.soundPath = cachePath;
      return cachePath;
    } catch (e, s) {
      Logger.print('download voice failed: $e\n$s');
      return null;
    }
  }

  void openFileMessage(Message message) {
    IMUtils.previewFile(message);
  }

  void onTapMessage(Message message) {
    if (isMultiSelectMode.value) {
      toggleMessageSelection(message);
      return;
    }
    parseClickEvent(message);
  }

  Future<void> onTapQuoteMessage(
    Message source,
    QuoteElem? quoteElem,
  ) async {
    final quoted = quoteElem?.quoteMessage;
    final quoteId = quoted?.clientMsgID ?? quoted?.serverMsgID;
    if (quoted == null || quoteId == null) {
      IMViews.showToast(StrRes.quoteContentBeRevoked);
      return;
    }
    final existing = messageList
        .firstWhereOrNull((element) => element.clientMsgID == quoteId);
    if (existing != null && existing.clientMsgID != null) {
      _markHighlight(existing.clientMsgID);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToMessage(existing.clientMsgID!);
      });
      return;
    }
    searchMessage = quoted;
    await _locateSearchMessage();
  }

  bool isMessageSelected(Message message) {
    final id = message.clientMsgID;
    if (id == null) return false;
    return selectedMessageIds.contains(id);
  }

  int get selectedMessageCount => selectedMessageIds.length;

  bool _canMultiSelect(Message message) =>
      message.isTextType || message.isPictureType;

  void _startMultiSelect(Message message) {
    final id = message.clientMsgID;
    if (id == null) return;
    isMultiSelectMode.value = true;
    selectedMessageIds
      ..clear()
      ..add(id);
    selectedMessageIds.refresh();
  }

  void toggleMessageSelection(Message message) {
    final id = message.clientMsgID;
    if (id == null) return;
    if (selectedMessageIds.remove(id)) {
      selectedMessageIds.refresh();
      if (selectedMessageIds.isEmpty) {
        isMultiSelectMode.value = false;
      }
    } else {
      if (!isMultiSelectMode.value) {
        isMultiSelectMode.value = true;
      }
      selectedMessageIds.add(id);
      selectedMessageIds.refresh();
    }
  }

  void exitMultiSelectMode() {
    isMultiSelectMode.value = false;
    selectedMessageIds.clear();
    selectedMessageIds.refresh();
  }

  void _removeFromSelection(Message message) {
    final id = message.clientMsgID;
    if (id == null) return;
    if (selectedMessageIds.remove(id)) {
      selectedMessageIds.refresh();
      if (selectedMessageIds.isEmpty) {
        isMultiSelectMode.value = false;
      }
    }
  }

  List<Message> _selectedMessagesInOrder() {
    final idMap = {
      for (final msg in messageList) msg.clientMsgID: msg,
    };
    final messages = <Message>[];
    for (final id in selectedMessageIds) {
      final msg = idMap[id];
      if (msg != null) {
        messages.add(msg);
      }
    }
    messages.sort(
      (a, b) => (a.sendTime ?? 0).compareTo(b.sendTime ?? 0),
    );
    return messages;
  }

  Future<void> onMultiForward() async {
    final selected = _selectedMessagesInOrder();
    if (selected.isEmpty) {
      IMViews.showToast(StrRes.selectMessages);
      return;
    }
    try {
      final preview = IMUtils.messageDigest(selected.last);
      final result = await AppNavigator.startSelectContacts(
        action: SelAction.forward,
        ex: preview,
      );
      if (result == null) return;
      final targets = _parseForwardTargets(result['checkedList']);
      if (targets.isEmpty) return;
      for (final target in targets) {
        final userId = IMUtils.convertCheckedToUserID(target);
        final groupId = IMUtils.convertCheckedToGroupID(target);
        if (userId == null && groupId == null) continue;
        for (final msg in selected) {
          try {
            final forwardMsg =
                await OpenIM.iMManager.messageManager.createForwardMessage(
              message: msg,
            );
            await _sendMessage(
              forwardMsg,
              userId: userId,
              groupId: groupId,
            );
          } catch (e, s) {
            Logger.print('multi forward failed: $e $s');
          }
        }
      }
      IMViews.showToast(StrRes.sendSuccessfully);
      exitMultiSelectMode();
    } catch (e, s) {
      Logger.print('multi forward error: $e $s');
      IMViews.showToast(StrRes.sendFailed);
    }
  }

  Future<void> onMultiDelete() async {
    final selected = _selectedMessagesInOrder();
    if (selected.isEmpty) return;
    final confirm = await Get.dialog<bool>(
      CustomDialog(
        title: StrRes.delete,
        content: StrRes.deleteConversationHint,
      ),
    );
    if (confirm != true) return;
    try {
      for (final msg in selected) {
        await OpenIM.iMManager.messageManager.deleteMessageFromLocalStorage(
          conversationID: conversationInfo.conversationID,
          clientMsgID: msg.clientMsgID!,
        );
        messageList.remove(msg);
      }
      messageList.refresh();
      exitMultiSelectMode();
      IMViews.showSimpleTip(StrRes.deleteSuccessfully);
    } catch (e, s) {
      Logger.print('multi delete failed: $e $s');
      IMViews.showToast(e.toString());
    }
  }

  void onLongPressMessage(Message message, Rect anchorRect) {
    if (isMultiSelectMode.value) {
      toggleMessageSelection(message);
      return;
    }
    closeToolbox();
    hideMessageActions();
    final actions = _buildMessageActions(message);
    if (actions.isEmpty) return;
    _presentMessageActions(message, anchorRect, actions);
  }

  List<MessageAction> _buildMessageActions(Message message) {
    final actions = <MessageAction>[];
    final type = message.contentType;
    if (_isTextualMessage(type)) {
      _addIfNotNull(actions, _copyAction(message));
      _addIfNotNull(actions, _replyAction(message));
      _addIfNotNull(actions, _forwardAction(message));
      _addIfNotNull(actions, _revokeAction(message));
      if (_canMultiSelect(message)) {
        _addIfNotNull(actions, _multiSelectAction(message));
      }
      _addIfNotNull(actions, _deleteAction(message));
      return actions;
    }

    if (message.isPictureType) {
      _addIfNotNull(actions, _savePictureAction(message));
      _addIfNotNull(actions, _forwardAction(message));
      _addIfNotNull(actions, _replyAction(message));
      if (_canMultiSelect(message)) {
        _addIfNotNull(actions, _multiSelectAction(message));
      }
      _addIfNotNull(actions, _revokeAction(message));
      _addIfNotNull(actions, _deleteAction(message));
      return actions;
    }

    if (message.isVideoType) {
      _addIfNotNull(actions, _saveVideoAction(message));
      _addIfNotNull(actions, _forwardAction(message));
      _addIfNotNull(actions, _replyAction(message));
      _addIfNotNull(actions, _revokeAction(message));
      _addIfNotNull(actions, _deleteAction(message));
      return actions;
    }

    if (message.isVoiceType) {
      _addIfNotNull(actions, _revokeAction(message));
      _addIfNotNull(actions, _deleteAction(message));
      return actions;
    }

    if (message.isFileType) {
      _addIfNotNull(actions, _openFileAction(message));
      _addIfNotNull(actions, _saveFileAction(message));
      _addIfNotNull(actions, _forwardAction(message));
      _addIfNotNull(actions, _revokeAction(message));
      _addIfNotNull(actions, _deleteAction(message));
      return actions;
    }

    _addIfNotNull(actions, _replyAction(message));
    _addIfNotNull(actions, _forwardAction(message));
    _addIfNotNull(actions, _revokeAction(message));
    _addIfNotNull(actions, _deleteAction(message));
    return actions;
  }

  void _addIfNotNull(List<MessageAction> list, MessageAction? action) {
    if (action != null) list.add(action);
  }

  bool _isTextualMessage(int? type) =>
      type == MessageType.text ||
      type == MessageType.atText ||
      type == MessageType.quote ||
      type == MessageType.advancedText;

  MessageAction? _copyAction(Message message) {
    final copyText = _messageCopyText(message);
    if (copyText == null || copyText.isEmpty) return null;
    return MessageAction(
      label: StrRes.menuCopy,
      icon: ImageRes.menuCopy,
      onTap: () {
        Clipboard.setData(ClipboardData(text: copyText));
        IMViews.showSimpleTip(StrRes.copySuccessfully);
      },
    );
  }

  MessageAction? _replyAction(Message message) {
    if (!_canReply(message)) return null;
    return MessageAction(
      label: StrRes.menuReply,
      icon: ImageRes.menuReply,
      onTap: () => _startReply(message),
    );
  }

  MessageAction? _forwardAction(Message message) {
    if (!_canForward(message)) return null;
    return MessageAction(
      label: StrRes.menuForward,
      icon: ImageRes.menuForward,
      onTap: () => _forwardMessage(message),
    );
  }

  MessageAction? _revokeAction(Message message) {
    if (!_canRevoke(message)) return null;
    return MessageAction(
      label: StrRes.menuRevoke,
      icon: ImageRes.menuRevoke,
      onTap: () => _revokeMessage(message),
    );
  }

  MessageAction? _deleteAction(Message message) => MessageAction(
        label: StrRes.menuDel,
        icon: ImageRes.menuDel,
        onTap: () => _deleteSingleMessage(message),
      );

  MessageAction? _multiSelectAction(Message message) {
    if (!_canMultiSelect(message)) return null;
    return MessageAction(
      label: StrRes.menuMulti,
      icon: ImageRes.menuMulti,
      onTap: () => _startMultiSelect(message),
    );
  }

  MessageAction? _savePictureAction(Message message) {
    if (!message.isPictureType) return null;
    return MessageAction(
      label: StrRes.save,
      icon: ImageRes.saveIcon,
      onTap: () => _savePictureMessage(message),
    );
  }

  MessageAction? _saveVideoAction(Message message) {
    if (!message.isVideoType) return null;
    return MessageAction(
      label: StrRes.save,
      icon: ImageRes.saveIcon,
      onTap: () => _saveVideoMessage(message),
    );
  }

  MessageAction? _openFileAction(Message message) {
    if (!message.isFileType) return null;
    return MessageAction(
      label: StrRes.openWith,
      icon: ImageRes.toolboxFile,
      onTap: () => openFileMessage(message),
    );
  }

  MessageAction? _saveFileAction(Message message) {
    if (!message.isFileType) return null;
    return MessageAction(
      label: StrRes.save,
      icon: ImageRes.saveIcon,
      onTap: () => _saveFileMessage(message),
    );
  }

  bool _canRevoke(Message message) {
    if (message.sendID != OpenIM.iMManager.userID) return false;
    final sendTime = message.sendTime;
    if (sendTime == null) return false;
    return DateTime.now().millisecondsSinceEpoch - sendTime <= 3 * 60 * 1000;
  }

  void _presentMessageActions(
      Message message, Rect anchorRect, List<MessageAction> actions) {
    final overlayContext = Get.overlayContext ?? Get.context;
    if (overlayContext == null) return;
    final overlayState = Overlay.of(overlayContext, rootOverlay: true);
    if (overlayState == null) return;

    final mediaQuery = MediaQuery.of(overlayContext);
    final size = mediaQuery.size;
    final padding = mediaQuery.padding;

    const double barHeight = MessageActionBar.barHeight;
    const double gap = MessageActionBar.verticalGap;

    double top = anchorRect.top - barHeight - gap;
    bool showAbove = true;
    final double minTop = padding.top + 12;
    if (top < minTop) {
      showAbove = false;
      top = anchorRect.bottom + gap;
    }
    final double maxTop = size.height - padding.bottom - barHeight - 12;
    if (maxTop <= minTop) {
      top = minTop;
    } else {
      top = top.clamp(minTop, maxTop);
    }

    _messageActionOverlay = OverlayEntry(
      builder: (_) => Material(
        color: Colors.transparent,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: hideMessageActions,
          child: Stack(
            children: [
              Positioned(
                top: top,
                left: 0,
                right: 0,
                child: MessageActionBar(
                  actions: actions,
                  anchorRect: anchorRect,
                  anchorX: anchorRect.center.dx,
                  showAbove: showAbove,
                  onDismiss: hideMessageActions,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    overlayState.insert(_messageActionOverlay!);
  }

  void _startReply(Message message) {
    hideMessageActions();
    if (!_canReply(message)) {
      IMViews.showToast(StrRes.unsupportedMessage);
      return;
    }
    clearReply(showToast: false);
    replyMessage.value = message;
    replyPreview.value = _replyPreviewText(message);
    focusNode.requestFocus();
    IMViews.showSimpleTip('${StrRes.reply} ${StrRes.setSuccessfully}');
  }

  String _replyPreviewText(Message message) {
    final name =
        getNewestNickname(message) ?? message.senderNickname ?? message.sendID ?? '';
    final digest = IMUtils.messageDigest(message);
    if (name.isEmpty) return digest;
    if (digest.isEmpty) return name;
    return '$name: $digest';
  }

  void clearReply({bool showToast = false}) {
    final hasValue = replyMessage.value != null || replyPreview.value != null;
    if (!hasValue) return;
    replyMessage.value = null;
    replyPreview.value = null;
    if (showToast) {
      IMViews.showSimpleTip('${StrRes.reply} ${StrRes.clearSuccessfully}');
    }
  }

  Future<void> _forwardMessage(Message message) async {
    hideMessageActions();
    if (!_canForward(message)) {
      IMViews.showToast(StrRes.unsupportedMessage);
      return;
    }
    try {
      final preview = IMUtils.messageDigest(message);
      final result = await AppNavigator.startSelectContacts(
        action: SelAction.forward,
        ex: preview.isNotEmpty ? preview : StrRes.menuForward,
      );
      if (result == null) return;
      final targets = _parseForwardTargets(result['checkedList']);
      if (targets.isEmpty) return;
      var successCount = 0;
      var failedCount = 0;
      for (final target in targets) {
        final userId = IMUtils.convertCheckedToUserID(target);
        final groupId = IMUtils.convertCheckedToGroupID(target);
        if (userId == null && groupId == null) {
          failedCount += 1;
          continue;
        }
        try {
          final forwardMsg =
              await OpenIM.iMManager.messageManager.createForwardMessage(
            message: message,
          );
          await _sendMessage(
            forwardMsg,
            userId: userId,
            groupId: groupId,
          );
          successCount += 1;
        } catch (e, s) {
          failedCount += 1;
          Logger.print('forward message failed: $e $s');
        }
      }
      if (successCount > 0) {
        final total = targets.length;
        final label = failedCount > 0
            ? '${StrRes.menuForward} ${StrRes.sendSuccessfully} ($successCount/$total)'
            : '${StrRes.menuForward} ${StrRes.sendSuccessfully}';
        IMViews.showToast(label);
      }
      if (failedCount > 0) {
        Future.delayed(const Duration(milliseconds: 200), () {
          IMViews.showToast('${StrRes.menuForward} ${StrRes.sendFailed}');
        });
      }
    } catch (e, s) {
      Logger.print('open forward selector failed: $e $s');
      IMViews.showToast('${StrRes.menuForward} ${StrRes.sendFailed}');
    }
  }

  List<dynamic> _parseForwardTargets(dynamic raw) {
    if (raw is Iterable) return raw.toList();
    if (raw is List) return List<dynamic>.from(raw);
    return <dynamic>[];
  }

  bool _canReply(Message message) => _isActionableMessage(message);

  bool _canForward(Message message) => _isActionableMessage(message);

  bool _isActionableMessage(Message message) {
    final type = message.contentType;
    if (type == null) return false;
    if (message.isNotificationType) return false;
    if (type == MessageType.revokeMessageNotification) return false;
    return true;
  }

  void hideMessageActions() {
    _messageActionOverlay?.remove();
    _messageActionOverlay = null;
  }

  String? _messageCopyText(Message message) {
    if (message.isTextType) {
      return message.textElem?.content;
    }
    if (message.isQuoteType) {
      return message.quoteElem?.text;
    }
    final text = copyTextMap[message.clientMsgID];
    return text;
  }

  Future<void> _deleteSingleMessage(Message message) async {
    try {
      await OpenIM.iMManager.messageManager.deleteMessageFromLocalStorage(
        conversationID: conversationInfo.conversationID,
        clientMsgID: message.clientMsgID!,
      );
      messageList.remove(message);
      messageList.refresh();
      _removeFromSelection(message);
      IMViews.showSimpleTip(StrRes.deleteSuccessfully);
    } catch (e, s) {
      Logger.print('delete message failed: $e $s');
      IMViews.showToast(
        e is PlatformException ? '${e.code} ${e.message}' : e.toString(),
      );
    }
  }

  Future<void> _revokeMessage(Message message) async {
    try {
      await OpenIM.iMManager.messageManager.revokeMessage(
        conversationID: conversationInfo.conversationID,
        clientMsgID: message.clientMsgID!,
      );
      await _loadHistoryForSyncEnd();
      IMViews.showSimpleTip(StrRes.revokeSuccessfully);
    } catch (e, s) {
      Logger.print('revoke message failed: $e $s');
      IMViews.showToast(
        e is PlatformException ? '${e.code} ${e.message}' : e.toString(),
      );
    }
  }

  Future<void> _savePictureMessage(Message message) async {
    final elem = message.pictureElem;
    if (elem == null) {
      IMViews.showToast(StrRes.saveFailed);
      return;
    }
    Permissions.storage(() async {
      try {
        final localPath = elem.sourcePath;
        if (localPath?.isNotEmpty == true) {
          final file = File(localPath!);
          if (await file.exists()) {
            await HttpUtil.saveFileToGallerySaver(
              file,
              name: p.basename(file.path),
            );
            return;
          }
        }
        final url = elem.sourcePicture?.url ??
            elem.bigPicture?.url ??
            elem.snapshotPicture?.url;
        if (url?.isNotEmpty == true) {
          await HttpUtil.saveUrlPicture(url!);
          return;
        }
        IMViews.showToast(StrRes.saveFailed);
      } catch (e, s) {
        Logger.print('save picture failed: $e $s');
        IMViews.showToast(StrRes.saveFailed);
      }
    });
  }

  Future<void> _saveVideoMessage(Message message) async {
    final elem = message.videoElem;
    if (elem == null) {
      IMViews.showToast(StrRes.saveFailed);
      return;
    }
    Permissions.storage(() async {
      try {
        final localPath = elem.videoPath;
        if (localPath?.isNotEmpty == true) {
          final file = File(localPath!);
          if (await file.exists()) {
            final result = await ImageGallerySaverPlus.saveFile(file.path);
            if (result != null) {
              var tips = StrRes.saveSuccessfully;
              final filePath = result['filePath'];
              if (filePath is String && filePath.isNotEmpty) {
                tips =
                    '${StrRes.saveSuccessfully}:${filePath.split('//').last}';
              }
              IMViews.showToast(tips);
              return;
            }
          }
        }
        final url = elem.videoUrl;
        if (url?.isNotEmpty == true) {
          await HttpUtil.saveUrlVideo(url!);
          return;
        }
        IMViews.showToast(StrRes.saveFailed);
      } catch (e, s) {
        Logger.print('save video failed: $e $s');
        IMViews.showToast(StrRes.saveFailed);
      }
    });
  }

  Future<void> _saveFileMessage(Message message) async {
    final elem = message.fileElem;
    if (elem == null) {
      IMViews.showToast(StrRes.saveFailed);
      return;
    }
    final source = await _ensureMediaFile(
      localPath: elem.filePath,
      url: elem.sourceUrl,
      tempDir: 'file',
      fileName: elem.fileName ?? _guessFileName(elem.sourceUrl),
    );
    if (source == null) {
      IMViews.showToast(StrRes.saveFailed);
      return;
    }
    Permissions.storage(() async {
      try {
        final downloadsDir = await IMUtils.getDownloadFileDir();
        final target = p.join(
          downloadsDir,
          elem.fileName ?? p.basename(source.path),
        );
        final copied = await source.copy(target);
        IMViews.showToast('${StrRes.saveSuccessfully}:${copied.path}');
      } catch (e, s) {
        Logger.print('save file failed: $e $s');
        IMViews.showToast(StrRes.saveFailed);
      }
    });
  }

  Future<File?> _ensureMediaFile({
    String? localPath,
    String? url,
    required String tempDir,
    String? fileName,
  }) async {
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (await file.exists()) return file;
    }
    if (url != null && url.isNotEmpty) {
      try {
        final name = fileName ?? _guessFileName(url);
        final cachePath = await IMUtils.createTempFile(
          dir: tempDir,
          name: name,
        );
        await HttpUtil.download(
          url,
          cachePath: cachePath,
        );
        return File(cachePath);
      } catch (e, s) {
        Logger.print('download media failed: $e $s');
      }
    }
    return null;
  }

  String _guessFileName(String? source, {String fallback = 'file'}) {
    if (source == null || source.isEmpty) {
      return '$fallback-${DateTime.now().millisecondsSinceEpoch}';
    }
    final clean = source.split('?').first;
    final base = p.basename(clean);
    if (base.isEmpty) {
      return '$fallback-${DateTime.now().millisecondsSinceEpoch}';
    }
    return base;
  }


  sendForwardRemarkMsg(
    String content, {
    String? userId,
    String? groupId,
  }) async {
    final message = await OpenIM.iMManager.messageManager.createTextMessage(
      text: content,
    );
    _sendMessage(message, userId: userId, groupId: groupId);
  }

  sendForwardMsg(
    Message originalMessage, {
    String? userId,
    String? groupId,
  }) async {
    var message = await OpenIM.iMManager.messageManager.createForwardMessage(
      message: originalMessage,
    );
    _sendMessage(message, userId: userId, groupId: groupId);
  }

  void sendTypingMsg({bool focus = false}) async {
    if (isSingleChat) {
      OpenIM.iMManager.conversationManager.changeInputStates(
        conversationID: conversationInfo.conversationID,
        focus: focus,
      );
    }
  }

  void sendCarte({
    required String userID,
    String? nickname,
    String? faceURL,
  }) async {
    var message = await OpenIM.iMManager.messageManager.createCardMessage(
      userID: userID,
      nickname: nickname!,
      faceURL: faceURL,
    );
    _sendMessage(message);
  }

  void sendCustomMsg({
    required String data,
    required String extension,
    required String description,
  }) async {
    var message = await OpenIM.iMManager.messageManager.createCustomMessage(
      data: data,
      extension: extension,
      description: description,
    );
    _sendMessage(message);
  }

  Future _sendMessage(
    Message message, {
    String? userId,
    String? groupId,
    bool addToUI = true,
  }) {
    log('send : ${json.encode(message)}');
    userId = IMUtils.emptyStrToNull(userId);
    groupId = IMUtils.emptyStrToNull(groupId);
    if (null == userId && null == groupId ||
        userId == userID && userId != null ||
        groupId == groupID && groupId != null) {
      if (addToUI) {
        messageList.add(message);
        scrollBottom();
      }
    }
    Logger.print('uid:$userID userId:$userId gid:$groupID groupId:$groupId');
    _reset(message);
    bool useOuterValue = null != userId || null != groupId;

    final recvUserID = useOuterValue ? userId : userID;
    message.recvID = recvUserID;

    return OpenIM.iMManager.messageManager
        .sendMessage(
          message: message,
          userID: recvUserID,
          groupID: useOuterValue ? groupId : groupID,
          offlinePushInfo: Config.offlinePushInfo,
        )
        .then((value) => _sendSucceeded(message, value))
        .catchError(
          (error, _) => _senFailed(message, groupId, userId, error, _),
        )
        .whenComplete(() => _completed());
  }

  void _sendSucceeded(Message oldMsg, Message newMsg) {
    Logger.print('message send success----');
    final originEx = oldMsg.ex;
    final originLocalEx = oldMsg.localEx;
    final originDesc = oldMsg.locationElem?.description;
    oldMsg.update(newMsg);
    if (originEx?.isNotEmpty == true && oldMsg.ex?.isEmpty == true) {
      oldMsg.ex = originEx;
    }
    if (originLocalEx?.isNotEmpty == true && oldMsg.localEx?.isEmpty == true) {
      oldMsg.localEx = originLocalEx;
    }
    final locationElem = oldMsg.locationElem;
    if (locationElem != null &&
        (locationElem.description == null ||
            locationElem.description!.isEmpty) &&
        originDesc?.isNotEmpty == true) {
      locationElem.description = originDesc;
    }
    final videoElem = oldMsg.videoElem;
    if (videoElem != null && (videoElem.snapshotUrl?.isNotEmpty == true)) {
      final snapshotPath = videoElem.snapshotPath;
      if (snapshotPath != null && snapshotPath.isNotEmpty) {
        final file = File(snapshotPath);
        if (file.existsSync()) {
          try {
            file.deleteSync();
          } catch (e, s) {
            Logger.print('delete video snapshot failed: $e $s');
          }
        }
        videoElem.snapshotPath = '';
      }
    }
    sendStatusSub.addSafely(
      MsgStreamEv<bool>(id: oldMsg.clientMsgID!, value: true),
    );
  }

  void _senFailed(
    Message message,
    String? groupId,
    String? userId,
    error,
    stack,
  ) async {
    Logger.print(
      'message send failed userID: $userId groupId:$groupId, catch error :$error  $stack',
    );
    message.status = MessageStatus.failed;
    sendStatusSub.addSafely(
      MsgStreamEv<bool>(id: message.clientMsgID!, value: false),
    );
    if (error is PlatformException) {
      int code = int.tryParse(error.code) ?? 0;
      if (isSingleChat) {
        int? customType;
        if (code == SDKErrorCode.hasBeenBlocked) {
          customType = CustomMessageType.blockedByFriend;
        } else if (code == SDKErrorCode.notFriend) {
          customType = CustomMessageType.deletedByFriend;
        }
        if (null != customType) {
          final hintMessage =
              (await OpenIM.iMManager.messageManager.createFailedHintMessage(
            type: customType,
          ))
                ..status = 2
                ..isRead = true;
          if (userId != null) {
            if (userId == userID) {
              messageList.add(hintMessage);
            }
          } else {
            messageList.add(hintMessage);
          }
          OpenIM.iMManager.messageManager.insertSingleMessageToLocalStorage(
            message: hintMessage,
            receiverID: userId ?? userID,
            senderID: OpenIM.iMManager.userID,
          );
        }
      } else {
        if ((code == SDKErrorCode.userIsNotInGroup ||
                code == SDKErrorCode.groupDisbanded) &&
            null == groupId) {
          final status = groupInfo?.status;
          final hintMessage =
              (await OpenIM.iMManager.messageManager.createFailedHintMessage(
            type: status == 2
                ? CustomMessageType.groupDisbanded
                : CustomMessageType.removedFromGroup,
          ))
                ..status = 2
                ..isRead = true;
          messageList.add(hintMessage);
          OpenIM.iMManager.messageManager.insertGroupMessageToLocalStorage(
            message: hintMessage,
            groupID: groupID,
            senderID: OpenIM.iMManager.userID,
          );
        }
      }
    }
  }

  void _reset(Message message) {
    if (message.contentType == MessageType.text ||
        message.contentType == MessageType.quote) {
      inputCtrl.clear();
    }
  }

  void _completed() {
    messageList.refresh();
  }

  void markMessageAsRead(Message message, bool visible) async {
    Logger.print('markMessageAsRead: ${message.textElem?.content}, $visible');
    if (visible &&
        message.contentType! < 1000 &&
        message.contentType! != MessageType.voice) {
      var data = IMUtils.parseCustomMessage(message);
      if (data != null && data['viewType'] == CustomMessageType.call) {
        Logger.print('markMessageAsRead: call message $data');
        return;
      }
      _markMessageAsRead(message);
    }
  }

  _markMessageAsRead(Message message) async {
    if (!message.isRead! && message.sendID != OpenIM.iMManager.userID) {
      try {
        Logger.print(
          'mark conversation message as read锟?{message.clientMsgID!} ${message.isRead}',
        );
        await OpenIM.iMManager.conversationManager
            .markConversationMessageAsRead(
          conversationID: conversationInfo.conversationID,
        );
      } catch (e) {
        Logger.print(
          'failed to send group message read receipt锟?${message.clientMsgID} ${message.isRead}',
        );
      } finally {
        message.isRead = true;
        message.hasReadTime = _timestamp;
        messageList.refresh();
      }
    }
  }

  _clearUnreadCount() {
    if (conversationInfo.unreadCount > 0) {
      OpenIM.iMManager.conversationManager.markConversationMessageAsRead(
        conversationID: conversationInfo.conversationID,
      );
    }
  }

  void _onScroll() {
    hideMessageActions();
  }

  void closeToolbox() {
    hideMessageActions();
    forceCloseToolbox.addSafely(true);
  }

  void onTapAlbum() async {
    final List<AssetEntity>? assets = await AssetPicker.pickAssets(
      Get.context!,
      pickerConfig: AssetPickerConfig(
        sortPathsByModifiedDate: true,
        filterOptions: PMFilter.defaultValue(containsPathModified: true),
        selectPredicate: (_, entity, isSelected) async {
          if (entity.type == AssetType.image) {
            if (await allowSendImageType(entity)) {
              return true;
            }

            IMViews.showToast(StrRes.supportsTypeHint);

            return false;
          }

          if (entity.videoDuration > const Duration(seconds: 5 * 60)) {
            IMViews.showToast(
              sprintf(StrRes.selectVideoLimit, [5]) + StrRes.minute,
            );
            return false;
          }
          return true;
        },
      ),
    );
    if (null != assets) {
      for (var asset in assets) {
        await _handleAssets(asset, sendNow: false);
      }

      for (var msg in tempMessages) {
        await _sendMessage(msg, addToUI: false);
      }

      tempMessages.clear();
      scrollBottom();
    }
  }

  Future<bool> allowSendImageType(AssetEntity entity) async {
    final mimeType = await entity.mimeTypeAsync;

    return IMUtils.allowImageType(mimeType);
  }

  Future _handleAssets(AssetEntity? asset, {bool sendNow = true}) async {
    if (null != asset) {
      Logger.print(
        '--------assets type-----${asset.type} create time: ${asset.createDateTime}',
      );
      final originalFile = await asset.file;
      final originalPath = originalFile!.path;
      var path = originalPath.toLowerCase().endsWith('.gif')
          ? originalPath
          : originalFile.path;
      Logger.print('--------assets path-----$path');
      switch (asset.type) {
        case AssetType.image:
          await sendPicture(path: path, sendNow: sendNow);
          break;
        case AssetType.video:
          await _sendVideo(asset: asset, file: originalFile, sendNow: sendNow);
          break;
        default:
          break;
      }
      if (Platform.isIOS && asset.type == AssetType.image) {
        originalFile.deleteSync();
      }
    }
  }

  void onTapDirectionalMessage() async {
    if (groupInfo != null) {
      final list = await AppNavigator.startGroupMemberList(
        groupInfo: groupInfo!,
        opType: GroupMemberOpType.call,
      );
      if (list is List<GroupMembersInfo>) {
        directionalUsers.assignAll(list);
      }
    }
  }

  TextSpan? directionalText() {
    if (directionalUsers.isNotEmpty) {
      final temp = <TextSpan>[];

      for (var e in directionalUsers) {
        final r = TextSpan(
          text: '${e.nickname ?? ''} ${directionalUsers.last == e ? '' : ','} ',
          style: Styles.ts_0089FF_14sp,
        );

        temp.add(r);
      }

      return TextSpan(
        text: '${StrRes.directedTo}:',
        style: Styles.ts_8E9AB0_14sp,
        children: temp,
      );
    }

    return null;
  }

  void onClearDirectional() {
    directionalUsers.clear();
  }

  void parseClickEvent(Message msg) async {
    log('parseClickEvent:${jsonEncode(msg)}');
    if (msg.contentType == MessageType.custom) {
      final customType = IMUtils.customMessageType(msg);
      if (CustomMessageType.call == customType && !isInBlacklist.value) {
        call();
      }
      return;
    }

    if (msg.contentType == MessageType.picture ||
        msg.contentType == MessageType.video) {
      previewMessageMedia(msg);
      return;
    }

    IMUtils.parseClickEvent(
      msg,
      onViewUserInfo: (userInfo) {
        viewUserInfo(userInfo, isCard: msg.isCardType);
      },
    );
  }

  void onTapLeftAvatar(Message message) {
    viewUserInfo(
      UserInfo()
        ..userID = message.sendID
        ..nickname = message.senderNickname
        ..faceURL = message.senderFaceUrl,
    );
  }

  void onTapRightAvatar() {
    viewUserInfo(OpenIM.iMManager.userInfo);
  }

  void viewUserInfo(UserInfo userInfo, {bool isCard = false}) {
    if (isGroupChat && !isAdminOrOwner && !isCard) {
      if (groupInfo!.lookMemberInfo != 1) {
        AppNavigator.startUserProfilePane(
          userID: userInfo.userID!,
          nickname: userInfo.nickname,
          faceURL: userInfo.faceURL,
          groupID: groupID,
          offAllWhenDelFriend: isSingleChat,
        );
      }
    } else {
      AppNavigator.startUserProfilePane(
        userID: userInfo.userID!,
        nickname: userInfo.nickname,
        faceURL: userInfo.faceURL,
        groupID: groupID,
        offAllWhenDelFriend: isSingleChat,
        forceCanAdd: isCard,
      );
    }
  }

  void clickLinkText(url, type) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  exit() async {
    Get.back();
    return true;
  }

  void previewMessageMedia(Message message) {
    final context = Get.context;
    if (context == null) return;
    final mediaMessages = messageList
        .where((e) => e.isPictureType || e.isVideoType)
        .toList(growable: false);
    if (mediaMessages.isEmpty) {
      IMUtils.previewMediaFile(
          context: context, message: message, muted: rtcIsBusy);
      return;
    }
    final sources = <MediaSource>[];
    int targetIndex = 0;
    for (final item in mediaMessages) {
      final source = IMUtils.mediaSourceFromMessage(item);
      if (source == null) continue;
      if (item.clientMsgID == message.clientMsgID) {
        targetIndex = sources.length;
      }
      sources.add(source);
    }
    if (sources.isEmpty) {
      IMUtils.previewMediaFile(
          context: context, message: message, muted: rtcIsBusy);
      return;
    }
    IMUtils.previewMediaSources(
      context: context,
      sources: sources,
      initialIndex: targetIndex.clamp(0, sources.length - 1),
      muted: rtcIsBusy,
      onAutoPlay: (index) => sources[index].isVideo && index == targetIndex,
    );
  }

  void focusNodeChanged(bool hasFocus) {
    if (hasFocus) {
      Logger.print('focus:$hasFocus');
      scrollBottom();
    }
  }

  Message indexOfMessage(int index, {bool calculate = true}) =>
      IMUtils.calChatTimeInterval(
        visibleMessages,
        calculate: calculate,
      ).reversed.elementAt(index);

  ValueKey itemKey(Message message) => ValueKey(message.clientMsgID!);

  @override
  void onClose() {
    sendTypingMsg();
    _clearUnreadCount();
    scrollController.removeListener(_onScroll);
    hideMessageActions();
    inputCtrl.dispose();
    focusNode.dispose();
    forceCloseToolbox.close();
    conversationSub.cancel();
    sendStatusSub.close();
    memberAddSub.cancel();
    memberDelSub.cancel();
    memberInfoChangedSub.cancel();
    groupInfoUpdatedSub.cancel();
    friendInfoChangedSub.cancel();
    userStatusChangedSub?.cancel();
    selfInfoUpdatedSub?.cancel();
    joinedGroupAddedSub.cancel();
    joinedGroupDeletedSub.cancel();
    connectionSub.cancel();

    _debounce?.cancel();
    imLogic.onRecvMessageRevoked = null;
    imLogic.onRecvNewMessage = null;
    _audioPlayer.dispose();
    groupSearchResults.clear();
    inlineSearchCtrl.dispose();
    inlineSearchFocus.dispose();
    super.onClose();
  }

  Future<void> _sendVideo({
    required AssetEntity asset,
    required File file,
    bool sendNow = true,
  }) async {
    try {
      final mimeType = await asset.mimeTypeAsync ??
          IMUtils.getMediaType(file.path) ??
          'video/mp4';
      final mediaInfo = await IMUtils.getMediaInfo(file.path);
      final thumb = await VideoCompress.getFileThumbnail(
        file.path,
        quality: 80,
        position: -1,
      );
      final durationMs = mediaInfo.duration ?? 0;
      final duration = durationMs > 0
          ? (durationMs / 1000).ceil()
          : (asset.videoDuration.inSeconds);
      final message =
          await OpenIM.iMManager.messageManager.createVideoMessageFromFullPath(
        videoPath: file.path,
        videoType: mimeType,
        duration: duration,
        snapshotPath: thumb.path,
      );
      message.videoElem?.snapshotWidth = mediaInfo.width?.toInt();
      message.videoElem?.snapshotHeight = mediaInfo.height?.toInt();
      message.videoElem?.videoSize = mediaInfo.filesize?.toInt();
      message.videoElem?.snapshotSize = await thumb.length();
      if (sendNow) {
        await _sendMessage(message);
      } else {
        messageList.add(message);
        tempMessages.add(message);
      }
    } catch (e, s) {
      Logger.print('send video error: $e $s');
      IMViews.showToast(StrRes.sendFailed);
    }
  }

  String? getShowTime(Message message) {
    if (message.exMap['showTime'] == true) {
      return IMUtils.getChatTimeline(message.sendTime!);
    }
    return null;
  }

  void clearAllMessage() {
    messageList.clear();
  }

  void _initChatConfig() async {
    scaleFactor.value = DataSp.getChatFontSizeFactor();
    var path = DataSp.getChatBackground(otherId) ?? '';
    if (path.isNotEmpty && (await File(path).exists())) {
      background.value = path;
    }
  }

  String get otherId => isSingleChat ? userID! : groupID!;

  void failedResend(Message message) {
    Logger.print('failedResend: ${message.clientMsgID}');
    if (message.status == MessageStatus.sending) {
      return;
    }
    sendStatusSub.addSafely(
      MsgStreamEv<bool>(id: message.clientMsgID!, value: true),
    );

    Logger.print('failedResending: ${message.clientMsgID}');
    _sendMessage(message..status = MessageStatus.sending, addToUI: false);
  }

  static int get _timestamp => DateTime.now().millisecondsSinceEpoch;

  void destroyMsg() {
    for (var message in privateMessageList) {
      OpenIM.iMManager.messageManager.deleteMessageFromLocalAndSvr(
        conversationID: conversationInfo.conversationID,
        clientMsgID: message.clientMsgID!,
      );
    }
  }

  Future _queryMyGroupMemberInfo() async {
    if (!isGroupChat) {
      return;
    }
    var list = await OpenIM.iMManager.groupManager.getGroupMembersInfo(
      groupID: groupID!,
      userIDList: [OpenIM.iMManager.userID],
    );
    groupMembersInfo = list.firstOrNull;
    groupMemberRoleLevel.value =
        groupMembersInfo?.roleLevel ?? GroupRoleLevel.member;
    if (null != groupMembersInfo) {
      memberUpdateInfoMap[OpenIM.iMManager.userID] = groupMembersInfo!;
    }

    return;
  }

  Future _queryOwnerAndAdmin() async {
    if (isGroupChat) {
      ownerAndAdmin = await OpenIM.iMManager.groupManager.getGroupMemberList(
        groupID: groupID!,
        filter: 5,
        count: 20,
      );
    }
    return;
  }

  void _isJoinedGroup() async {
    if (!isGroupChat) {
      return;
    }
    isInGroup.value = await OpenIM.iMManager.groupManager.isJoinedGroup(
      groupID: groupID!,
    );
    if (!isInGroup.value) {
      return;
    }
    _queryGroupInfo();
    _queryOwnerAndAdmin();
  }

  void _queryGroupInfo() async {
    if (!isGroupChat) {
      return;
    }
    var list = await OpenIM.iMManager.groupManager.getGroupsInfo(
      groupIDList: [groupID!],
    );
    groupInfo = list.firstOrNull;
    groupOwnerID = groupInfo?.ownerUserID;
    if (null != groupInfo?.memberCount) {
      memberCount.value = groupInfo!.memberCount!;
    }
    _queryMyGroupMemberInfo();
  }

  bool get havePermissionMute =>
      isGroupChat &&
      (groupInfo?.ownerUserID ==
          OpenIM.iMManager
              .userID /*||
          groupMembersInfo?.roleLevel == 2*/
      );

  bool isNotificationType(Message message) => message.contentType! >= 1000;

  Map<String, String> getAtMapping(Message message) {
    return {};
  }

  void _checkInBlacklist() async {
    if (userID != null) {
      var list = await OpenIM.iMManager.friendshipManager.getBlacklist();
      var user = list.firstWhereOrNull((e) => e.userID == userID);
      isInBlacklist.value = user != null;
    }
  }

  bool isExceed24H(Message message) {
    int milliseconds = message.sendTime!;
    return !DateUtil.isToday(milliseconds);
  }

  String? getNewestNickname(Message message) {
    if (isSingleChat) null;

    return message.senderNickname;
  }

  String? getNewestFaceURL(Message message) {
    return message.senderFaceUrl;
  }

  bool get isInvalidGroup => !isInGroup.value && isGroupChat;

  void _resetGroupAtType() {
    if (conversationInfo.groupAtType != GroupAtType.atNormal) {
      OpenIM.iMManager.conversationManager.resetConversationGroupAtType(
        conversationID: conversationInfo.conversationID,
      );
    }
  }

  void call() {
    if (rtcIsBusy) {
      IMViews.showToast(StrRes.callingBusy);
      return;
    }
    imLogic.call(
      callObj: CallObj.single,
      callType: CallType.audio,
      inviteeUserIDList: [if (isSingleChat) userID!],
    );
  }

  void onScrollToTop() {
    if (scrollingCacheMessageList.isNotEmpty) {
      messageList.addAll(scrollingCacheMessageList);
      scrollingCacheMessageList.clear();
    }
  }

  String get markText {
    String? phoneNumber = imLogic.userInfo.value.phoneNumber;
    if (phoneNumber != null) {
      int start = phoneNumber.length > 4 ? phoneNumber.length - 4 : 0;
      final sub = phoneNumber.substring(start);
      return "${OpenIM.iMManager.userInfo.nickname!}$sub";
    }
    return OpenIM.iMManager.userInfo.nickname ?? '';
  }

  bool isFailedHintMessage(Message message) {
    if (message.contentType == MessageType.custom) {
      final customType = IMUtils.customMessageType(message);
      return customType == CustomMessageType.deletedByFriend ||
          customType == CustomMessageType.blockedByFriend;
    }
    return false;
  }

  void sendFriendVerification() =>
      AppNavigator.startSendVerificationApplication(userID: userID);

  void _setSdkSyncDataListener() {
    connectionSub = imLogic.imSdkStatusPublishSubject.listen((value) {
      syncStatus.value = value.status;
        if (value.status == IMSdkStatus.syncStart) {
          _isStartSyncing = true;
        } else if (value.status == IMSdkStatus.syncEnded) {
          if (_isStartSyncing) {
            _isStartSyncing = false;
            _isFirstLoad = true;
            _loadHistoryForSyncEnd();
          }
        } else if (value.status == IMSdkStatus.syncFailed) {
          _isStartSyncing = false;
        }
    });
  }

  bool get isSyncFailed => syncStatus.value == IMSdkStatus.syncFailed;

  String? get syncStatusStr {
    switch (syncStatus.value) {
      case IMSdkStatus.syncStart:
      case IMSdkStatus.synchronizing:
        return StrRes.synchronizing;
      case IMSdkStatus.syncFailed:
        return StrRes.syncFailed;
      default:
        return null;
    }
  }

  bool showBubbleBg(Message message) {
    return !isNotificationType(message) && !isFailedHintMessage(message);
  }

  bool get _isInlineSearchMode => isInlineSearchResultMode.value;

  void focusGroupSearchField() {
    inlineSearchFocus.requestFocus();
  }

  void onSearchFieldSubmitted(String value) {
    _executeGroupSearch(keyword: value.trim());
  }

  void onSearchActionTapped() {
    _executeGroupSearch(keyword: inlineSearchCtrl.text.trim());
  }

  void clearGroupSearch() {
    inlineSearchCtrl.clear();
    groupSearchKeyword.value = '';
    _resetGroupSearchState();
  }

  Future<void> _executeGroupSearch({String? keyword}) async {
    if (!isGroupChat) return;
    final groupID = conversationInfo.groupID;
    if (groupID == null || groupID.isEmpty) {
      return;
    }
    final query = (keyword ?? inlineSearchCtrl.text).trim();
    groupSearchKeyword.value = query;
    inlineSearchResultKeyword.value = query;
    _groupSearchPageNumber = 1;
    _groupSearchRequestId += 1;
    final requestId = _groupSearchRequestId;
    isGroupSearchLoading.value = true;
    try {
      final result = await Apis.searchGroupMessages(
        groupID: groupID,
        keyword: query,
        pageNumber: _groupSearchPageNumber,
        pageSize: _groupSearchPageSize,
      );
      if (requestId != _groupSearchRequestId) {
        return;
      }
      final items = result.messages.toList();
      for (final msg in items) {
        _hydrateServerMessage(msg);
        final customType = IMUtils.customMessageType(msg);
        final parsed = IMUtils.parseCustomMessage(msg);
        final preview = msg.customElem?.data;
        final snippet = preview == null
            ? ''
            : (preview.length > 120 ? '${preview.substring(0, 120)}...' : preview);
        Logger.print(
          'group search msg -> contentType: ${msg.contentType}, customType: $customType, parsed: ${parsed != null}, snippet: $snippet',
        );
      }
      groupSearchResults.assignAll(items);
      inlineSearchResultCount.value = result.total;
      hasMoreGroupSearchResult.value = groupSearchResults.length < result.total;
      if (groupSearchResults.isEmpty) {
        isInlineSearchResultMode.value = false;
        IMViews.showToast('未找到相关消息');
      } else {
        isInlineSearchResultMode.value = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scrollController.hasClients) {
            scrollController.jumpTo(0);
          }
        });
      }
    } catch (e, s) {
      Logger.print('execute group search failed: $e\n$s');
      IMViews.showToast('搜索失败，请稍后重试');
    } finally {
      if (requestId == _groupSearchRequestId) {
        isGroupSearchLoading.value = false;
        isGroupSearchLoadingMore.value = false;
      }
    }
  }

  Future<void> loadMoreGroupSearchResults() async {
    if (!isInlineSearchResultMode.value) return;
    if (!hasMoreGroupSearchResult.value ||
        isGroupSearchLoading.value ||
        isGroupSearchLoadingMore.value) {
      return;
    }
    final groupID = conversationInfo.groupID;
    if (groupID == null || groupID.isEmpty) {
      return;
    }
    final keyword = groupSearchKeyword.value;
    isGroupSearchLoadingMore.value = true;
    final nextPage = _groupSearchPageNumber + 1;
    try {
      final result = await Apis.searchGroupMessages(
        groupID: groupID,
        keyword: keyword,
        pageNumber: nextPage,
        pageSize: _groupSearchPageSize,
      );
      if (result.messages.isNotEmpty) {
        for (final msg in result.messages) {
          _hydrateServerMessage(msg);
        }
        groupSearchResults.addAll(result.messages);
        _groupSearchPageNumber = nextPage;
        hasMoreGroupSearchResult.value =
            groupSearchResults.length < result.total;
      } else {
        hasMoreGroupSearchResult.value = false;
      }
    } catch (e, s) {
      Logger.print('load more group search failed: $e\n$s');
    } finally {
      isGroupSearchLoadingMore.value = false;
    }
  }

  void exitSearchMode() {
    _resetGroupSearchState();
    inlineSearchCtrl.clear();
    groupSearchKeyword.value = '';
  }
  void _resetGroupSearchState() {
    groupSearchResults.clear();
    inlineSearchResultCount.value = 0;
    inlineSearchResultKeyword.value = '';
    hasMoreGroupSearchResult.value = false;
    isGroupSearchLoading.value = false;
    isGroupSearchLoadingMore.value = false;
    isInlineSearchResultMode.value = false;
  }

  List<Message> get visibleMessages =>
      isInlineSearchResultMode.value ? groupSearchResults : messageList;

  int get visibleMessageCount => visibleMessages.length;

  Message visibleMessageAt(int index) => visibleMessages[index];

  String get inlineSearchSummary {
    final count = inlineSearchResultCount.value;
    final keyword = inlineSearchResultKeyword.value;
    if (keyword.isEmpty) {
      return sprintf(StrRes.groupSearchResultWithoutKeyword, [count]);
    }
    return sprintf(StrRes.groupSearchResultWithKeyword, [count, keyword]);
  }

  void _hydrateServerMessage(Message message) {
    if (_hasContentElem(message)) return;
    final payload = _decodePayloadMap(message);
    if (payload == null) return;
    try {
      final inner = Message.fromJson(Map<String, dynamic>.from(payload));
      _copyElemIfNull(() => message.textElem, (v) => message.textElem = v,
          inner.textElem);
      _copyElemIfNull(() => message.atTextElem, (v) => message.atTextElem = v,
          inner.atTextElem);
      _copyElemIfNull(() => message.quoteElem, (v) => message.quoteElem = v,
          inner.quoteElem);
      _copyElemIfNull(
          () => message.advancedTextElem,
          (v) => message.advancedTextElem = v,
          inner.advancedTextElem);
      _copyElemIfNull(() => message.pictureElem,
          (v) => message.pictureElem = v, inner.pictureElem);
      _copyElemIfNull(
          () => message.videoElem, (v) => message.videoElem = v, inner.videoElem);
      _copyElemIfNull(
          () => message.soundElem, (v) => message.soundElem = v, inner.soundElem);
      _copyElemIfNull(
          () => message.fileElem, (v) => message.fileElem = v, inner.fileElem);
      _copyElemIfNull(
          () => message.locationElem,
          (v) => message.locationElem = v,
          inner.locationElem);
      _copyElemIfNull(
          () => message.faceElem, (v) => message.faceElem = v, inner.faceElem);
      _copyElemIfNull(
          () => message.customElem, (v) => message.customElem = v, inner.customElem);
    } catch (e, s) {
      Logger.print('hydrate server message failed: $e\n$s');
    } finally {
      if (message.contentType == MessageType.custom) {
        message.customElem ??= CustomElem();
        final current = message.customElem?.data;
        if (current == null || current.isEmpty) {
          final source = message.exMap['_serverContent'];
          if (source is Map<String, dynamic>) {
            message.customElem!.data = jsonEncode(source);
          } else if (source is String && source.isNotEmpty) {
            message.customElem!.data = source;
          } else if (payload['content'] is String &&
              (payload['content'] as String).isNotEmpty) {
            message.customElem!.data = payload['content'];
          }
        }
      }
    }
  }

  bool _hasContentElem(Message message) {
    final hasCustom = message.customElem != null &&
        (message.customElem!.data?.isNotEmpty == true);
    return message.textElem != null ||
        message.atTextElem != null ||
        message.quoteElem != null ||
        message.advancedTextElem != null ||
        message.pictureElem != null ||
        message.videoElem != null ||
        message.soundElem != null ||
        message.fileElem != null ||
        message.locationElem != null ||
        message.faceElem != null ||
        hasCustom;
  }

  void _copyElemIfNull<T>(
      T? Function() getter, void Function(T value) setter, T? source) {
    if (getter() == null && source != null) {
      setter(source);
    }
  }

  Map<String, dynamic>? _decodePayloadMap(Message message) {
    final raw = message.exMap['_serverContent'] ?? message.localEx ?? message.ex;
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    return null;
  }

  Future<void> _locateSearchMessage() async {
    final target = searchMessage;
    if (target == null) return;
    try {
      final before =
          await OpenIM.iMManager.messageManager.getAdvancedHistoryMessageList(
        conversationID: conversationInfo.conversationID,
        startMsg: target,
        count: _pageSize,
        viewType: GetHistoryViewType.search,
      );
      final after = await OpenIM.iMManager.messageManager
          .getAdvancedHistoryMessageListReverse(
        conversationID: conversationInfo.conversationID,
        startMsg: target,
        count: _pageSize,
        viewType: GetHistoryViewType.search,
      );
      final Map<String, Message> cache = {};
      void addAll(List<Message>? source) {
        if (source == null) return;
        for (final msg in source) {
          final id = msg.clientMsgID;
          if (id == null) continue;
          cache[id] = msg;
        }
      }

      addAll(before.messageList);
      if (target.clientMsgID != null) {
        cache[target.clientMsgID!] = target;
      }
      addAll(after.messageList);
      final list = cache.values.toList()
        ..sort((a, b) => (a.sendTime ?? 0).compareTo(b.sendTime ?? 0));
      if (list.isEmpty) {
        return;
      }
      messageList.assignAll(list);
      _purgeUnusedKeys();
      _isFirstLoad = false;
      final targetId = target.clientMsgID;
      _markHighlight(targetId);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (targetId != null) {
          _scrollToMessage(targetId);
        }
      });
    } catch (e, s) {
      Logger.print('locate search message failed $e $s');
    } finally {
      searchMessage = null;
    }
  }

  void locateSearchPreviewMessage(Message message) {
    searchMessage = message;
    _locateSearchMessage();
  }

  void _markHighlight(String? msgId) {
    highlightMsgId.value = msgId;
    if (msgId != null) {
      Future.delayed(const Duration(seconds: 3), () {
        if (highlightMsgId.value == msgId) {
          highlightMsgId.value = null;
        }
      });
    }
  }

  void _scrollToMessage(String msgId) {
    final key = _messageKeys[msgId];
    final context = key?.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: const Duration(milliseconds: 300),
      );
    }
  }

  GlobalKey itemContextKey(Message message) {
    final id = message.clientMsgID;
    if (id == null) {
      return GlobalKey();
    }
    return _messageKeys.putIfAbsent(id, () => GlobalKey());
  }

  void _purgeUnusedKeys() {
    final ids =
        messageList.map((e) => e.clientMsgID).whereType<String>().toSet();
    _messageKeys.removeWhere((key, value) => !ids.contains(key));
  }

  Future<AdvancedMessage> _fetchHistoryMessages() {
    Logger.print(
      '_fetchHistoryMessages: is first load: $_isFirstLoad, last client id: ${_isFirstLoad ? null : messageList.firstOrNull?.clientMsgID}',
    );
    return OpenIM.iMManager.messageManager.getAdvancedHistoryMessageList(
      conversationID: conversationInfo.conversationID,
      count: _pageSize,
      startMsg: _isFirstLoad ? null : messageList.firstOrNull,
    );
  }

  Future<bool> onScrollToBottomLoad() async {
    if (_skipFirstAutoLoad) {
      _skipFirstAutoLoad = false;
      return messageList.isNotEmpty;
    }
    if (_isInlineSearchMode) {
      await loadMoreGroupSearchResults();
      return hasMoreGroupSearchResult.value;
    }
    late List<Message> list;
    final result = await _fetchHistoryMessages();
    if (result.messageList == null || result.messageList!.isEmpty) {
      _getGroupInfoAfterLoadMessage();

      return false;
    }
    list = result.messageList!;
    if (_isFirstLoad) {
      _isFirstLoad = false;
      // remove the message that has been timed down
      messageList.assignAll(list);
      _purgeUnusedKeys();
      scrollBottom();

      _getGroupInfoAfterLoadMessage();
    } else {
      messageList.insertAll(0, list);
    }

    return result.isEnd != true;
  }

  Future<void> _loadHistoryForSyncEnd() async {
    final result =
        await OpenIM.iMManager.messageManager.getAdvancedHistoryMessageList(
      conversationID: conversationInfo.conversationID,
      count: messageList.length < _pageSize ? _pageSize : messageList.length,
      startMsg: null,
    );
    if (result.messageList == null || result.messageList!.isEmpty) return;
    final list = result.messageList!;

    final offset = scrollController.offset;
    messageList.assignAll(list);
    scrollController.jumpTo(offset);
    _purgeUnusedKeys();
  }

  Future<void> refreshLatestMessages() => _loadHistoryForSyncEnd();

  void _setupAudioPlayer() {
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed ||
          (!state.playing && state.processingState == ProcessingState.idle)) {
        playingVoiceMsgId.value = '';
        voiceProgress.value = 0.0;
      }
    });
    _audioPlayer.positionStream.listen((position) {
      if (playingVoiceMsgId.value.isEmpty) return;
      final total = _currentVoiceDurationMs > 0
          ? _currentVoiceDurationMs
          : _audioPlayer.duration?.inMilliseconds ?? 0;
      if (total <= 0) return;
      final progress = (position.inMilliseconds / total).clamp(0.0, 1.0);
      voiceProgress.value = progress;
    });
    _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        _currentVoiceDurationMs = duration.inMilliseconds;
      }
    });
  }

  void _getGroupInfoAfterLoadMessage() {
    if (isGroupChat && ownerAndAdmin.isEmpty) {
      _isJoinedGroup();
    } else {
      _checkInBlacklist();
    }
  }

  recommendFriendCarte(UserInfo userInfo) async {
    final result = await AppNavigator.startSelectContacts(
      action: SelAction.recommend,
      ex: '[${StrRes.carte}]${userInfo.nickname}',
    );
    if (null != result) {
      final customEx = result['customEx'];
      final checkedList = result['checkedList'];
      for (var info in checkedList) {
        final userID = IMUtils.convertCheckedToUserID(info);
        final groupID = IMUtils.convertCheckedToGroupID(info);
        if (customEx is String && customEx.isNotEmpty) {
          _sendMessage(
            await OpenIM.iMManager.messageManager.createTextMessage(
              text: customEx,
            ),
            userId: userID,
            groupId: groupID,
          );
        }
        _sendMessage(
          await OpenIM.iMManager.messageManager.createCardMessage(
            userID: userInfo.userID!,
            nickname: userInfo.nickname!,
            faceURL: userInfo.faceURL,
          ),
          userId: userID,
          groupId: groupID,
        );
      }
    }
  }

  @override
  void onDetached() {}

  @override
  void onHidden() {}

  @override
  void onInactive() {}

  @override
  void onPaused() {}

  @override
  void onResumed() {
    _loadHistoryForSyncEnd();
  }
}









