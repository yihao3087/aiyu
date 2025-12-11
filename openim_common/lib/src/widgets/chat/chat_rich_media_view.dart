import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:openim_common/openim_common.dart';

class ChatRichMediaView extends StatelessWidget {
  const ChatRichMediaView({
    super.key,
    required this.isISend,
    required this.text,
    required this.media,
    this.textScaleFactor = 1.0,
    required this.message,
    this.muted = false,
    this.layout = const <String>[],
  });

  final bool isISend;
  final String text;
  final List<Map<String, dynamic>> media;
  final double textScaleFactor;
  final Message message;
  final bool muted;
  final List<String> layout;

  List<_RichMediaAttachment> get _attachments => media
      .map(_RichMediaAttachment.fromJson)
      .where((element) => element.url.isNotEmpty)
      .toList();

  @override
  Widget build(BuildContext context) {
    final attachments = _attachments;
    if (text.trim().isEmpty && attachments.isEmpty) {
      return ChatText(
        isISend: isISend,
        text: '[${StrRes.richMedia}]',
        textScaleFactor: textScaleFactor,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final sections = <Widget>[];
        final normalizedLayout = _resolveLayoutOrder();
        final bubbleWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 247.w;
        final mediaSection = attachments.isEmpty
            ? null
            : _buildMediaSection(context, attachments, bubbleWidth);
        final textSection = text.trim().isEmpty ? null : _buildTextSection();

        void addSection(Widget? widget) {
          if (widget == null) return;
          if (sections.isNotEmpty) {
            sections.add(SizedBox(height: 8.h));
          }
          sections.add(widget);
        }

        for (final entry in normalizedLayout) {
          if (entry == _RichMediaSection.media) {
            addSection(mediaSection);
          } else if (entry == _RichMediaSection.text) {
            addSection(textSection);
          }
        }
        if (sections.isEmpty) {
          addSection(mediaSection);
          addSection(textSection);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: sections,
        );
      },
    );
  }

  List<_RichMediaSection> _resolveLayoutOrder() {
    final order = <_RichMediaSection>[];
    for (final entry in layout) {
      final normalized = entry.toLowerCase();
      if (normalized == 'media') {
        order.add(_RichMediaSection.media);
      } else if (normalized == 'text') {
        order.add(_RichMediaSection.text);
      }
    }
    if (order.isEmpty) {
      order.addAll([_RichMediaSection.media, _RichMediaSection.text]);
    }
    return order;
  }

  Widget _buildTextSection() => ChatText(
        isISend: isISend,
        text: text,
        textScaleFactor: textScaleFactor,
      );

  Widget _buildMediaSection(
    BuildContext context,
    List<_RichMediaAttachment> attachments,
    double bubbleWidth,
  ) {
    final double spacing = 8.w;
    final bool singleItem = attachments.length == 1;
    final double maxWidth = bubbleWidth;
    final double itemWidth = singleItem ? maxWidth : (maxWidth - spacing) / 2;
    final sources = List.generate(
      attachments.length,
      (index) => attachments[index].toMediaSource(
        tag: '${message.clientMsgID ?? message.serverMsgID ?? hashCode}_$index',
      ),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: bubbleWidth),
      child: Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: List.generate(attachments.length, (index) {
          final attach = attachments[index];
          final isSingle = attachments.length == 1;
          final previewWidth = isSingle ? bubbleWidth : itemWidth;
          return SizedBox(
            width: previewWidth,
            child: _RichMediaPreview(
              attachment: attach,
              isISend: isISend,
              durationLabel: attach.durationLabel,
              maxContentWidth: previewWidth,
              single: isSingle,
              onTap: () => IMUtils.previewMediaSources(
                context: context,
                sources: sources,
                initialIndex: index,
                muted: muted,
                onAutoPlay: (i) => sources[i].isVideo && i == index,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _RichMediaPreview extends StatelessWidget {
  const _RichMediaPreview({
    required this.attachment,
    required this.isISend,
    this.onTap,
    this.durationLabel,
    this.maxContentWidth,
    this.single = false,
  });

  final _RichMediaAttachment attachment;
  final bool isISend;
  final VoidCallback? onTap;
  final String? durationLabel;
  final double? maxContentWidth;
  final bool single;

  Size _resolveSize() {
    final double bubbleMaxWidth = 247.w;
    final double targetWidth =
        (maxContentWidth ?? bubbleMaxWidth).clamp(60.w, bubbleMaxWidth);
    final double ratio = attachment.aspectRatio;
    final double minHeight = 80;
    final double baseHeight = single ? targetWidth / ratio : targetWidth * 0.75;
    final double height =
        baseHeight.clamp(minHeight, single ? 320.h : baseHeight);
    return Size(targetWidth, height);
  }

  @override
  Widget build(BuildContext context) {
    final size = _resolveSize();
    Widget child;
    if (attachment.isVideo) {
      child = Stack(
        alignment: Alignment.center,
        children: [
          _buildImage(size),
          Container(
            width: 38.w,
            height: 38.w,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child:
                Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26.w),
          ),
          if (durationLabel != null)
            Positioned(
              right: 8.w,
              bottom: 6.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  durationLabel!,
                  style: Styles.ts_FFFFFF_12sp,
                ),
              ),
            ),
        ],
      );
    } else {
      child = _buildImage(size);
    }
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: _bubbleRadius(isISend),
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: child,
        ),
      ),
    );
  }

  Widget _buildImage(Size size) {
    final placeholderColor = Styles.c_8E9AB0_opacity30;
    final source = attachment.thumbnail?.isNotEmpty == true
        ? attachment.thumbnail
        : (attachment.url.isNotEmpty ? attachment.url : null);
    if (source != null) {
      return ImageUtil.networkImage(
        url: source,
        width: size.width,
        height: size.height,
        fit: BoxFit.cover,
      );
    }
    return Container(
      width: size.width,
      height: size.height,
      color: placeholderColor,
    );
  }
}

class _RichMediaAttachment {
  _RichMediaAttachment({
    required this.type,
    required this.url,
    this.thumbnail,
    this.width,
    this.height,
    this.duration,
  });

