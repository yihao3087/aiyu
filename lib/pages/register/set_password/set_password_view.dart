import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

import 'set_password_logic.dart';

class SetPasswordPage extends GetView<SetPasswordLogic> {
  SetPasswordPage({super.key});

  final logic = Get.find<SetPasswordLogic>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleBar.back(title: 'Set Password'),
      body: Center(
        child: Text(StrRes.dataAbnormal),
      ),
    );
  }
}
