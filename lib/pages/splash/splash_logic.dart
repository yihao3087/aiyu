import 'package:get/get.dart';
import 'package:openim/routes/app_navigator.dart';

class SplashLogic extends GetxController {
  @override
  void onReady() {
    super.onReady();
    AppNavigator.startRegister();
  }
}