  factory _RichMediaAttachment.fromJson(Map<String, dynamic> map) {
    String _pickString(List<String> keys, {String? fallback}) {
      for (final key in keys) {
        final raw = map[key];
        final candidate = _resolveStringValue(raw);
        if (candidate.isNotEmpty) return candidate;
      }
      return fallback ?? '';
    }

    final resolvedUrl = _pickString(
      [
        'url',
        'sourceUrl',
        'videoUrl',
        'imageUrl',
        'originalUrl',
        'downloadUrl',
        'path',
        'fileUrl'
      ],
    );
    final resolvedThumbnail = _pickString(
      [
        'thumbnail',
        'thumb',
        'thumbUrl',
        'snapshot',
        'snapshotUrl',
        'snapshotPicture',
        'cover',
        'coverUrl',
        'preview',
        'previewUrl',
        'poster',
        'image',
        'picture',
      ],
      fallback: resolvedUrl,
    );

    double? _toDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        return parsed;
      }
      return null;
    }

    final type =
        (map['type'] ?? map['mediaType'] ?? map['format'] ?? '').toString();

    final normalizedUrl = IMUtils.resolveMediaUrl(resolvedUrl) ?? resolvedUrl;
    final normalizedThumbnail = IMUtils.resolveThumbnailUrl(
          resolvedThumbnail,
          fallback: normalizedUrl,
        ) ??
        normalizedUrl;

    return _RichMediaAttachment(
      type: type,
      url: normalizedUrl ?? '',
      thumbnail: normalizedThumbnail,
      width: _toDouble(map['width']),
      height: _toDouble(map['height']),
      duration: _toDouble(map['duration']),
    );
  }

  final String type;
  final String url;
  final String? thumbnail;
  final double? width;
  final double? height;
  final double? duration;

  bool get isVideo => type.toLowerCase().contains('video');
  double get aspectRatio {
    final w = width ?? 1;
    final h = height ?? 1;
    if (w <= 0 || h <= 0) return 1;
    return w / h;
  }

  String? get durationLabel {
    if (duration == null || duration! <= 0) return null;
    return IMUtils.seconds2HMS(duration!.round());
  }

  MediaSource toMediaSource({required String tag}) {
    return MediaSource(
      url: url,
      thumbnail: _resolvedThumbnail,
      isVideo: isVideo,
      tag: tag,
    );
  }

  String get _resolvedThumbnail {
    final candidate = (thumbnail?.isNotEmpty == true ? thumbnail! : url);
    return candidate.adjustThumbnailAbsoluteString(960);
  }

  static String _resolveStringValue(dynamic raw) {
    if (raw is String && raw.trim().isNotEmpty) {
      return raw.trim();
    }
    if (raw is Map) {
      final nested = raw['url'];
      if (nested is String && nested.trim().isNotEmpty) {
        return nested.trim();
      }
    }
    return '';
  }
}

BorderRadius _bubbleRadius(bool isISend) => BorderRadius.only(
      topLeft: Radius.circular(isISend ? 6.r : 0),
      topRight: Radius.circular(isISend ? 0 : 6.r),
      bottomLeft: Radius.circular(6.r),
      bottomRight: Radius.circular(6.r),
    );

enum _RichMediaSection {
  media,
  text,
}
