import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

class ChatLocationView extends StatelessWidget {
  const ChatLocationView({
    super.key,
    required this.message,
    required this.isISend,
  });

  final Message message;
  final bool isISend;

  LocationElem get _elem => message.locationElem!;

  Map<String, dynamic>? _decodeDescription() {
    Map<String, dynamic>? info;

    Map<String, dynamic>? tryDecode(String? raw) {
      if (raw == null || raw.isEmpty) return null;
      try {
        final map = jsonDecode(raw);
        if (map is Map<String, dynamic>) {
          return map;
        }
      } catch (_) {
        // ignore json error and try legacy format
      }
      final parts = raw.split('|');
      if (parts.isEmpty) return null;
      final title = parts.first;
      final address = parts.length > 1 ? parts.sublist(1).join('|') : '';
      return {
        'title': title,
        'address': address,
      };
    }

    info = tryDecode(_elem.description);
    info ??= tryDecode(message.ex);
    info ??= tryDecode(message.localEx);
    return info;
  }

  @override
  Widget build(BuildContext context) {
    final info = _decodeDescription();
    final rawDesc = _elem.description ?? '';
    final legacyParts = rawDesc.split('|');
    final legacyTitle = legacyParts.isNotEmpty ? legacyParts.first : rawDesc;
    final legacyAddress =
        legacyParts.length > 1 ? legacyParts.sublist(1).join('|') : '';
    final title = info?['title'] as String? ?? legacyTitle;
    final address = info?['address'] as String? ?? legacyAddress;
    final street = info?['street'] as String? ?? '';
    final staticMap = info?['staticMap'] as String?;
    final fallbackDetail = [
      if (_elem.latitude != null) '${_elem.latitude!.toStringAsFixed(6)}',
      if (_elem.longitude != null) '${_elem.longitude!.toStringAsFixed(6)}',
    ].join(', ');
    final detailText = address.isNotEmpty
        ? address
        : (street.isNotEmpty ? street : fallbackDetail);
    return GestureDetector(
      onTap: _openMap,
      child: Container(
        width: 220.w,
        decoration: BoxDecoration(
          color: Styles.c_FFFFFF,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (staticMap != null && staticMap.isNotEmpty)
              SizedBox(
                height: 120.h,
                width: 220.w,
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12.r),
                    topRight: Radius.circular(12.r),
                  ),
                  child: Image.network(
                    staticMap,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Styles.c_0089FF_opacity20,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 120.h,
                width: 220.w,
                color: Styles.c_0089FF_opacity20,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title.isEmpty ? StrRes.location : title,
                    style: Styles.ts_0C1C33_17sp.copyWith(fontSize: 16.sp),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (detailText.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 4.h),
                      child: Text(
                        detailText,
                        style: Styles.ts_8E9AB0_14sp,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openMap() {
    final info = _decodeDescription();
    final title =
        info?['title'] as String? ?? _elem.description ?? StrRes.location;
    final address = info?['address'] as String? ?? '';
    final fallbackDetail = [
      if (_elem.latitude != null) '${_elem.latitude!.toStringAsFixed(6)}',
      if (_elem.longitude != null) '${_elem.longitude!.toStringAsFixed(6)}',
    ].join(', ');
    Get.to(() => MapView(
          latitude: _elem.latitude ?? 0,
          longitude: _elem.longitude ?? 0,
          address1: title,
          address2: address.isNotEmpty ? address : fallbackDetail,
        ));
  }
}
