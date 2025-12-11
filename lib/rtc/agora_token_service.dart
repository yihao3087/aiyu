import 'package:dio/dio.dart';
import 'package:openim/config/agora_config.dart';

class AgoraTokenException implements Exception {
  AgoraTokenException(this.message, {this.statusCode, this.data});

  final String message;
  final int? statusCode;
  final dynamic data;

  @override
  String toString() =>
      'AgoraTokenException(statusCode: $statusCode, message: $message, data: $data)';
}

class AgoraTokenService {
  AgoraTokenService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<String> fetchRtcToken({
    required String channelName,
    required int uid,
    int? expireSeconds,
  }) async {
    if (!AgoraConfig.isConfigured) {
      throw AgoraTokenException('语音服务未配置，请联系管理员');
    }
    try {
      final response = await _dio.post(
        AgoraConfig.agoraTokenServer,
        data: <String, dynamic>{
          'channelName': channelName,
          'uid': uid,
          'expire': expireSeconds ?? AgoraConfig.defaultTokenExpireSeconds,
        },
        options: Options(
          headers: const <String, dynamic>{'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      final data = response.data;
      if (data is Map && data['errCode'] == 0) {
        final token = data['data']?['token'];
        if (token is String && token.isNotEmpty) {
          return token;
        }
      }

      throw AgoraTokenException(
        '获取语音服务 Token 失败',
        statusCode: response.statusCode,
        data: response.data,
      );
    } on DioException catch (e) {
      final message = e.message ?? e.response?.statusMessage ?? '网络请求异常，请稍后再试';
      throw AgoraTokenException(
        message,
        statusCode: e.response?.statusCode,
        data: e.response?.data,
      );
    } catch (e) {
      throw AgoraTokenException('获取语音服务 Token 失败: ${e.toString()}');
    }
  }
}
