import 'package:animate_do/animate_do.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emoji_picker;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:openim_common/openim_common.dart';

double kInputBoxMinHeight = 48.h;

class ChatInputBox extends StatefulWidget {
  const ChatInputBox({
    Key? key,
    required this.toolbox,
    required this.voiceRecordBar,
    this.emojiPanelHeight,
    this.controller,
    this.focusNode,
    this.style,
    this.atStyle,
    this.enabled = true,
    this.isNotInGroup = false,
    this.hintText,
    this.forceCloseToolboxSub,
    this.quoteContent,
    this.onClearQuote,
    this.onSend,
    this.directionalText,
    this.onCloseDirectional,
  }) : super(key: key);
  final FocusNode? focusNode;
  final TextEditingController? controller;
  final TextStyle? style;
  final TextStyle? atStyle;
  final bool enabled;
  final bool isNotInGroup;
  final String? hintText;
  final Widget toolbox;
  final Widget voiceRecordBar;
  final double? emojiPanelHeight;
  final Stream? forceCloseToolboxSub;
  final String? quoteContent;
  final Function()? onClearQuote;
  final ValueChanged<String>? onSend;
  final TextSpan? directionalText;
  final VoidCallback? onCloseDirectional;

  @override
  State<ChatInputBox> createState() => _ChatInputBoxState();
}

