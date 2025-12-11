import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

import 'forget_password_logic.dart';

class ForgetPasswordPage extends GetView<ForgetPasswordLogic> {
  ForgetPasswordPage({super.key});

  final logic = Get.find<ForgetPasswordLogic>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleBar.back(title: StrRes.forgetPassword),
      body: Center(
        child: Text(StrRes.dataAbnormal),
      ),
    );
  }
}

