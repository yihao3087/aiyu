import 'package:dio/dio.dart';

import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:openim_common/openim_common.dart';

class DeviceAuthService {
  DeviceAuthService._();

  static const _markProfileUrl =
      'https://im.zucuzu.com/device-auth/device/mark-profile';
  static bool _markProfileEndpointAvailable = true;

  static const _accountKey = 'device_auth.account';
  static const _passwordKey = 'device_auth.password';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static Future<LoginCertificate?> tryDeviceLogin() async {
    final cached = DataSp.getLoginCertificate();
    if (cached != null) {
      Logger.print(
          'deviceAuth: cached certificate found => userID:${cached.userID} imToken:${cached.imToken.isNotEmpty} chatToken:${cached.chatToken.isNotEmpty}');
    }
    if (cached != null &&
        IMUtils.emptyStrToNull(cached.imToken) != null &&
        IMUtils.emptyStrToNull(cached.chatToken) != null) {
      Logger.print(
          'deviceAuth: use cached login certificate ${cached.userID}');
      return cached;
    } else {
      Logger.print('deviceAuth: cached certificate missing, fallback to stored credentials');
    }
    if (!_markProfileEndpointAvailable) {
      Logger.print('deviceAuth: mark-profile disabled, still attempting login');
    }
    final account = await _secureStorage.read(key: _accountKey);
    final password = await _secureStorage.read(key: _passwordKey);

    if (account == null ||
        account.isEmpty ||
        password == null ||
        password.isEmpty) {
      Logger.print('deviceAuth: no stored credentials, skip auto login');
      return null;
    }

    try {
      Logger.print('deviceAuth: try login with stored credentials $account');
      final cert = await Apis.login(account: account, password: password);
      await DataSp.putLoginCertificate(cert);
      await DataSp.putDeviceProfileStatus(cert.needProfile);
      await _persistAccount(cert.account ?? account, password);
      return cert;
    } catch (e, s) {
      Logger.print('deviceAuth account login failed: $e $s');
      return null;
    }
  }

  static Future<void> saveCredentials(String account, String password) async {
    if (account.isEmpty || password.isEmpty) return;
    await _persistAccount(account, password);
    Logger.print('deviceAuth: credentials saved for $account');
  }

  static Future<void> markProfileCompleted() async {
    if (!_markProfileEndpointAvailable) {
      await _cacheProfileCompleted();
      return;
    }
    final account = await _secureStorage.read(key: _accountKey);
    Logger.print(
      'markProfileCompleted start, account=${account ?? ''}',
    );
    try {
      await HttpUtil.post(
        _markProfileUrl,
        data: <String, dynamic>{
          'userID': OpenIM.iMManager.userID,
          if (account != null && account.isNotEmpty) 'account': account,
        },
        showErrorToast: false,
      );
    } on DioException catch (e, s) {
      final status = e.response?.statusCode;
      if (status == 404) {
        _markProfileEndpointAvailable = false;
        Logger.print('markProfileCompleted endpoint not found, disable future calls');
        await _cacheProfileCompleted();
      } else {
        Logger.print('markProfileCompleted error: $e $s');
      }
    } catch (e, s) {
      Logger.print('markProfileCompleted error: $e $s');
    }
    if (_markProfileEndpointAvailable) {
      await _cacheProfileCompleted();
    }
  }

  static Future<void> _cacheProfileCompleted() async {
    await DataSp.putDeviceProfileStatus(false);
    Logger.print('markProfileCompleted done, local flag set to false');
    final cert = DataSp.getLoginCertificate();
    if (cert != null) {
      cert.needProfile = false;
      await DataSp.putLoginCertificate(cert);
    }
  }

  static Future<void> _persistAccount(String? account, String? password) async {
    if (account != null && account.isNotEmpty) {
      await _secureStorage.write(key: _accountKey, value: account);
    } else {
      await _secureStorage.delete(key: _accountKey);
    }
    if (password != null && password.isNotEmpty) {
      await _secureStorage.write(key: _passwordKey, value: password);
    } else {
      await _secureStorage.delete(key: _passwordKey);
    }
  }
}
