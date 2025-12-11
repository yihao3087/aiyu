import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:azlistview/azlistview.dart';
import 'package:collection/collection.dart';
import 'package:common_utils/common_utils.dart';
import 'package:crypto/crypto.dart';
import 'package:dart_date/dart_date.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:mime/mime.dart';
import 'package:open_filex/open_filex.dart';
import 'package:openim_common/openim_common.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sprintf/sprintf.dart';
import 'package:uri_to_file/uri_to_file.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:flutter/foundation.dart';
import 'package:video_compress/video_compress.dart';

class IntervalDo {
  DateTime? last;
  Timer? lastTimer;

  void run({required Function() fuc, int milliseconds = 0}) {
    DateTime now = DateTime.now();
    if (null == last ||
        now.difference(last ?? now).inMilliseconds > milliseconds) {
      last = now;
      fuc();
    }
  }

  void drop({required Function() fun, int milliseconds = 0}) {
    lastTimer?.cancel();
    lastTimer = null;
    lastTimer = Timer(Duration(milliseconds: milliseconds), () {
      lastTimer!.cancel();
      lastTimer = null;
      fun.call();
    });
  }
}

class IMUtils {
  IMUtils._();

  static Future<CroppedFile?> uCrop(String path) {
    final aspectRatioPresets = <CropAspectRatioPresetData>[
      CropAspectRatioPreset.square,
      CropAspectRatioPreset.ratio3x2,
      CropAspectRatioPreset.original,
      CropAspectRatioPreset.ratio4x3,
      CropAspectRatioPreset.ratio16x9,
    ];
    return ImageCropper().cropImage(
      sourcePath: path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '',
          toolbarColor: Styles.c_0089FF,
          toolbarWidgetColor: Colors.white,
          aspectRatioPresets: aspectRatioPresets,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: '',
          aspectRatioPresets: aspectRatioPresets,
        ),
      ],
    );
  }

  static String getSuffix(String url) {
    if (!url.contains(".")) return "";
    return url.substring(url.lastIndexOf('.'), url.length);
  }

  static bool isGif(String url) {
    return IMUtils.getSuffix(url).contains("gif");
  }

  static void copy({required String text}) {
    Clipboard.setData(ClipboardData(text: text));
    IMViews.showToast(StrRes.copySuccessfully);
  }

  static String messageDigest(Message? message) {
    if (message == null) return '';
    final type = message.contentType;
    switch (type) {
      case MessageType.text:
        return message.textElem?.content ?? '';
      case MessageType.atText:
        return message.atTextElem?.text ?? message.textElem?.content ?? '';
      case MessageType.quote:
        return message.quoteElem?.text ?? '';
      case MessageType.advancedText:
        return message.advancedTextElem?.text ?? '';
      case MessageType.picture:
        return StrRes.picture;
      case MessageType.video:
        return StrRes.video;
      case MessageType.voice:
        return StrRes.voice;
      case MessageType.file:
        return message.fileElem?.fileName ?? StrRes.file;
      case MessageType.card:
        return message.cardElem?.nickname ?? StrRes.contacts;
      case MessageType.location:
        return message.locationElem?.description ?? StrRes.location;
      case MessageType.customFace:
        return StrRes.emoji;
      default:
        if (message.isEmojiType) {
          return StrRes.emoji;
        }
        if (type != null && type >= MessageType.notificationBegin) {
          return StrRes.notification;
        }
        return StrRes.unsupportedMessage;
    }
  }

  static List<ISuspensionBean> convertToAZList(List<ISuspensionBean> list) {
    for (int i = 0, length = list.length; i < length; i++) {
      setAzPinyinAndTag(list[i]);
    }

    SuspensionUtil.sortListBySuspensionTag(list);

    SuspensionUtil.setShowSuspensionStatus(list);

    return list;
  }

  static ISuspensionBean setAzPinyinAndTag(ISuspensionBean info) {
    if (info is ISUserInfo) {
      String pinyin = PinyinHelper.getPinyinE(info.showName);
      if (pinyin.trim().isEmpty) {
        info.tagIndex = "#";
      } else {
        String tag = pinyin.substring(0, 1).toUpperCase();
        info.namePinyin = pinyin.toUpperCase();
        if (RegExp("[A-Z]").hasMatch(tag)) {
          info.tagIndex = tag;
        } else {
          info.tagIndex = "#";
        }
      }
    } else if (info is ISGroupMembersInfo) {
      String pinyin = PinyinHelper.getPinyinE(info.nickname!);
      if (pinyin.trim().isEmpty) {
        info.tagIndex = "#";
      } else {
        String tag = pinyin.substring(0, 1).toUpperCase();
        info.namePinyin = pinyin.toUpperCase();
        if (RegExp("[A-Z]").hasMatch(tag)) {
          info.tagIndex = tag;
        } else {
          info.tagIndex = "#";
        }
      }
    }
    return info;
  }

  static saveMediaToGallery(String mimeType, String cachePath) async {
    if (mimeType.contains('video') || mimeType.contains('image')) {
      await ImageGallerySaverPlus.saveFile(cachePath);
    }
  }

  static String? emptyStrToNull(String? str) =>
      (null != str && str.trim().isEmpty) ? null : str;

  static bool isNotNullEmptyStr(String? str) => null != str && "" != str.trim();

  static bool isChinaMobile(String mobile) {
    RegExp exp = RegExp(
        r'^((13[0-9])|(14[0-9])|(15[0-9])|(16[0-9])|(17[0-9])|(18[0-9])|(19[0-9]))\d{8}$');
    return exp.hasMatch(mobile);
  }

  static bool isMobile(String areaCode, String mobile) =>
      (areaCode == '+86' || areaCode == '86') ? isChinaMobile(mobile) : true;

  static Future<MediaInfo> getMediaInfo(String path) {
    final mediaInfo = VideoCompress.getMediaInfo(path);

    return mediaInfo;
  }

  static Future<File?> compressImageAndGetFile(File file,
      {int quality = 80}) async {
    var path = file.path;
    var name = path.substring(path.lastIndexOf("/") + 1).toLowerCase();

    if (name.endsWith('.gif')) {
      return file;
    }

    CompressFormat format = CompressFormat.jpeg;
    if (name.endsWith(".jpg") || name.endsWith(".jpeg")) {
      format = CompressFormat.jpeg;
    } else if (name.endsWith(".png")) {
      format = CompressFormat.png;
    } else if (name.endsWith(".heic")) {
      format = CompressFormat.heic;
    } else if (name.endsWith(".webp")) {
      format = CompressFormat.webp;
    }

    var targetDirectory = await getTempDirectory(name);

    if (file.path == targetDirectory.path) {
      targetDirectory = await getTempDirectory('compressed-$name');
    }

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetDirectory.path,
      quality: quality,
      minWidth: 1280,
      minHeight: 720,
      format: format,
    );

    return result != null ? File(result.path) : file;
  }

  static Future<String> createTempFile({
    required String dir,
    required String name,
  }) async {
    final storage = await createTempDir(dir: dir);
    File file = File('$storage/$name');
    if (!(await file.exists())) {
      file.create();
    }
    return file.path;
  }

  static Future<String> createTempDir({
    required String dir,
  }) async {
    Directory directory = await getTempDirectory(dir);

    if (!(await directory.exists())) {
      directory.create(recursive: true);
    }
    return directory.path;
  }

  static Future<Directory> getTempDirectory(String dir) async {
    final storage = await getApplicationCacheDirectory();
    Directory directory = Directory('${storage.path}/$dir');

    return directory;
  }

  static int compareVersion(String val1, String val2) {
    var arr1 = val1.split(".");
    var arr2 = val2.split(".");
    int length = arr1.length >= arr2.length ? arr1.length : arr2.length;
    int diff = 0;
    int v1;
    int v2;
    for (int i = 0; i < length; i++) {
      v1 = i < arr1.length ? int.parse(arr1[i]) : 0;
      v2 = i < arr2.length ? int.parse(arr2[i]) : 0;
      diff = v1 - v2;
      if (diff == 0) {
        continue;
      } else {
        return diff > 0 ? 1 : -1;
      }
    }
    return diff;
  }

  static int getPlatform() {
    BuildContext? context;
    try {
      context = Get.context;
    } catch (_) {
      context = null;
    }
    final isTablet = context?.isTablet ?? _fallbackIsTablet();
    if (Platform.isAndroid) {
      return isTablet ? 8 : 2;
    }
    if (Platform.isIOS) {
      return isTablet ? 9 : 1;
    }
    // Fallback for other platforms to avoid crashes.
    return 2;
  }

  static bool _fallbackIsTablet() {
    try {
      final binding = WidgetsBinding.instance;
      final views = binding.platformDispatcher.views;
      if (views.isEmpty) return false;
      final view = views.first;
      final ratio = view.devicePixelRatio == 0 ? 1.0 : view.devicePixelRatio;
      final width = view.physicalSize.width / ratio;
      final height = view.physicalSize.height / ratio;
      final shortestSide = math.min(width, height);
      return shortestSide >= 600;
    } catch (_) {
      return false;
    }
  }

  static String? generateMD5(String? data) {
    if (null == data) return null;
    var content = const Utf8Encoder().convert(data);
    var digest = md5.convert(content);
    return digest.toString();
  }

  static String buildGroupApplicationID(GroupApplicationInfo info) {
    return '${info.groupID}-${info.creatorUserID}-${info.reqTime}-${info.userID}--${info.inviterUserID}';
  }

  static String buildFriendApplicationID(FriendApplicationInfo info) {
    return '${info.fromUserID}-${info.toUserID}-${info.createTime}';
  }

  static Future<String> getCacheFileDir() async {
    return (await getTemporaryDirectory()).absolute.path;
  }

  static Future<String> getAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  }

  static Future<String> getDownloadFileDir() async {
    String? externalStorageDirPath;
    if (Platform.isAndroid) {
      try {
        externalStorageDirPath =
            await PathProviderPlatform.instance.getDownloadsPath();
      } catch (err, st) {
        Logger.print('failed to get downloads path: $err, $st');
        final directory = await getExternalStorageDirectory();
        externalStorageDirPath = directory?.path;
      }
    } else if (Platform.isIOS) {
      externalStorageDirPath =
          (await getApplicationDocumentsDirectory()).absolute.path;
    }
    return externalStorageDirPath!;
  }

  static Future<String> toFilePath(String path) async {
    var filePrefix = 'file://';
    var uriPrefix = 'content://';
    if (path.contains(filePrefix)) {
      path = path.substring(filePrefix.length);
    } else if (path.contains(uriPrefix)) {
      File file = await toFile(path);
      path = file.path;
    }
    return path;
  }

  static List<Message> calChatTimeInterval(List<Message> list,
      {bool calculate = true}) {
    if (!calculate) return list;
    var milliseconds = list.firstOrNull?.sendTime;
    if (null == milliseconds) return list;
    list.first.exMap['showTime'] = true;
    var lastShowTimeStamp = milliseconds;
    for (var i = 0; i < list.length; i++) {
      var index = i + 1;
      if (index <= list.length - 1) {
        var cur = getDateTimeByMs(lastShowTimeStamp);
        var milliseconds = list.elementAt(index).sendTime!;
        var next = getDateTimeByMs(milliseconds);
        if (next.difference(cur).inMinutes > 5) {
          lastShowTimeStamp = milliseconds;
          list.elementAt(index).exMap['showTime'] = true;
        }
      }
    }
    return list;
  }

  static String getChatTimeline(int ms, [String formatToday = 'HH:mm']) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(ms);
    final languageCode = Get.locale?.languageCode ?? 'zh';
    final isChinese = languageCode == 'zh';
    final now = DateTime.now();
    final formatter = DateFormat(formatToday);

    if (isSameDay(dateTime, now)) {
      return formatter.format(
        dateTime,
      );
    }

    final yesterday = now.subtract(Duration(days: 1));

    if (isSameDay(dateTime, yesterday)) {
      return isChinese
          ? '昨天 ${formatter.format(dateTime)}'
          : 'Yesterday ${formatter.format(dateTime)}';
    }

    if (isSameWeek(dateTime, now)) {
      final weekDay = DateFormat('EEEE').format(dateTime);
      final weekDayChinese = {
        'Monday': StrRes.monday,
        'Tuesday': StrRes.tuesday,
        'Wednesday': StrRes.wednesday,
        'Thursday': StrRes.thursday,
        'Friday': StrRes.friday,
        'Saturday': StrRes.saturday,
        'Sunday': StrRes.sunday,
      };
      return '${isChinese ? weekDayChinese[weekDay]! : weekDay} ${formatter.format(dateTime)}';
    }

    if (dateTime.year == now.year) {
      final dateFormat = isChinese ? 'MM月dd HH:mm' : 'MM/dd HH:mm';
      return DateFormat(dateFormat).format(dateTime);
    }

    final dateFormat = isChinese ? 'yyyy年MM月dd HH:mm' : 'yyyy/MM/dd HH:mm';
    return DateFormat(dateFormat).format(dateTime);
  }

  static bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  static bool isSameWeek(DateTime date1, DateTime date2) {
    final weekStart = date2.subtract(Duration(days: date2.weekday - 1));
    final weekEnd = weekStart.add(Duration(days: 6));
    return date1.isAfter(weekStart.subtract(Duration(days: 1))) &&
        date1.isBefore(weekEnd.add(Duration(days: 1)));
  }

  static String getCallTimeline(int milliseconds) {
    if (DateUtil.yearIsEqualByMs(milliseconds, DateUtil.getNowDateMs())) {
      return formatDateMs(milliseconds, format: 'MM/dd');
    } else {
      return formatDateMs(milliseconds, format: 'yyyy/MM/dd');
    }
  }

  static DateTime getDateTimeByMs(int ms, {bool isUtc = false}) {
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: isUtc);
  }

  static String formatDateMs(int ms, {bool isUtc = false, String? format}) {
    return DateUtil.formatDateMs(ms, format: format, isUtc: isUtc);
  }

  static String seconds2HMS(int seconds) {
    int h = 0;
    int m = 0;
    int s = 0;
    int temp = seconds % 3600;
    if (seconds > 3600) {
      h = seconds ~/ 3600;
      if (temp != 0) {
        if (temp > 60) {
          m = temp ~/ 60;
          if (temp % 60 != 0) {
            s = temp % 60;
          }
        } else {
          s = temp;
        }
      }
    } else {
      m = seconds ~/ 60;
      if (seconds % 60 != 0) {
        s = seconds % 60;
      }
    }
    if (h == 0) {
      return '${m < 10 ? '0$m' : m}:${s < 10 ? '0$s' : s}';
    }
    return "${h < 10 ? '0$h' : h}:${m < 10 ? '0$m' : m}:${s < 10 ? '0$s' : s}";
  }

  static Map<String, List<Message>> groupingMessage(List<Message> list) {
    var languageCode = Get.locale?.languageCode ?? 'zh';
    var group = <String, List<Message>>{};
    for (var message in list) {
      var dateTime = DateTime.fromMillisecondsSinceEpoch(message.sendTime!);
      String dateStr;
      if (DateUtil.isToday(message.sendTime!)) {
        dateStr = languageCode == 'zh' ? '今天' : 'Today';
      } else if (DateUtil.isWeek(message.sendTime!)) {
        dateStr = languageCode == 'zh' ? '本周' : 'This Week';
      } else if (dateTime.isThisMonth) {
        dateStr = languageCode == 'zh' ? '这个月' : 'This Month';
      } else {
        dateStr = DateUtil.formatDate(dateTime, format: 'yyyy/MM');
      }
      group[dateStr] = (group[dateStr] ?? <Message>[])..add(message);
    }
    return group;
  }

  static String mutedTime(int mss) {
    int days = mss ~/ (60 * 60 * 24);
    int hours = (mss % (60 * 60 * 24)) ~/ (60 * 60);
    int minutes = (mss % (60 * 60)) ~/ 60;
    int seconds = mss % 60;
    return "${_combTime(days, StrRes.day)}${_combTime(hours, StrRes.hours)}${_combTime(minutes, StrRes.minute)}${_combTime(seconds, StrRes.seconds)}";
  }

  static String _combTime(int value, String unit) =>
      value > 0 ? '$value$unit' : '';

  static String calContent({
    required String content,
    required String key,
    required TextStyle style,
    required double usedWidth,
  }) {
    var size = calculateTextSize(content, style);
    var lave = 1.sw - usedWidth;
    if (size.width < lave) {
      return content;
    }
    var index = content.indexOf(key);
    if (index == -1 || index > content.length - 1) return content;
    var start = content.substring(0, index);
    var end = content.substring(index);
    var startSize = calculateTextSize(start, style);
    var keySize = calculateTextSize(key, style);
    if (startSize.width + keySize.width > lave) {
      if (index - 4 > 0) {
        return "...${content.substring(index - 4)}";
      } else {
        return "...$end";
      }
    } else {
      return content;
    }
  }

  static Size calculateTextSize(
    String text,
    TextStyle style, {
    int maxLines = 1,
    double maxWidth = double.infinity,
  }) {
    final TextPainter textPainter = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: maxLines,
        textDirection: TextDirection.ltr)
      ..layout(minWidth: 0, maxWidth: maxWidth);
    return textPainter.size;
  }

  static TextPainter getTextPainter(
    String text,
    TextStyle style, {
    int maxLines = 1,
    double maxWidth = double.infinity,
  }) =>
      TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: maxLines,
          textDirection: TextDirection.ltr)
        ..layout(minWidth: 0, maxWidth: maxWidth);

  static bool isUrlValid(String? url) {
    if (null == url || url.isEmpty) {
      return false;
    }
    return url.startsWith("http://") || url.startsWith("https://");
  }

  /// Normalize media url to absolute path using current server config.
  static String? resolveMediaUrl(String? rawUrl) {
    if (rawUrl == null) return null;
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('//')) {
      return '${_defaultScheme()}$trimmed';
    }
    final normalized = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '${_defaultOrigin()}$normalized';
  }

  /// Resolve thumbnail url and ensure it has thumbnail query params.
  static String? resolveThumbnailUrl(String? url, {String? fallback}) {
    final target = resolveMediaUrl(url) ?? resolveMediaUrl(fallback);
    if (target == null || target.isEmpty) return null;
    return target.adjustThumbnailAbsoluteString(960);
  }

  static String _defaultScheme() {
    final api = Config.imApiUrl;
    return api.startsWith('https') ? 'https:' : 'http:';
  }

  static String _defaultOrigin() {
    final api = Config.imApiUrl;
    final uri = Uri.tryParse(api);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      final port = uri.hasPort ? ':${uri.port}' : '';
      return '${uri.scheme}://${uri.host}$port';
    }
    final scheme = api.startsWith('https') ? 'https' : 'http';
    final host = Config.serverIp;
    return '$scheme://$host';
  }

  static bool isValidUrl(String? urlString) {
    if (null == urlString || urlString.isEmpty) {
      return false;
    }
    Uri? uri = Uri.tryParse(urlString);
    if (uri != null && uri.hasScheme && uri.hasAuthority) {
      return true;
    }
    return false;
  }

  static String getGroupMemberShowName(GroupMembersInfo membersInfo) {
    return membersInfo.userID == OpenIM.iMManager.userID
        ? StrRes.you
        : membersInfo.nickname!;
  }

  static String getShowName(String? userID, String? nickname) {
    return (userID == OpenIM.iMManager.userID
            ? OpenIM.iMManager.userInfo.nickname
            : nickname) ??
        '';
  }

  static String? parseNtf(
    Message message, {
    bool isConversation = false,
  }) {
    String? text;
    try {
      if (message.contentType! >= 1000) {
        final elem = message.notificationElem!;
        final map = json.decode(elem.detail!);
        switch (message.contentType) {
          case MessageType.groupCreatedNotification:
            {
              final ntf = GroupNotification.fromJson(map);

              final label = StrRes.createGroupNtf;
              text = sprintf(label, [getGroupMemberShowName(ntf.opUser!)]);
            }
            break;
          case MessageType.groupInfoSetNotification:
            {
              final ntf = GroupNotification.fromJson(map);
              if (ntf.group?.notification != null &&
                  ntf.group!.notification!.isNotEmpty) {
                return isConversation ? ntf.group!.notification! : null;
              }

              final label = StrRes.editGroupInfoNtf;
              text = sprintf(label, [getGroupMemberShowName(ntf.opUser!)]);
            }
            break;
          case MessageType.memberQuitNotification:
            {
              final ntf = QuitGroupNotification.fromJson(map);

              final label = StrRes.quitGroupNtf;
              text = sprintf(label, [getGroupMemberShowName(ntf.quitUser!)]);
            }
            break;
          case MessageType.memberInvitedNotification:
            {
              final ntf = InvitedJoinGroupNotification.fromJson(map);

              final label = StrRes.invitedJoinGroupNtf;
              final b = ntf.invitedUserList
                  ?.map((e) => getGroupMemberShowName(e))
                  .toList()
                  .join('、');
              text = sprintf(
                  label, [getGroupMemberShowName(ntf.opUser!), b ?? '']);
            }
            break;
          case MessageType.memberKickedNotification:
            {
              final ntf = KickedGroupMemeberNotification.fromJson(map);

              final label = StrRes.kickedGroupNtf;
              final b = ntf.kickedUserList!
                  .map((e) => getGroupMemberShowName(e))
                  .toList()
                  .join('、');
              text = sprintf(label, [b, getGroupMemberShowName(ntf.opUser!)]);
            }
            break;
          case MessageType.memberEnterNotification:
            {
              final ntf = EnterGroupNotification.fromJson(map);

              final label = StrRes.joinGroupNtf;
              text = sprintf(label, [getGroupMemberShowName(ntf.entrantUser!)]);
            }
            break;
          case MessageType.dismissGroupNotification:
            {
              final ntf = GroupNotification.fromJson(map);

              final label = StrRes.dismissGroupNtf;
              text = sprintf(label, [getGroupMemberShowName(ntf.opUser!)]);
            }
            break;
          case MessageType.groupOwnerTransferredNotification:
            {
              final ntf = GroupRightsTransferNoticication.fromJson(map);

              final label = StrRes.transferredGroupNtf;
              text = sprintf(label, [
                getGroupMemberShowName(ntf.opUser!),
                getGroupMemberShowName(ntf.newGroupOwner!)
              ]);
            }
            break;
          case MessageType.groupMemberMutedNotification:
            {
              final ntf = MuteMemberNotification.fromJson(map);

              final label = StrRes.muteMemberNtf;
              final c = ntf.mutedSeconds;
              text = sprintf(label, [
                getGroupMemberShowName(ntf.mutedUser!),
                getGroupMemberShowName(ntf.opUser!),
                mutedTime(c!)
              ]);
            }
            break;
          case MessageType.groupMemberCancelMutedNotification:
            {
              final ntf = MuteMemberNotification.fromJson(map);

              final label = StrRes.muteCancelMemberNtf;
              text = sprintf(label, [
                getGroupMemberShowName(ntf.mutedUser!),
                getGroupMemberShowName(ntf.opUser!)
              ]);
            }
            break;
          case MessageType.groupMutedNotification:
            {
              final ntf = MuteMemberNotification.fromJson(map);

              final label = StrRes.muteGroupNtf;
              text = sprintf(label, [getGroupMemberShowName(ntf.opUser!)]);
            }
            break;
          case MessageType.groupCancelMutedNotification:
            {
              final ntf = MuteMemberNotification.fromJson(map);

              final label = StrRes.muteCancelGroupNtf;
              text = sprintf(label, [getGroupMemberShowName(ntf.opUser!)]);
            }
            break;
          case MessageType.friendApplicationApprovedNotification:
            {
              text = StrRes.friendAddedNtf;
            }
            break;
          case MessageType.burnAfterReadingNotification:
            {
              final ntf = BurnAfterReadingNotification.fromJson(map);
              if (ntf.isPrivate == true) {
                text = StrRes.openPrivateChatNtf;
              } else {
                text = StrRes.closePrivateChatNtf;
              }
            }
            break;
          case MessageType.groupMemberInfoChangedNotification:
            final ntf = GroupMemberInfoChangedNotification.fromJson(map);
            text = sprintf(StrRes.memberInfoChangedNtf,
                [getGroupMemberShowName(ntf.opUser!)]);
            break;
          case MessageType.groupInfoSetAnnouncementNotification:
            if (isConversation) {
              final ntf = GroupNotification.fromJson(map);
              text = ntf.group?.notification ?? '';
            }
            break;
          case MessageType.groupInfoSetNameNotification:
            final ntf = GroupNotification.fromJson(map);
            text = sprintf(StrRes.whoModifyGroupName,
                [getGroupMemberShowName(ntf.opUser!), ntf.group?.groupName]);
            break;
        }
      }
    } catch (e, s) {
      Logger.print('Exception details:\n $e');
      Logger.print('Stack trace:\n $s');
    }
    return text;
  }

  static String parseMsg(
    Message message, {
    bool isConversation = false,
    bool replaceIdToNickname = false,
  }) {
    String? content;
    try {
      switch (message.contentType) {
        case MessageType.text:
          content = message.textElem?.content;
          break;
        case MessageType.picture:
          content = '[${StrRes.picture}]';
          break;
        case MessageType.voice:
          final duration = message.soundElem?.duration ?? 0;
          content = '[${StrRes.voice}]${duration > 0 ? ' ${duration}s' : ''}';
          break;
        case MessageType.video:
          content = '[${StrRes.video}]';
          break;
        case MessageType.file:
          final fileName = message.fileElem?.fileName;
          content = fileName?.isNotEmpty == true
              ? '[${StrRes.file}] $fileName'
              : '[${StrRes.file}]';
          break;
        case MessageType.location:
          final desc = message.locationElem?.description;
          content = desc?.isNotEmpty == true
              ? '[${StrRes.location}] $desc'
              : '[${StrRes.location}]';
          break;
        case MessageType.atText:
          content = message.atTextElem?.text ?? message.textElem?.content ?? '';
          break;
        case MessageType.customFace:
          content = '[${StrRes.emoji}]';
          break;
        case MessageType.custom:
          final payload = parseCustomMessage(message);
          if (payload is Map) {
            final customContent = payload['content'];
            if (customContent is String && customContent.isNotEmpty) {
              content = customContent;
            } else {
              final viewType = payload['viewType'];
              if (viewType == CustomMessageType.emoji) {
                content = StrRes.emoji;
              } else if (viewType == CustomMessageType.meeting) {
                content = StrRes.videoMeeting;
              } else if (viewType == CustomMessageType.tag) {
                final name = payload['name'];
                content =
                    name is String && name.isNotEmpty ? name : StrRes.tagGroup;
              } else if (viewType == CustomMessageType.blockedByFriend) {
                content = StrRes.blockedByFriendHint;
              } else if (viewType == CustomMessageType.deletedByFriend) {
                content = sprintf(StrRes.deletedByFriendHint, ['']);
              } else if (viewType == CustomMessageType.removedFromGroup) {
                content = StrRes.removedFromGroupHint;
              } else if (viewType == CustomMessageType.groupDisbanded) {
                content = StrRes.groupDisbanded;
              } else if (viewType == CustomMessageType.telegramRichMedia) {
                final richText = payload['text'];
                final textStr = richText is String ? richText.trim() : '';
                content = textStr.isEmpty
                    ? '[${StrRes.richMedia}]'
                    : '[${StrRes.richMedia}] $textStr';
              }
            }
          }
          break;
        default:
          content = '[${StrRes.unsupportedMessage}]';
          break;
      }
    } catch (e, s) {
      Logger.print('Exception details:\n $e');
      Logger.print('Stack trace:\n $s');
    }
    content = content?.replaceAll("\n", " ");
    return content ?? '[${StrRes.unsupportedMessage}]';
  }

  static Map<String, dynamic>? decodeCustomMessageMap(Message message) {
    if (message.contentType != MessageType.custom) {
      return null;
    }
    final payload = _resolveCustomPayloadString(message);
    if (payload == null || payload.isEmpty) {
      return null;
    }
    try {
      final decoded = json.decode(payload);
      final root = _ensureMap(decoded);
      final flattened = _flattenCustomPayloadMap(root);
      final effective = flattened ?? root;
      final normalized = Map<String, dynamic>.from(effective);
      final customType = _parseCustomTypeValue(normalized['customType']);
      if (customType != null) {
        normalized['customType'] = customType;
      }
      normalized['data'] = _ensureMap(normalized['data']);
      return normalized;
    } catch (e, s) {
      Logger.print('decodeCustomMessageMap failed: $e');
      Logger.print('Stack trace:\n $s');
    }
    return null;
  }

  static int? customMessageType(Message message) {
    final map = decodeCustomMessageMap(message);
    if (map == null) return null;
    return _parseCustomTypeValue(map['customType']);
  }

  static Map<String, dynamic> customMessageData(Message message) {
    final map = decodeCustomMessageMap(message);
    if (map == null) return <String, dynamic>{};
    return _ensureMap(map['data']);
  }

  static bool isSdkNotInitError(Object e) {
    if (e is PlatformException) {
      if (e.code == '10006') return true;
      final msg = '${e.message ?? ''}${e.details ?? ''}'.toLowerCase();
      if (msg.contains('sdk not init')) return true;
    }
    return false;
  }

  static Future<T> runWithImReady<T>(
    Future<T> Function() task, {
    int maxRetry = 3,
    Duration delay = const Duration(milliseconds: 300),
  }) async {
    PlatformException? last;
    for (var attempt = 0; attempt < maxRetry; attempt++) {
      try {
        return await task();
      } on PlatformException catch (e) {
        if (!isSdkNotInitError(e) || attempt == maxRetry - 1) {
          rethrow;
        }
        last = e;
        final wait = delay * (attempt + 1);
        await Future.delayed(wait);
      }
    }
    if (last != null) {
      throw last;
    }
    throw PlatformException(code: 'sdk_not_ready');
  }

  static int? _parseCustomTypeValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String? _resolveCustomPayloadString(Message message) {
    final sources = <dynamic>[
      message.customElem?.data,
      message.exMap['_serverContent'],
      message.localEx,
      message.ex,
      message.attachedInfo,
    ];
    for (final source in sources) {
      final normalized = _normalizeCustomPayloadSource(source);
      if (normalized != null && normalized.isNotEmpty) {
        message.customElem ??= CustomElem();
        message.customElem!.data = normalized;
        return normalized;
      }
    }
    return null;
  }

  static String? _normalizeCustomPayloadSource(dynamic source) {
    if (source == null) return null;
    if (source is Map) {
      try {
        return jsonEncode(_mapFromDynamic(source));
      } catch (_) {
        return null;
      }
    }
    if (source is List) {
      try {
        return jsonEncode(source);
      } catch (_) {
        return null;
      }
    }
    if (source is String) {
      final trimmed = source.trim();
      if (trimmed.isEmpty) return null;
      final sanitized = _stripBom(trimmed);
      if (_looksLikeJsonPayload(sanitized)) {
        return sanitized;
      }
      final base64Decoded = _tryDecodeBase64(sanitized);
      if (base64Decoded != null && _looksLikeJsonPayload(base64Decoded)) {
        return base64Decoded;
      }
      try {
        final decoded = json.decode(sanitized);
        if (decoded is Map || decoded is List) {
          return jsonEncode(decoded);
        } else if (decoded is String) {
          final nested = _stripBom(decoded.trim());
          if (_looksLikeJsonPayload(nested)) {
            return nested;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  static bool _looksLikeJsonPayload(String text) {
    if (text.isEmpty) return false;
    final trimmed = text.trimLeft();
    if (trimmed.isEmpty) return false;
    final first = trimmed[0];
    return first == '{' || first == '[';
  }

  static String? _tryDecodeBase64(String text) {
    try {
      final normalized = text.replaceAll('\n', '').replaceAll('\r', '');
      final decoded = utf8.decode(base64.decode(normalized));
      return _stripBom(decoded.trim());
    } catch (_) {
      return null;
    }
  }

  static String _stripBom(String text) =>
      text.startsWith('\ufeff') ? text.substring(1) : text;

  static Map<String, dynamic> _mapFromDynamic(Map source) {
    final map = <String, dynamic>{};
    source.forEach((key, value) {
      final stringKey = key is String ? key : key?.toString();
      if (stringKey != null && stringKey.isNotEmpty) {
        map[stringKey] = value;
      }
    });
    return map;
  }

  static Map<String, dynamic> _ensureMap(dynamic value) {
    if (value == null) return <String, dynamic>{};
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return _mapFromDynamic(value);
    }
    if (value is String) {
      try {
        final decoded = json.decode(value);
        if (decoded is Map) {
          return _mapFromDynamic(decoded);
        }
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  static Map<String, dynamic>? _flattenCustomPayloadMap(
      Map<String, dynamic> source) {
    final customType = _parseCustomTypeValue(source['customType']);
    if (customType != null) {
      final map = Map<String, dynamic>.from(source);
      map['customType'] = customType;
      map['data'] = _ensureMap(map['data']);
      return map;
    }
    final data = source['data'];
    if (data is String && _looksLikeJsonPayload(data)) {
      final nested = _flattenCustomPayloadMap(_ensureMap(data));
      if (nested != null) return nested;
    } else if (data is Map) {
      final nested = _flattenCustomPayloadMap(_ensureMap(data));
      if (nested != null) return nested;
    }
    final serverContent = source['_serverContent'];
    if (serverContent is String && _looksLikeJsonPayload(serverContent)) {
      final nested = _flattenCustomPayloadMap(_ensureMap(serverContent));
      if (nested != null) return nested;
    } else if (serverContent is Map) {
      final nested = _flattenCustomPayloadMap(_ensureMap(serverContent));
      if (nested != null) return nested;
    }
    return null;
  }

  static dynamic parseCustomMessage(Message message) {
    try {
      switch (message.contentType) {
        case MessageType.custom:
          {
            final map = decodeCustomMessageMap(message);
            if (map == null) break;
            final customType = _parseCustomTypeValue(map['customType']);
            if (customType == null) break;
            final data = _ensureMap(map['data']);
            switch (customType) {
              case CustomMessageType.call:
                {
                    final duration = data['duration'];
                    final state = data['state'] as String?;
                    final type = data['type'];
                    String? content;
                    final durationSeconds =
                        duration is num ? duration.round() : 0;
                    final hasDuration = durationSeconds >= 0;
                    final durationText = seconds2HMS(durationSeconds);
                    switch (state) {
                      case 'hangup':
                        content = hasDuration
                            ? sprintf(StrRes.callDurationCaller, [durationText])
                            : sprintf(StrRes.callDurationCaller, ['00:00']);
                        break;
                      case 'beHangup':
                        content = hasDuration
                            ? sprintf(StrRes.callDurationCallee, [durationText])
                            : sprintf(StrRes.callDurationCallee, ['00:00']);
                        break;
                      case 'cancel':
                        content = StrRes.cancelled;
                        break;
                    case 'beCanceled':
                      content = StrRes.cancelledByCaller;
                      break;
                    case 'reject':
                      content = StrRes.rejected;
                      break;
                    case 'beRejected':
                      content = StrRes.rejectedByCaller;
                      break;
                    case 'timeout':
                      content = StrRes.callTimeout;
                      break;
                    case 'networkError':
                      content = StrRes.networkAnomaly;
                      break;
                    case 'call':
                    case 'beCalled':
                    case 'calling':
                    case 'beAccepted':
                    case 'connecting':
                    case 'join':
                      content = StrRes.calling;
                      break;
                    case 'otherAccepted':
                    case 'otherReject':
                      content = StrRes.callingInterruption;
                      break;
                    default:
                      content ??= hasDuration
                          ? sprintf(StrRes.callDurationCaller,
                              [seconds2HMS(durationSeconds)])
                          : StrRes.callingInterruption;
                      break;
                  }
                  if (content != null) {
                    return {
                      'viewType': CustomMessageType.call,
                      'type': type,
                      'content': content,
                    };
                  }
                }
                break;
              case CustomMessageType.callingInvite:
              case CustomMessageType.callingAccept:
              case CustomMessageType.callingReject:
              case CustomMessageType.callingCancel:
              case CustomMessageType.callingHungup:
                {
                  final mediaType =
                      (data['mediaType'] ?? data['type'] ?? 'audio').toString();
                  final type = mediaType == 'video' ? 'video' : 'audio';
                  String? content;
                  switch (customType) {
                    case CustomMessageType.callingInvite:
                      content = type == 'video'
                          ? StrRes.invitedVideoCallHint
                          : StrRes.invitedVoiceCallHint;
                      break;
                    case CustomMessageType.callingAccept:
                      content = StrRes.acceptCall;
                      break;
                    case CustomMessageType.callingReject:
                      content = StrRes.rejected;
                      break;
                    case CustomMessageType.callingCancel:
                      content = StrRes.cancelled;
                      break;
                    case CustomMessageType.callingHungup:
                      content = StrRes.callingInterruption;
                      break;
                  }
                  if (content != null) {
                    return {
                      'viewType': CustomMessageType.call,
                      'type': type,
                      'content': content,
                    };
                  }
                }
                break;
              case CustomMessageType.emoji:
                data['viewType'] = CustomMessageType.emoji;
                return data;
              case CustomMessageType.tag:
                data['viewType'] = CustomMessageType.tag;
                return data;
              case CustomMessageType.meeting:
                data['viewType'] = CustomMessageType.meeting;
                return data;
              case CustomMessageType.deletedByFriend:
              case CustomMessageType.blockedByFriend:
              case CustomMessageType.removedFromGroup:
              case CustomMessageType.groupDisbanded:
                return {'viewType': customType};
              case CustomMessageType.telegramRichMedia:
                final rawMedia = data['media'];
                final rawLayout = data['layout'];
                final List<Map<String, dynamic>> mediaList = rawMedia is List
                    ? rawMedia
                        .whereType<Map>()
                        .map(
                          (item) => {
                            'type': (item['type'] ?? '').toString(),
                            'url': (item['url'] ?? '').toString(),
                            'thumbnail':
                                (item['thumbnail'] ?? item['url'] ?? '')
                                    .toString(),
                            'width': (item['width'] as num?)?.toDouble(),
                            'height': (item['height'] as num?)?.toDouble(),
                            'duration': (item['duration'] as num?)?.toDouble(),
                          },
                        )
                        .where(
                            (element) => (element['url'] as String).isNotEmpty)
                        .toList()
                    : <Map<String, dynamic>>[];
                final layout = rawLayout is List
                    ? rawLayout
                        .whereType<String>()
                        .map((e) => e.toLowerCase())
                        .toList()
                    : const <String>[];
                final text = (data['text'] as String?)?.trim() ?? '';
                return {
                  'viewType': CustomMessageType.telegramRichMedia,
                  'text': text,
                  'media': mediaList,
                  'layout': layout,
                  'content': text.isNotEmpty ? text : '[${StrRes.richMedia}]',
                };
            }
          }
      }
    } catch (e, s) {
      Logger.print('Exception details:\n $e');
      Logger.print('Stack trace:\n $s');
    }
    return null;
  }

  static Map<String, String> getAtMapping(
    Message message,
    Map<String, String> newMapping,
  ) {
    final mapping = <String, String>{};
    try {
      if (message.contentType == MessageType.atText) {
        final atUserIDs = message.atTextElem!.atUserList!;
        final atUserInfos = message.atTextElem!.atUsersInfo!;

        for (final userID in atUserIDs) {
          final groupNickname = (newMapping[userID] ??
                  atUserInfos
                      .firstWhere((e) => e.atUserID == userID)
                      .groupNickname) ??
              userID;
          mapping[userID] = getAtNickname(userID, groupNickname);
        }
      }
    } catch (_) {}
    return mapping;
  }

  static String getAtNickname(String atUserID, String atNickname) {
    return atUserID == 'atAllTag' ? StrRes.everyone : atNickname;
  }

  static void previewUrlPicture(
    List<MediaSource> sources, {
    int currentIndex = 0,
    String? heroTag,
  }) =>
      navigator?.push(TransparentRoute(
        builder: (BuildContext context) => GestureDetector(
          onTap: () => Get.back(),
          child: ChatPicturePreview(
            currentIndex: currentIndex,
            images: sources,
            heroTag: heroTag,
            onLongPress: (url) {
              IMViews.openDownloadSheet(
                url,
                onDownload: () => saveImage(context, url),
              );
            },
          ),
        ),
      ));

  /*Get.to(
        () => ChatPicturePreview(
          currentIndex: currentIndex,
          images: urls,

          heroTag: urls.elementAt(currentIndex),
          onLongPress: (url) {
            IMViews.openDownloadSheet(
              url,
              onDownload: () => HttpUtil.saveUrlPicture(url),
            );
          },
        ),

        transition: Transition.cupertino,


      );*/

  static void previewPicture(
    Message message, {
    List<Message> allList = const [],
  }) {
    if (allList.isEmpty) {
      final source = mediaSourceFromMessage(message);
      if (source == null) {
        Logger.print('previewPicture: unable to resolve media source');
        return;
      }
      previewUrlPicture([source], currentIndex: 0);
      return;
    }
    final mediaMessages = allList
        .where(
          (element) => element.isPictureType || element.isVideoType,
        )
        .toList(growable: false);
    if (mediaMessages.isEmpty) {
      Logger.print('previewPicture: empty media list');
      return;
    }
    final sources = <MediaSource>[];
    var targetIndex = 0;
    for (final item in mediaMessages) {
      final source = mediaSourceFromMessage(item);
      if (source == null) {
        continue;
      }
      if (item.clientMsgID == message.clientMsgID) {
        targetIndex = sources.length;
      }
      sources.add(source);
    }
    if (sources.isEmpty) {
      Logger.print('previewPicture: no valid media sources');
      return;
    }
    previewUrlPicture(
      sources,
      currentIndex: targetIndex.clamp(0, sources.length - 1),
    );
  }

  static void previewFile(Message message) async {
    final fileElem = message.fileElem;
    if (null != fileElem) {
      final sourcePath = fileElem.filePath;
      final url = fileElem.sourceUrl;
      final fileName = fileElem.fileName;
      final fileSize = fileElem.fileSize;
      final nameAndExt = fileName?.split('.');
      final name = nameAndExt?.first;
      final ext = nameAndExt?.last;

      final dir = await getDownloadFileDir();

      var cachePath = '$dir/${name}_${message.clientMsgID}.$ext';

      final isExitSourcePath = await isExitFile(sourcePath);

      final isExitCachePath = await isExitFile(cachePath);

      Logger.print(
          'isExitSourcePath:$isExitSourcePath, isExitCachePath:$isExitCachePath, cachePath:$cachePath');

      final isExitNetwork = isUrlValid(url);
      String? availablePath;
      if (isExitSourcePath) {
        availablePath = sourcePath;
      } else if (isExitCachePath) {
        availablePath = cachePath;
      }
      final isAvailableFileSize = isExitSourcePath || isExitCachePath
          ? (await File(availablePath!).length() == fileSize)
          : false;
      Logger.print(
          'previewFile isAvailableFileSize: $isAvailableFileSize   isExitNetwork: $isExitNetwork');
      if (isAvailableFileSize) {
        String? mimeType = lookupMimeType(fileName ?? '');
        if (null != mimeType && allowVideoType(mimeType)) {
        } else if (null != mimeType && mimeType.contains('image')) {
          previewPicture(Message()
            ..clientMsgID = message.clientMsgID
            ..contentType = MessageType.picture
            ..pictureElem = PictureElem(
                sourcePath: availablePath,
                sourcePicture: PictureInfo(url: url)));
        } else {
          openFileByOtherApp(availablePath);
        }
      } else {}
    }
  }

  static Future previewMediaFile({
    required BuildContext context,
    required Message message,
    bool muted = false,
    bool Function(int)? onAutoPlay,
    ValueChanged<int>? onPageChanged,
    bool onlySave = false,
  }) {
    final source = mediaSourceFromMessage(message);
    if (source == null) {
      return Future.value();
    }
    return previewMediaSources(
      context: context,
      sources: [source],
      muted: muted,
      onAutoPlay: onAutoPlay,
      onPageChanged: onPageChanged,
    );
  }

  static Future previewMediaSources({
    required BuildContext context,
    required List<MediaSource> sources,
    int initialIndex = 0,
    bool muted = false,
    bool Function(int)? onAutoPlay,
    ValueChanged<int>? onPageChanged,
  }) {
    if (sources.isEmpty) return Future.value();
    final safeIndex = initialIndex.clamp(0, sources.length - 1);
    final mb = MediaBrowser(
      sources: sources,
      initialIndex: safeIndex,
      onAutoPlay: (index) => onAutoPlay?.call(index) ?? false,
      muted: muted,
      onPageChanged: onPageChanged,
    );
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) => mb,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  static MediaSource? mediaSourceFromMessage(Message message) {
    if (message.isVideoType) {
      File? videoFile;
      final videoPath = message.videoElem?.videoPath;
      if (videoPath != null && videoPath.isNotEmpty) {
        final file = File(videoPath);
        if (file.existsSync()) {
          videoFile = file;
        }
      }
      final url = IMUtils.resolveMediaUrl(message.videoElem?.videoUrl);
      final thumbnail = IMUtils.resolveThumbnailUrl(
        message.videoElem?.snapshotUrl,
        fallback: url,
      );
      if ((url == null || url.isEmpty) && videoFile == null) {
        return null;
      }
      return MediaSource(
        url: url,
        thumbnail: thumbnail ?? url ?? '',
        file: videoFile,
        tag: message.clientMsgID,
        isVideo: true,
      );
    } else if (message.isPictureType) {
      File? imageFile;
      final sourcePath = message.pictureElem?.sourcePath;
      if (sourcePath != null && sourcePath.isNotEmpty) {
        final file = File(sourcePath);
        if (file.existsSync()) {
          imageFile = file;
        }
      }
      final url = IMUtils.resolveMediaUrl(message.pictureElem?.sourcePicture?.url);
      final thumbnail = IMUtils.resolveThumbnailUrl(
        message.pictureElem?.snapshotPicture?.url,
        fallback: url,
      );
      if ((url == null || url.isEmpty) && imageFile == null) {
        return null;
      }
      return MediaSource(
        url: url,
        thumbnail: thumbnail ?? url ?? '',
        file: imageFile,
        tag: message.clientMsgID,
      );
    }
    return null;
  }

  static void saveImage(BuildContext ctx, String url) async {
    EasyLoading.show(dismissOnTap: true);
    final imageFile = await getCachedImageFile(url);

    if (imageFile != null) {
      await HttpUtil.saveFileToGallerySaver(
        imageFile,
        name: url.split('/').last,
      );

      EasyLoading.dismiss();
    } else {
      HttpUtil.saveUrlPicture(url, onCompletion: () {
        EasyLoading.dismiss();
      });
    }
  }

  static openFileByOtherApp(String path) async {
    OpenResult result = await OpenFilex.open(path);
    if (result.type == ResultType.noAppToOpen) {
      IMViews.showToast("没有可用的应用");
    } else if (result.type == ResultType.permissionDenied) {
      IMViews.showToast("没有访问权限");
    } else if (result.type == ResultType.fileNotFound) {
      IMViews.showToast("文件已失效");
    }
  }

  static void parseClickEvent(
    Message message, {
    Function(UserInfo userInfo)? onViewUserInfo,
  }) async {
    if (message.contentType == MessageType.picture ||
        message.contentType == MessageType.video) {
      previewMediaFile(
        context: Get.context!,
        message: message,
      );
    } else if (message.contentType == MessageType.file) {
      previewFile(message);
    }
  }

  static Future<bool> isExitFile(String? path) async {
    return isNotNullEmptyStr(path) ? await File(path!).exists() : false;
  }

  static String? getMediaType(final String filePath) {
    var fileName = filePath.substring(filePath.lastIndexOf("/") + 1);
    var fileExt = fileName.substring(fileName.lastIndexOf("."));
    switch (fileExt.toLowerCase()) {
      case ".jpg":
      case ".jpeg":
      case ".jpe":
        return "image/jpeg";
      case ".png":
        return "image/png";
      case ".bmp":
        return "image/bmp";
      case ".gif":
        return "image/gif";
      case ".json":
        return "application/json";
      case ".svg":
      case ".svgz":
        return "image/svg+xml";
      case ".mp3":
        return "audio/mpeg";
      case ".mp4":
        return "video/mp4";
      case ".mov":
        return "video/mov";
      case ".htm":
      case ".html":
        return "text/html";
      case ".css":
        return "text/css";
      case ".csv":
        return "text/csv";
      case ".txt":
      case ".text":
      case ".conf":
      case ".def":
      case ".log":
      case ".in":
        return "text/plain";
    }
    return null;
  }

  static String formatBytes(int bytes) {
    int kb = 1024;
    int mb = kb * 1024;
    int gb = mb * 1024;
    if (bytes >= gb) {
      return sprintf("%.1f GB", [bytes / gb]);
    } else if (bytes >= mb) {
      double f = bytes / mb;
      return sprintf(f > 100 ? "%.0f MB" : "%.1f MB", [f]);
    } else if (bytes > kb) {
      double f = bytes / kb;
      return sprintf(f > 100 ? "%.0f KB" : "%.1f KB", [f]);
    } else {
      return sprintf("%d B", [bytes]);
    }
  }

  static bool allowImageType(String? mimeType) {
    final result = mimeType?.contains('png') == true ||
        mimeType?.contains('jpeg') == true ||
        mimeType?.contains('gif') == true ||
        mimeType?.contains('bmp') == true ||
        mimeType?.contains('webp') == true ||
        mimeType?.contains('heic') == true;

    return result;
  }

  static bool allowVideoType(String? mimeType) {
    final result = mimeType?.contains('mp4') == true ||
        mimeType?.contains('3gpp') == true ||
        mimeType?.contains('webm') == true ||
        mimeType?.contains('x-msvideo') == true ||
        mimeType?.contains('quicktime') == true;

    return result;
  }

  static String fileIcon(String fileName) {
    var mimeType = lookupMimeType(fileName) ?? '';
    if (mimeType == 'application/pdf') {
      return ImageRes.filePdf;
    } else if (mimeType == 'application/msword' ||
        mimeType ==
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document') {
      return ImageRes.fileWord;
    } else if (mimeType == 'application/vnd.ms-excel' ||
        mimeType ==
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet') {
      return ImageRes.fileExcel;
    } else if (mimeType == 'application/vnd.ms-powerpoint') {
      return ImageRes.filePpt;
    } else if (mimeType.startsWith('audio/')) {
    } else if (mimeType == 'application/zip' ||
        mimeType == 'application/x-rar-compressed') {
      return ImageRes.fileZip;
    }
    /*else if (mimeType.startsWith('audio/')) {
      return FontAwesomeIcons.solidFileAudio;
    } else if (mimeType.startsWith('video/')) {
      return FontAwesomeIcons.solidFileVideo;
    } else if (mimeType.startsWith('image/')) {
      return FontAwesomeIcons.solidFileImage;
    } else if (mimeType == 'text/plain') {
      return FontAwesomeIcons.solidFileCode;
    }*/
    return ImageRes.fileUnknown;
  }

  static String createSummary(Message message) {
    return '${message.senderNickname}：${parseMsg(message, replaceIdToNickname: true)}';
  }

  static List<UserInfo>? convertSelectContactsResultToUserInfo(result) {
    if (result is Map) {
      final checkedList = <UserInfo>[];
      final values = result.values;
      for (final value in values) {
        if (value is ISUserInfo) {
          checkedList.add(UserInfo.fromJson(value.toJson()));
        } else if (value is UserFullInfo) {
          checkedList.add(UserInfo.fromJson(value.toJson()));
        } else if (value is FriendInfo) {
          checkedList.add(UserInfo.fromJson(value.toJson()));
        } else if (value is UserInfo) {
          checkedList.add(value);
        }
      }
      return checkedList;
    }
    return null;
  }

  static List<String>? convertSelectContactsResultToUserID(result) {
    if (result is Map) {
      final checkedList = <String>[];
      final values = result.values;
      for (final value in values) {
        if (value is UserInfo ||
            value is FriendInfo ||
            value is UserFullInfo ||
            value is ISUserInfo) {
          checkedList.add(value.userID!);
        }
      }
      return checkedList;
    }
    return null;
  }

  static convertCheckedListToMap(List<dynamic>? checkedList) {
    if (null == checkedList) return null;
    final checkedMap = <String, dynamic>{};
    for (var item in checkedList) {
      if (item is ConversationInfo) {
        checkedMap[item.isSingleChat ? item.userID! : item.groupID!] = item;
      } else if (item is UserInfo ||
          item is UserFullInfo ||
          item is ISUserInfo ||
          item is FriendInfo) {
        checkedMap[item.userID!] = item;
      } else if (item is GroupInfo) {
        checkedMap[item.groupID] = item;
      }
    }
    return checkedMap;
  }

  static List<Map<String, String?>> convertCheckedListToForwardObj(
      List<dynamic> checkedList) {
    final map = <Map<String, String?>>[];
    for (var item in checkedList) {
      if (item is UserInfo ||
          item is UserFullInfo ||
          item is ISUserInfo ||
          item is FriendInfo) {
        map.add({'nickname': item.nickname, 'faceURL': item.faceURL});
      } else if (item is GroupInfo) {
        map.add({'nickname': item.groupName, 'faceURL': item.faceURL});
      } else if (item is ConversationInfo) {
        map.add({'nickname': item.showName, 'faceURL': item.faceURL});
      }
    }
    return map;
  }

  static String? convertCheckedToUserID(dynamic info) {
    if (info is UserInfo ||
        info is UserFullInfo ||
        info is ISUserInfo ||
        info is FriendInfo) {
      return info.userID;
    } else if (info is ConversationInfo) {
      return info.userID;
    }

    return null;
  }

  static String? convertCheckedToGroupID(dynamic info) {
    if (info is GroupInfo) {
      return info.groupID;
    } else if (info is ConversationInfo) {
      return info.groupID;
    }

    return null;
  }

  static List<Map<String, String?>> convertCheckedListToShare(
      Iterable<dynamic> checkedList) {
    final map = <Map<String, String?>>[];
    for (var item in checkedList) {
      if (item is UserInfo ||
          item is UserFullInfo ||
          item is ISUserInfo ||
          item is FriendInfo) {
        map.add({'userID': item.userID, 'groupID': null});
      } else if (item is GroupInfo) {
        map.add({'userID': null, 'groupID': item.groupID});
      } else if (item is ConversationInfo) {
        map.add({'userID': item.userID, 'groupID': item.groupID});
      }
    }
    return map;
  }

  static String getWorkMomentsTimeline(int ms) {
    final locTimeMs = DateTime.now().millisecondsSinceEpoch;
    final languageCode = Get.locale?.languageCode ?? 'zh';
    final isZH = languageCode == 'zh';

    if (DateUtil.isToday(ms, locMs: locTimeMs)) {
      return isZH ? '今天' : 'Today';
    }

    if (DateUtil.isYesterdayByMs(ms, locTimeMs)) {
      return isZH ? '昨天' : 'Yesterday';
    }

    if (DateUtil.isWeek(ms, locMs: locTimeMs)) {
      return DateUtil.getWeekdayByMs(ms, languageCode: languageCode);
    }

    if (DateUtil.yearIsEqualByMs(ms, locTimeMs)) {
      return formatDateMs(ms, format: isZH ? 'MM月dd' : 'MM/dd');
    }

    return formatDateMs(ms, format: isZH ? 'yyyy年MM月dd' : 'yyyy/MM/dd');
  }

  static String safeTrim(String text) {
    return text.trim();
  }

  static String getTimeFormat1() {
    bool isZh = Get.locale!.languageCode.toLowerCase().contains("zh");
    return isZh ? 'yyyy年MM月dd日' : 'yyyy/MM/dd';
  }

  static String getTimeFormat2() {
    bool isZh = Get.locale!.languageCode.toLowerCase().contains("zh");
    return isZh ? 'yyyy年MM月dd日 HH时mm分' : 'yyyy/MM/dd HH:mm';
  }

  static String getTimeFormat3() {
    bool isZh = Get.locale!.languageCode.toLowerCase().contains("zh");
    return isZh ? 'MM月dd日 HH时mm分' : 'MM/dd HH:mm';
  }

  static bool isValidPassword(String password) => RegExp(
        r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d\S]{6,20}$',
      ).hasMatch(password);

  static TextInputFormatter getPasswordFormatter() =>
      FilteringTextInputFormatter.allow(
        RegExp(r'[a-zA-Z0-9\S]'),
      );
}

extension PlatformExt on Platform {
  static bool get isMobile => Platform.isIOS || Platform.isAndroid;

  static bool get isDesktop =>
      Platform.isLinux || Platform.isMacOS || Platform.isWindows;
}
