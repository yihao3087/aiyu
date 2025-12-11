import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

import 'core/controller/im_controller.dart';
import 'core/services/auto_login_service.dart';
import 'routes/app_pages.dart';
import 'widgets/app_view.dart';

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppView(
      builder: (locale, builder) => GetMaterialApp(
        debugShowCheckedModeBanner: false,
        enableLog: true,
        builder: builder,
        translations: TranslationService(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        fallbackLocale: TranslationService.fallbackLocale,
        locale: locale,
        localeResolutionCallback: (locale, list) {
          Get.locale ??= locale;
          return locale;
        },
        supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
        getPages: AppPages.routes,
        initialBinding: InitBinding(),
        initialRoute: AppRoutes.splash,
        theme: _themeData,
      ),
    );
  }

  ThemeData get _themeData {
    const primaryBlue = Color(0xFF2E9BFF);
    const scaffoldBg = Color(0xFFF7F7F7);
    return ThemeData.light().copyWith(
      scaffoldBackgroundColor: scaffoldBg,
      canvasColor: Colors.white,
      appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: Colors.black87),
      colorScheme: ThemeData.light().colorScheme.copyWith(primary: primaryBlue, secondary: primaryBlue),
      textSelectionTheme: const TextSelectionThemeData().copyWith(
        cursorColor: primaryBlue,
        selectionColor: primaryBlue.withAlpha(77),
        selectionHandleColor: primaryBlue,
      ),
      checkboxTheme: const CheckboxThemeData().copyWith(
        checkColor: WidgetStateProperty.all(Colors.white),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return Colors.grey;
          }
          if (states.contains(WidgetState.selected)) {
            return primaryBlue;
          }
          return Colors.white;
        }),
        side: BorderSide(color: Colors.grey.shade500, width: 1),
      ),
      dialogTheme: const DialogThemeData().copyWith(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4.0),
            ),
          ),
          textStyle: WidgetStatePropertyAll(
            TextStyle(
              fontSize: 16.sp,
              color: Colors.white,
            ),
          ),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          backgroundColor: const WidgetStatePropertyAll(primaryBlue),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData()
          .copyWith(color: primaryBlue, linearTrackColor: Colors.grey[300], circularTrackColor: Colors.grey[300]),
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: primaryBlue,
        barBackgroundColor: Colors.white,
        applyThemeToAll: true,
        textTheme: const CupertinoTextThemeData().copyWith(
          navActionTextStyle: TextStyle(color: CupertinoColors.label, fontSize: 17.sp),
          actionTextStyle: TextStyle(color: primaryBlue, fontSize: 17.sp),
          textStyle: TextStyle(color: CupertinoColors.label, fontSize: 17.sp),
          navLargeTitleTextStyle: TextStyle(color: CupertinoColors.label, fontSize: 20.sp),
          navTitleTextStyle: TextStyle(color: CupertinoColors.label, fontSize: 17.sp),
          pickerTextStyle: TextStyle(color: CupertinoColors.label, fontSize: 17.sp),
          tabLabelTextStyle: TextStyle(color: CupertinoColors.label, fontSize: 17.sp),
          dateTimePickerTextStyle: TextStyle(color: CupertinoColors.label, fontSize: 17.sp),
        ),
      ),
    );
  }
}

class InitBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<IMController>(IMController());
    Get.put<PushController>(PushController());
    Get.put<CacheController>(CacheController());
    Get.put(AutoLoginService());
  }
}
