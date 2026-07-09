import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_models.dart';
import '../models/comp_share_instance.dart';
import 'api_exception.dart';
import 'ucloud_signer.dart';

typedef HttpPoster = Future<http.Response> Function(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
});

/// CompShare GPU 实例 API 客户端。
class CompShareApiClient {
  CompShareApiClient({
    required ApiCredentials credentials,
    UCloudSigner signer = const UCloudSigner(),
    HttpPoster? poster,
  })  : _credentials = credentials,
        _signer = signer,
        _poster = poster ??
            ((url, {headers, body}) => http.post(
                  url,
                  headers: headers,
                  body: body,
                ));

  ApiCredentials _credentials;
  final UCloudSigner _signer;
  final HttpPoster _poster;

  ApiCredentials get credentials => _credentials;

  void updateCredentials(ApiCredentials credentials) {
    _credentials = credentials;
  }

  Future<List<CompShareInstance>> describeInstances({
    List<String>? uHostIds,
    int limit = 100,
    int offset = 0,
    String? zone,
  }) async {
    final params = <String, Object?>{
      'Action': 'DescribeCompShareInstance',
      'Region': _credentials.region,
      'Limit': limit,
      'Offset': offset,
    };
    if (zone != null && zone.isNotEmpty) {
      params['Zone'] = zone;
    }
    if (uHostIds != null && uHostIds.isNotEmpty) {
      for (var i = 0; i < uHostIds.length; i++) {
        params['UHostIds.$i'] = uHostIds[i];
      }
    }

    final data = await _invoke(params);
    final set = (data['UHostSet'] as List?) ?? const [];
    return set
        .whereType<Map>()
        .map((e) => CompShareInstance.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<String> startInstance({
    required String zone,
    required String uHostId,
    String? withoutGpuSpec,
  }) async {
    final data = await _invoke({
      'Action': 'StartCompShareInstance',
      'Region': _credentials.region,
      'Zone': zone,
      'UHostId': uHostId,
      if (withoutGpuSpec != null && withoutGpuSpec.isNotEmpty)
        'WithoutGpuSpec': withoutGpuSpec,
    });
    return (data['UHostId'] ?? uHostId).toString();
  }

  Future<String> stopInstance({
    required String zone,
    required String uHostId,
    bool force = false,
  }) async {
    final data = await _invoke({
      'Action': 'StopCompShareInstance',
      'Region': _credentials.region,
      'Zone': zone,
      'UHostId': uHostId,
      if (force) 'Force': true,
    });
    return (data['UHostId'] ?? uHostId).toString();
  }

  Future<String> rebootInstance({
    required String zone,
    required String uHostId,
  }) async {
    final data = await _invoke({
      'Action': 'RebootCompShareInstance',
      'Region': _credentials.region,
      'Zone': zone,
      'UHostId': uHostId,
    });
    return (data['UHostId'] ?? uHostId).toString();
  }

  Future<Map<String, dynamic>> _invoke(Map<String, Object?> params) async {
    if (!_credentials.isConfigured) {
      throw CompShareApiException(message: '请先在设置中填写 API 密钥');
    }

    final body = Map<String, Object?>.from(params);
    body['PublicKey'] = _credentials.publicKey;
    body['Signature'] = _signer.sign(body, _credentials.privateKey);

    final uri = Uri.parse(_credentials.baseUrl);
    final response = await _poster(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CompShareApiException(
        message: 'HTTP ${response.statusCode}: ${utf8.decode(response.bodyBytes)}',
        action: params['Action']?.toString(),
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) {
      throw CompShareApiException(message: '响应格式错误');
    }
    final data = Map<String, dynamic>.from(decoded);
    final retCode = data['RetCode'];
    final code = retCode is int ? retCode : int.tryParse('$retCode') ?? -1;
    if (code != 0) {
      throw CompShareApiException(
        message: (data['Message'] ?? data['message'] ?? '请求失败').toString(),
        retCode: code,
        action: params['Action']?.toString(),
      );
    }
    return data;
  }
}
