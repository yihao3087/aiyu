import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

import 'reset_password_logic.dart';

class ResetPasswordPage extends GetView<ResetPasswordLogic> {
  ResetPasswordPage({super.key});

  final logic = Get.find<ResetPasswordLogic>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleBar.back(title: 'Reset Password'),
      body: Center(
        child: Text(StrRes.dataAbnormal),
      ),
    );
  }
}
