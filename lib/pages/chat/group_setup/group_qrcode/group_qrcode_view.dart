import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

import 'group_qrcode_logic.dart';

class GroupQrcodePage extends GetView<GroupQrcodeLogic> {
  GroupQrcodePage({super.key});

  final logic = Get.find<GroupQrcodeLogic>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleBar.back(title: 'Group QR'),
      body: Center(
        child: Text(StrRes.dataAbnormal),
      ),
    );
  }
}

