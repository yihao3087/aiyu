import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:openim/core/controller/im_controller.dart';
import 'package:openim_common/openim_common.dart';
import 'package:sprintf/sprintf.dart';

import 'conversation_logic.dart';

class ConversationPage extends StatefulWidget {
  const ConversationPage({super.key});

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage>
    with TickerProviderStateMixin {
  final logic = Get.find<ConversationLogic>();
  final im = Get.find<IMController>();
  final Map<String, _SlidableTracker> _trackers = {};
  static const double _actionExtentRatio = 0.22;

  String? _activeConversationId;

  @override
  void dispose() {
    for (final tracker in _trackers.values) {
      tracker.controller.dispose();
    }
    super.dispose();
  }

  _SlidableTracker _trackerFor(String conversationId) {
    return _trackers.putIfAbsent(
      conversationId,
      () {
        final controller = SlidableController(this);
        controller.animation.addListener(
          () => _handleControllerChanged(conversationId, controller),
        );
        return _SlidableTracker(
          controller: controller,
        );
      },
    );
  }

  void _handleControllerChanged(
    String conversationId,
    SlidableController controller,
  ) {
    final tracker = _trackers[conversationId];
    if (tracker == null) return;
    final ratio = controller.ratio;
    final isOpen = ratio.abs() > 0.01;
    if (isOpen) {
      final bool fromStart = ratio > 0;
      if (tracker.lastOpenFromStart != fromStart) {
        tracker.lastOpenFromStart = fromStart;
      }
      if (_activeConversationId != conversationId) {
        setState(() => _activeConversationId = conversationId);
      }
    } else if (_activeConversationId == conversationId) {
      setState(() => _activeConversationId = null);
    }
  }

  bool _closeActiveSlidable({
    Offset? pointerPosition,
    bool force = false,
  }) {
    final id = _activeConversationId;
    if (id == null) return false;
    if (!force &&
        pointerPosition != null &&
        _isPointInsideActionArea(id, pointerPosition)) {
      return false;
    }
    final tracker = _trackers[id];
    tracker?.controller.close();
    setState(() => _activeConversationId = null);
    return true;
  }

  bool _isPointInsideActionArea(String id, Offset position) {
    final tracker = _trackers[id];
    if (tracker == null) return false;
    final context = tracker.itemContext;
    if (context == null) return false;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return false;
    final origin = renderObject.localToGlobal(Offset.zero);
    final size = renderObject.size;
    final rect = Rect.fromLTWH(origin.dx, origin.dy, size.width, size.height);
    final width = size.width * _actionExtentRatio;
    final actionRect = tracker.lastOpenFromStart
        ? Rect.fromLTWH(rect.left, rect.top, width, rect.height)
        : Rect.fromLTWH(rect.right - width, rect.top, width, rect.height);
    return actionRect.contains(position);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _closeActiveSlidable(pointerPosition: event.position);
      },
      child: Obx(
        () => Scaffold(
          backgroundColor: Styles.c_F8F9FA,
          appBar: TitleBar.conversation(
            statusStr: logic.imSdkStatus,
            isFailed: logic.isFailedSdkStatus,
            popCtrl: logic.popCtrl,
            onAddFriend: logic.addFriend,
            onAddGroup: logic.addGroup,
            onCreateGroup: logic.createGroup,
            left: Expanded(
              flex: 2,
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  AvatarView(
                    width: 42.w,
                    height: 42.h,
                    text: im.userInfo.value.nickname,
                    url: im.userInfo.value.faceURL,
                  ),
                  10.horizontalSpace,
                  if (null != im.userInfo.value.nickname)
                    Flexible(
                      child: im.userInfo.value.nickname!.toText
                        ..style = Styles.ts_0C1C33_17sp
                        ..maxLines = 1
                        ..overflow = TextOverflow.ellipsis,
                    ),
                  10.horizontalSpace,
                  if (null != logic.imSdkStatus &&
                      (!logic.reInstall || logic.isFailedSdkStatus))
                    Flexible(
                      child: SyncStatusView(
                        isFailed: logic.isFailedSdkStatus,
                        statusStr: logic.imSdkStatus!,
                      ),
                    ),
                ],
              ),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: SlidableAutoCloseBehavior(
                  closeWhenTapped: true,
                  child: ListView.builder(
                    itemCount: logic.list.length,
                    itemBuilder: (_, index) {
                      final info = logic.list.elementAt(index);
                      return _buildSwipeItem(info);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeItem(ConversationInfo info) {
    final tracker = _trackerFor(info.conversationID);
    return Slidable(
      groupTag: 'conversationList',
      key: ValueKey(info.conversationID),
      controller: tracker.controller,
      closeOnScroll: true,
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: _actionExtentRatio,
        children: [
          SlidableAction(
            onPressed: (_) async {
              final success = await logic.markConversationAsRead(info);
              if (success) {
                _closeActiveSlidable(force: true);
              }
            },
            backgroundColor: Styles.c_0089FF,
            foregroundColor: Styles.c_FFFFFF,
            icon: Icons.done_all,
            label: StrRes.markHasRead,
            borderRadius: BorderRadius.circular(12.r),
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: _actionExtentRatio,
        children: [
          SlidableAction(
            onPressed: (_) async {
              final deleted = await logic.onTapDeleteConversation(info);
              if (deleted) {
                _closeActiveSlidable(force: true);
              }
            },
            backgroundColor: Styles.c_FF381F,
            foregroundColor: Styles.c_FFFFFF,
            icon: Icons.delete_outline,
            label: StrRes.delete,
            borderRadius: BorderRadius.circular(12.r),
          ),
        ],
      ),
      child: _buildItemView(info, tracker),
    );
  }

  Widget _buildItemView(ConversationInfo info, _SlidableTracker tracker) => Ink(
        child: InkWell(
          onTap: () {
            if (_closeActiveSlidable(force: true)) return;
            logic.toChat(conversationInfo: info);
          },
          onLongPress: () {
            if (_closeActiveSlidable(force: true)) return;
            logic.onConversationLongPress(info);
          },
          child: Stack(
            children: [
              Container(
                height: 68,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Builder(
                  builder: (itemContext) {
                    tracker.itemContext = itemContext;
                    return Row(
                      children: [
                        Stack(
                          children: [
                            AvatarView(
                              width: 48.w,
                              height: 48.h,
                              text: logic.getShowName(info),
                              url: info.faceURL,
                              isGroup: logic.isGroupChat(info),
                              textStyle: Styles.ts_FFFFFF_14sp_medium,
                            ),
                          ],
                        ),
                        12.horizontalSpace,
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: 180.w),
                                    child: logic.getShowName(info).toText
                                      ..style = Styles.ts_0C1C33_17sp
                                      ..maxLines = 1
                                      ..overflow = TextOverflow.ellipsis,
                                  ),
                                  const Spacer(),
                                  logic.getTime(info).toText
                                    ..style = Styles.ts_8E9AB0_12sp,
                                ],
                              ),
                              3.verticalSpace,
                              Row(
                                children: [
                                  MatchTextView(
                                    text: logic.getContent(info),
                                    textStyle: Styles.ts_8E9AB0_14sp,
                                    prefixSpan: TextSpan(
                                      text: '',
                                      children: [
                                        if (logic.getUnreadCount(info) > 0)
                                          TextSpan(
                                            text: '[${sprintf(StrRes.nPieces, [
                                                  logic.getUnreadCount(info)
                                                ])}] ',
                                            style: Styles.ts_8E9AB0_14sp,
                                          ),
                                        TextSpan(
                                          text: logic.getPrefixTag(info),
                                          style: Styles.ts_0089FF_14sp,
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Spacer(),
                                  UnreadCountView(
                                    count: logic.getUnreadCount(info),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
}

class _SlidableTracker {
  _SlidableTracker({
    required this.controller,
  });

  final SlidableController controller;
  BuildContext? itemContext;
  bool lastOpenFromStart = true;
}
