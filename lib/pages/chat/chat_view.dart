
import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:sprintf/sprintf.dart';

import 'chat_logic.dart';

class ChatPage extends StatelessWidget {
  final logic = Get.find<ChatLogic>(tag: GetTags.chat);

  ChatPage({super.key});

  Widget _buildItemView(
    Message message, {
    VoidCallback? onTap,
    bool enableReadReceipt = true,
    String? playingVoiceMsgId,
    double playingVoiceProgress = 0.0,
  }) {
    final isSelected = logic.isMessageSelected(message);
    final isHighlighted = logic.highlightMsgId.value == message.clientMsgID;
    final highlightColor = isSelected
        ? Styles.c_0089FF.withValues(alpha: 0.12)
        : isHighlighted
            ? Styles.c_FF381F.withValues(alpha: 0.16)
            : null;

    if (logic.isGroupChat &&
        _shouldHideGroupNotice(message.contentType)) {
      return const SizedBox.shrink();
    }
    return ChatItemView(
      key: logic.itemKey(message),
      message: message,
      textScaleFactor: logic.scaleFactor.value,
      allAtMap: logic.getAtMapping(message),
      timelineStr: logic.getShowTime(message),
      sendStatusSubject: logic.sendStatusSub,
      leftNickname: logic.getNewestNickname(message),
      leftFaceUrl: logic.getNewestFaceURL(message),
      rightNickname: logic.senderName,
      rightFaceUrl: OpenIM.iMManager.userInfo.faceURL,
      showLeftNickname: !logic.isSingleChat,
      showRightNickname: !logic.isSingleChat,
      onFailedToResend: () => logic.failedResend(message),
      onClickItemView: onTap ?? () => logic.onTapMessage(message),
      onTapQuote: (src, quote) => logic.onTapQuoteMessage(src, quote),
      highlightColor: highlightColor,
      visibilityChange: (msg, visible) {
        if (enableReadReceipt) {
          logic.markMessageAsRead(message, visible);
        }
      },
      onLongPressRightAvatar: () {},
      onTapLeftAvatar: () {
        logic.onTapLeftAvatar(message);
      },
      onVisibleTrulyText: (text) {
        logic.copyTextMap[message.clientMsgID] = text;
      },
      customTypeBuilder: _buildCustomTypeItemView,
      patterns: <MatchPattern>[
        MatchPattern(
          type: PatternType.email,
          onTap: logic.clickLinkText,
        ),
        MatchPattern(
          type: PatternType.url,
          onTap: logic.clickLinkText,
        ),
        MatchPattern(
          type: PatternType.mobile,
          onTap: logic.clickLinkText,
        ),
        MatchPattern(
          type: PatternType.tel,
          onTap: logic.clickLinkText,
        ),
      ],
      mediaItemBuilder: (context, message) {
        return _buildMediaItem(context, message);
      },
      onTapUserProfile: handleUserProfileTap,
      onLongPressMessage: (msg, rect) => logic.onLongPressMessage(msg, rect),
      onTapVoice: logic.playVoiceMessage,
      playingVoiceMsgId: playingVoiceMsgId,
      playingVoiceProgress: playingVoiceProgress,
      onSeekVoice: logic.seekVoiceMessage,
    );
  }

  void handleUserProfileTap(({String userID, String name, String? faceURL, String? groupID}) userProfile) {
    final userInfo = UserInfo(userID: userProfile.userID, nickname: userProfile.name, faceURL: userProfile.faceURL);
    logic.viewUserInfo(userInfo);
  }

  Widget? _buildMediaItem(BuildContext context, Message message) {
    if (message.contentType != MessageType.picture && message.contentType != MessageType.video) {
      return null;
    }

    return GestureDetector(
      onTap: () async {
        try {
          IMUtils.previewMediaFile(
              context: context,
              message: message,
              onAutoPlay: (index) {
                return !logic.playOnce;
              },
              muted: logic.rtcIsBusy,
              onPageChanged: (index) {
                logic.playOnce = true;
              }).then((value) {
            logic.playOnce = false;
          });
        } catch (e) {
          IMViews.showToast(e.toString());
        }
      },
      child: Hero(
        tag: message.clientMsgID!,
        child: _buildMediaContent(message),
        placeholderBuilder: (BuildContext context, Size heroSize, Widget child) => child,
      ),
    );
  }

