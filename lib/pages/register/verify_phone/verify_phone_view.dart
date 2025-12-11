import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

import 'verify_phone_logic.dart';

class VerifyPhonePage extends GetView<VerifyPhoneLogic> {
  VerifyPhonePage({super.key});

  final logic = Get.find<VerifyPhoneLogic>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleBar.back(title: 'Verify Phone'),
      body: Center(
        child: Text(StrRes.dataAbnormal),
      ),
    );
  }
}