class _ChatInputBoxState
    extends State<ChatInputBox> /*with TickerProviderStateMixin */ {
  bool _toolsVisible = false;
  bool _emojiVisible = false;
  bool _voiceMode = false;
  bool _sendButtonVisible = false;

  bool get _showQuoteView => IMUtils.isNotNullEmptyStr(widget.quoteContent);

  double get _opacity => (widget.enabled ? 1 : .4);

  bool get _showDirectionalView => widget.directionalText != null;

  @override
  void initState() {
    widget.focusNode?.addListener(() {
      if (widget.focusNode!.hasFocus) {
        setState(() {
          _toolsVisible = false;
          _emojiVisible = false;
        });
      }
    });

    widget.forceCloseToolboxSub?.listen((value) {
      if (!mounted) return;
      setState(() {
        _toolsVisible = false;
        _emojiVisible = false;
        _voiceMode = false;
      });
    });

    widget.controller?.addListener(() {
      setState(() {
        _sendButtonVisible = widget.controller!.text.isNotEmpty;
      });
    });

    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) widget.controller?.clear();
    return widget.isNotInGroup
        ? const ChatDisableInputBox()
        : Column(
            children: [
              Container(
                constraints: BoxConstraints(minHeight: kInputBoxMinHeight),
                padding: EdgeInsets.symmetric(vertical: 6.h),
                color: Styles.c_F0F2F6,
                child: Row(
                  children: [
                    12.horizontalSpace,
                    _buildEmojiButton(),
                    8.horizontalSpace,
                    Expanded(
                      child: Stack(
                        children: [
                          Offstage(
                            offstage: _voiceMode,
                            child: _textFiled,
                          ),
                          Offstage(
                            offstage: !_voiceMode,
                            child: Container(
                              margin: EdgeInsets.only(
                                top: 6.h,
                                bottom: _showQuoteView ? 2.h : 6.h,
                              ),
                              child: widget.voiceRecordBar,
                            ),
                          ),
                        ],
                      ),
                    ),
                    8.horizontalSpace,
                    _buildVoiceToggleButton(),
                    8.horizontalSpace,
                    if (_sendButtonVisible)
                      _buildSendButton()
                    else
                      _buildToolboxButton(),
                    12.horizontalSpace,
                  ],
                ),
              ),
              if (_showQuoteView)
                _SubView(
                  title: StrRes.reply,
                  content: widget.quoteContent,
                  onClose: widget.onClearQuote,
                ),
              if (_showDirectionalView)
                _SubView(
                  textSpan: widget.directionalText,
                  onClose: () {
                    widget.onCloseDirectional?.call();
                  },
                ),
              _buildExtraPanels(),
            ],
          );
  }

  Widget get _textFiled => Container(
        margin: EdgeInsets.only(top: 6.h, bottom: _showQuoteView ? 4.h : 6.h),
        decoration: BoxDecoration(
          color: Styles.c_FFFFFF,
          borderRadius: BorderRadius.circular(4.r),
        ),
        child: ChatTextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          style: widget.style ?? Styles.ts_0C1C33_17sp,
          atStyle: widget.atStyle ?? Styles.ts_0089FF_17sp,
          enabled: widget.enabled,
          hintText: widget.hintText,
          textAlign: widget.enabled ? TextAlign.start : TextAlign.center,
        ),
      );

  void send() {
    if (!widget.enabled) return;
    if (null != widget.onSend && null != widget.controller) {
      widget.onSend!(widget.controller!.text.toString().trim());
    }
  }

  void toggleToolbox() {
    if (!widget.enabled) return;
    setState(() {
      _toolsVisible = !_toolsVisible;
      _emojiVisible = false;
      _voiceMode = false;
      if (_toolsVisible) {
        unfocus();
      } else {
        focus();
      }
    });
  }

  void toggleEmoji() {
    if (!widget.enabled) return;
    setState(() {
      _emojiVisible = !_emojiVisible;
      if (_emojiVisible) {
        _toolsVisible = false;
        _voiceMode = false;
        unfocus();
      } else {
        focus();
      }
    });
  }

  void toggleVoiceMode() {
    if (!widget.enabled) return;
    setState(() {
      _voiceMode = !_voiceMode;
      if (_voiceMode) {
        _emojiVisible = false;
        _toolsVisible = false;
        unfocus();
      } else {
        focus();
      }
    });
  }

  Widget _buildEmojiButton() => (ImageRes.openEmoji.toImage
    ..width = 32.w
    ..height = 32.h
    ..opacity = _opacity
    ..onTap = toggleEmoji);

  Widget _buildVoiceToggleButton() {
    if (_voiceMode) {
      return (ImageRes.openKeyboard.toImage
        ..width = 32.w
        ..height = 32.h
        ..opacity = _opacity
        ..onTap = toggleVoiceMode);
    }
    return (ImageRes.openVoice.toImage
      ..width = 32.w
      ..height = 32.h
      ..opacity = _opacity
      ..onTap = () => Permissions.microphone(toggleVoiceMode));
  }

  Widget _buildEmojiPanel() {
    return SizedBox(
      height: widget.emojiPanelHeight ?? 260.h,
      child: emoji_picker.EmojiPicker(
        onEmojiSelected: (_, emoji) {
          final controller = widget.controller;
          if (controller == null) return;
          final text = controller.text;
          final selection = controller.selection;
          final start = selection.start >= 0 ? selection.start : text.length;
          final end = selection.end >= 0 ? selection.end : text.length;
          final newText = text.replaceRange(start, end, emoji.emoji);
          controller.value = TextEditingValue(
            text: newText,
            selection:
                TextSelection.collapsed(offset: start + emoji.emoji.length),
          );
          setState(() {
            _sendButtonVisible = controller.text.isNotEmpty;
          });
        },
        onBackspacePressed: () {
          final controller = widget.controller;
          if (controller == null) return;
          final selection = controller.selection;
          final text = controller.text;
          if (selection.start == selection.end && selection.start > 0) {
            final start = selection.start;
            final newText =
                text.substring(0, start - 1) + text.substring(selection.end);
            controller.value = TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(offset: start - 1),
            );
          } else if (selection.start != selection.end) {
            final newText =
                text.replaceRange(selection.start, selection.end, '');
            controller.value = TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(offset: selection.start),
            );
          }
          setState(() {
            _sendButtonVisible = controller.text.isNotEmpty;
          });
        },
        config: emoji_picker.Config(
          checkPlatformCompatibility: true,
          emojiViewConfig: emoji_picker.EmojiViewConfig(
            backgroundColor: Styles.c_F0F2F6,
            emojiSizeMax: 30,
            recentsLimit: 0,
            noRecents: const SizedBox.shrink(),
          ),
          categoryViewConfig: emoji_picker.CategoryViewConfig(
            backgroundColor: Styles.c_F0F2F6,
            indicatorColor: Styles.c_0089FF,
            iconColor: Styles.c_8E9AB0,
            iconColorSelected: Styles.c_0089FF,
            backspaceColor: Styles.c_0089FF,
            initCategory: emoji_picker.Category.SMILEYS,
            recentTabBehavior: emoji_picker.RecentTabBehavior.NONE,
            dividerColor: Styles.c_E8EAEF,
          ),
          bottomActionBarConfig: const emoji_picker.BottomActionBarConfig(
            enabled: false,
          ),
          searchViewConfig: emoji_picker.SearchViewConfig(
            backgroundColor: Colors.transparent,
            buttonIconColor: Colors.transparent,
            hintText: '',
            hintTextStyle: const TextStyle(height: 0, fontSize: 0),
            customSearchView: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  Widget _buildExtraPanels() {
    final panels = <Widget>[];
    if (_emojiVisible) {
      panels.add(_buildEmojiPanel());
    } else if (_toolsVisible) {
      panels.add(widget.toolbox);
    }

    if (panels.isEmpty) {
      return const SizedBox.shrink();
    }

    return FadeInUp(
      duration: const Duration(milliseconds: 200),
      child: Column(
        children: panels,
      ),
    );
  }

  focus() => FocusScope.of(context).requestFocus(widget.focusNode);

  unfocus() => FocusScope.of(context).requestFocus(FocusNode());

  Widget _buildSendButton() => GestureDetector(
        onTap: send,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: Styles.c_0089FF,
            borderRadius: BorderRadius.circular(18.r),
          ),
          child: Text(
            StrRes.send,
            style: Styles.ts_FFFFFF_14sp,
          ),
        ),
      );

  Widget _buildToolboxButton() => (ImageRes.openToolbox.toImage
        ..width = 32.w
        ..height = 32.h
        ..opacity = _opacity
        ..onTap = toggleToolbox);
}

class _SubView extends StatelessWidget {
  const _SubView({
    this.onClose,
    this.title,
    this.content,
    this.textSpan,
  }) : assert(content != null || textSpan != null,
            'Either content or textSpan must be provided.');
  final VoidCallback? onClose;
  final String? title;
  final String? content;
  final InlineSpan? textSpan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: 10.h, left: 56.w, right: 100.w),
      color: Styles.c_F0F2F6,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onClose,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 1.h, horizontal: 4.w),
          decoration: BoxDecoration(
            color: Styles.c_FFFFFF,
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Row(
                  children: [
                    if (title != null && title!.isNotEmpty)
                      Flexible(
                        child: Text(
                          title!,
                          style: Styles.ts_8E9AB0_14sp,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (content != null && content!.isNotEmpty)
                      Flexible(
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: title != null && title!.isNotEmpty ? 4.w : 0,
                          ),
                          child: Text(
                            content!,
                            style: Styles.ts_8E9AB0_14sp,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    if (textSpan != null)
                      Expanded(
                        child: RichText(
                          text: textSpan!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              ImageRes.delQuote.toImage
                ..width = 14.w
                ..height = 14.h,
            ],
          ),
        ),
      ),
    );
  }
}