  Widget _buildMediaContent(Message message) {
    final isOutgoing = message.sendID == OpenIM.iMManager.userID;

    if (message.isVideoType) {
      return const SizedBox();
    } else {
      return ChatPictureView(
        isISend: isOutgoing,
        message: message,
      );
    }
  }

  CustomTypeInfo? _buildCustomTypeItemView(_, Message message) {
    var data = IMUtils.parseCustomMessage(message);
    data ??= _decodeTelegramRichMedia(message);
    if (null != data) {
      final viewType = data['viewType'];
      if (viewType == CustomMessageType.call) {
        final type = data['type'];
        final content = data['content'];
        final isSend = message.sendID == OpenIM.iMManager.userID;
        final view = ChatCallItemView(
          type: type,
          content: content,
          isISend: isSend,
          onTap: logic.call,
        );
        return CustomTypeInfo(view);
      } else if (viewType == CustomMessageType.deletedByFriend || viewType == CustomMessageType.blockedByFriend) {
        final view = ChatFriendRelationshipAbnormalHintView(
          name: logic.nickname.value,
          onTap: logic.sendFriendVerification,
          blockedByFriend: viewType == CustomMessageType.blockedByFriend,
          deletedByFriend: viewType == CustomMessageType.deletedByFriend,
        );
        return CustomTypeInfo(view, false, false);
      } else if (viewType == CustomMessageType.removedFromGroup) {
        return CustomTypeInfo(
          StrRes.removedFromGroupHint.toText..style = Styles.ts_8E9AB0_12sp,
          false,
          false,
        );
      } else if (viewType == CustomMessageType.groupDisbanded) {
        return CustomTypeInfo(
          StrRes.groupDisbanded.toText..style = Styles.ts_8E9AB0_12sp,
          false,
          false,
        );
      } else if (viewType == CustomMessageType.telegramRichMedia) {
        final text = (data['text'] as String?) ?? '';
        final mediaList = (data['media'] as List?)
                ?.whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList() ??
            <Map<String, dynamic>>[];
        final layout = (data['layout'] as List?)
                ?.whereType<String>()
                .map((e) => e.toLowerCase())
                .toList() ??
            const <String>[];
        if (text.isNotEmpty) {
          logic.copyTextMap[message.clientMsgID] = text;
        }
        final view = ChatRichMediaView(
          isISend: message.sendID == OpenIM.iMManager.userID,
          text: text,
          media: mediaList,
          textScaleFactor: logic.scaleFactor.value,
          message: message,
          muted: logic.rtcIsBusy,
          layout: layout,
        );
        return CustomTypeInfo(view);
      }
    }
    return null;
  }

  Map<String, dynamic>? _decodeTelegramRichMedia(Message message) {
    final payload = IMUtils.decodeCustomMessageMap(message);
    final customType = IMUtils.customMessageType(message);
    if (payload == null || customType != CustomMessageType.telegramRichMedia) {
      return null;
    }
    final dataMap = IMUtils.customMessageData(message);
    final media = (dataMap['media'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final layout = (dataMap['layout'] as List? ?? const [])
        .whereType<String>()
        .map((e) => e.toLowerCase())
        .toList();
    final text = (dataMap['text'] as String?)?.trim() ?? '';
    return {
      'viewType': CustomMessageType.telegramRichMedia,
      'text': text,
      'media': media,
      'layout': layout,
      'content': text.isNotEmpty ? text : '[${StrRes.richMedia}]',
    };
  }

  bool _shouldHideGroupNotice(int? contentType) {
    if (contentType == null) return false;
    return contentType == MessageType.memberInvitedNotification ||
        contentType == MessageType.memberEnterNotification;
  }

  Widget? get _groupCallHintView => null;

  Widget _buildRightActions() {
    if (logic.isGroupChat) {
      return const SizedBox.shrink();
    }
    final children = <Widget>[];
    children.add(
      GestureDetector(
        onTap: logic.call,
        child: Icon(
          Icons.phone_in_talk_outlined,
          color: Styles.c_0C1C33,
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _buildMultiSelectBar() => Obx(() {
        final count = logic.selectedMessageCount;
        final label = count > 0
            ? sprintf(StrRes.selectedMessageCount, [count])
            : StrRes.selectMessages;
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Styles.c_FFFFFF,
            border: Border(
              top: BorderSide(color: Styles.c_E8EAEF, width: 0.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Styles.ts_0C1C33_14sp,
                ),
              ),
              _MultiActionButton(
                icon: ImageRes.multiBoxForward,
                label: StrRes.menuForward,
                onTap: logic.onMultiForward,
              ),
              const SizedBox(width: 16),
              _MultiActionButton(
                icon: ImageRes.multiBoxDel,
                label: StrRes.menuDel,
                onTap: logic.onMultiDelete,
              ),
            ],
          ),
        );
      });

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (logic.isMultiSelectMode.value) {
            logic.exitMultiSelectMode();
          } else {
            Get.back();
          }
        },
        child: Obx(() {
          return Scaffold(
              backgroundColor: Styles.c_F0F2F6,
              appBar: TitleBar.chat(
                title: logic.nickname.value,
                member: logic.isGroupChat ? null : logic.memberStr,
              isMultiModel: logic.isMultiSelectMode.value,
              onCloseMultiModel: () => logic.exitMultiSelectMode(),
              rightWidget: logic.isMultiSelectMode.value
                  ? const SizedBox.shrink()
                  : _buildRightActions(),
            ),
            body: SafeArea(
              child: WaterMarkBgView(
                text: '',
                path: logic.background.value,
                backgroundColor: Styles.c_FFFFFF,
                floatView: _groupCallHintView,
                bottomView: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (logic.isMultiSelectMode.value)
                      _buildMultiSelectBar(),
                    if (logic.isGroupChat)
                      _GroupSearchBar(logic: logic)
                    else
                      ChatInputBox(
                        forceCloseToolboxSub: logic.forceCloseToolbox,
                        controller: logic.inputCtrl,
                        focusNode: logic.focusNode,
                        isNotInGroup: logic.isInvalidGroup,
                        enabled: !logic.isMultiSelectMode.value,
                        directionalText: logic.directionalText(),
                        quoteContent: logic.replyPreview.value,
                        onClearQuote: () => logic.clearReply(showToast: true),
                        onCloseDirectional: logic.onClearDirectional,
                        onSend: (v) => logic.sendTextMsg(),
                        toolbox: ChatToolBox(
                          onTapAlbum: logic.onTapAlbum,
                          onTapCamera: logic.onTapCamera,
                          onTapLocation: logic.onTapLocation,
                          onTapCall: logic.isGroupChat ? null : logic.call,
                        ),
                        voiceRecordBar: ChatVoiceRecordBar(
                          onSend: logic.onVoiceRecordCompleted,
                        ),
                      ),
                  ],
                ),
                child: Obx(() {
                  final itemCount = logic.visibleMessageCount;
                  final enableReadReceipt = !logic.isInlineSearchResultMode.value;
                  final playingVoiceMsgId = logic.playingVoiceMsgId.value;
                  final voiceProgress = logic.voiceProgress.value;
                  return ChatListView(
                    onTouch: () => logic.closeToolbox(),
                    itemCount: itemCount,
                    controller: logic.scrollController,
                    onScrollToBottomLoad: logic.onScrollToBottomLoad,
                    onScrollToTop: logic.onScrollToTop,
                    itemBuilder: (_, index) {
                      final message = logic.indexOfMessage(index);
                      return _buildItemView(
                        message,
                        enableReadReceipt: enableReadReceipt,
                        playingVoiceMsgId: playingVoiceMsgId,
                        playingVoiceProgress: voiceProgress,
                      );
                    },
                  );
                }),
              ),
            ));
      }),
    );
  }
}

class _MultiActionButton extends StatelessWidget {

  const _MultiActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Styles.c_F0F2F6,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: icon.toImage
              ..width = 24
              ..height = 24,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Styles.ts_0C1C33_12sp,
          ),
        ],
      ),
    );
  }
}

class _GroupSearchBar extends StatelessWidget {
  const _GroupSearchBar({required this.logic});

  final ChatLogic logic;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Styles.c_F0F2F6,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Expanded(child: _buildTextField()),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: logic.onSearchActionTapped,
            style: ElevatedButton.styleFrom(
              backgroundColor: Styles.c_0089FF,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Text(StrRes.search),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField() {
    return Obx(() {
      final showClear = logic.inlineSearchCtrl.text.isNotEmpty ||
          logic.isInlineSearchResultMode.value;
      return TextField(
        controller: logic.inlineSearchCtrl,
        focusNode: logic.inlineSearchFocus,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: StrRes.groupSearchEnterKeyword,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: showClear
              ? IconButton(
                  onPressed: logic.clearGroupSearch,
                  icon: const Icon(Icons.close),
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
        onSubmitted: logic.onSearchFieldSubmitted,
      );
    });
  }
}



