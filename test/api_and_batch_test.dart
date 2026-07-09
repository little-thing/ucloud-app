import 'dart:convert';

import 'package:compshare_manager/models/app_models.dart';
import 'package:compshare_manager/models/comp_share_instance.dart';
import 'package:compshare_manager/services/api_exception.dart';
import 'package:compshare_manager/services/compshare_api_client.dart';
import 'package:compshare_manager/services/instance_batch_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  group('CompShareApiClient', () {
    test('describeInstances parses UHostSet', () async {
      final client = CompShareApiClient(
        credentials: const ApiCredentials(
          publicKey: 'pk',
          privateKey: 'sk',
        ),
        poster: (url, {headers, body}) async {
          final payload = jsonDecode(body as String) as Map<String, dynamic>;
          expect(payload['Action'], 'DescribeCompShareInstance');
          expect(payload.containsKey('Signature'), isTrue);
          return http.Response(
            jsonEncode({
              'Action': 'DescribeCompShareInstanceResponse',
              'RetCode': 0,
              'TotalCount': 1,
              'UHostSet': [
                {
                  'UHostId': 'uhost-1',
                  'Name': 'gpu-a',
                  'State': 'Stopped',
                  'Zone': 'cn-wlcb-01',
                  'Region': 'cn-wlcb',
                  'GPU': 1,
                  'GpuType': '4090',
                  'CPU': 8,
                  'Memory': 32768,
                  'SupportWithoutGpuStart': true,
                  'IsSpot': false,
                }
              ],
            }),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        },
      );

      final list = await client.describeInstances();
      expect(list, hasLength(1));
      expect(list.first.uHostId, 'uhost-1');
      expect(list.first.canStart, isTrue);
      expect(list.first.supportWithoutGpuStart, isTrue);
    });

    test('startInstance sends WithoutGpuSpec when requested', () async {
      Map<String, dynamic>? seen;
      final client = CompShareApiClient(
        credentials: const ApiCredentials(publicKey: 'pk', privateKey: 'sk'),
        poster: (url, {headers, body}) async {
          seen = jsonDecode(body as String) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'RetCode': 0,
              'UHostId': 'uhost-1',
            }),
            200,
          );
        },
      );

      await client.startInstance(
        zone: 'cn-wlcb-01',
        uHostId: 'uhost-1',
        withoutGpuSpec: 'A',
      );
      expect(seen!['Action'], 'StartCompShareInstance');
      expect(seen!['WithoutGpuSpec'], 'A');
      expect(seen!.containsKey('WithoutGpu'), isFalse);
    });

    test('throws CompShareApiException on RetCode != 0', () async {
      final client = CompShareApiClient(
        credentials: const ApiCredentials(publicKey: 'pk', privateKey: 'sk'),
        poster: (url, {headers, body}) async {
          return http.Response(
            jsonEncode({
              'RetCode': 8000,
              'Message': 'InstanceOperationInProgress',
            }),
            200,
          );
        },
      );

      expect(
        () => client.stopInstance(zone: 'z', uHostId: 'u'),
        throwsA(
          isA<CompShareApiException>().having(
            (e) => e.retCode,
            'retCode',
            8000,
          ),
        ),
      );
    });
  });

  group('InstanceBatchService', () {
    CompShareInstance inst({
      required String id,
      required String state,
      bool supportWithoutGpu = true,
      bool isSpot = false,
    }) {
      return CompShareInstance(
        uHostId: id,
        name: id,
        state: state,
        zone: 'cn-wlcb-01',
        region: 'cn-wlcb',
        supportWithoutGpuStart: supportWithoutGpu,
        isSpot: isSpot,
      );
    }

    test('startMany skips non-stopped and rejects unsupported withoutGpu',
        () async {
      final calls = <Map<String, dynamic>>[];
      final api = CompShareApiClient(
        credentials: const ApiCredentials(publicKey: 'pk', privateKey: 'sk'),
        poster: (url, {headers, body}) async {
          calls.add(jsonDecode(body as String) as Map<String, dynamic>);
          return http.Response(
            jsonEncode({'RetCode': 0, 'UHostId': 'ok'}),
            200,
          );
        },
      );
      final batch = InstanceBatchService(api);
      final result = await batch.startMany(
        [
          inst(id: 'a', state: 'Stopped'),
          inst(id: 'b', state: 'Running'),
          inst(id: 'c', state: 'Stopped', supportWithoutGpu: false),
        ],
        mode: StartMode.noGpuA,
      );

      expect(result.succeeded, ['a']);
      expect(result.skipped, ['b']);
      expect(result.failed.map((e) => e.id), ['c']);
      expect(calls, hasLength(1));
      expect(calls.first['WithoutGpuSpec'], 'A');
      expect(calls.first.containsKey('WithoutGpu'), isFalse);
    });

    test('stopMany calls API regardless of state and forces spot', () async {
      final calls = <Map<String, dynamic>>[];
      final api = CompShareApiClient(
        credentials: const ApiCredentials(publicKey: 'pk', privateKey: 'sk'),
        poster: (url, {headers, body}) async {
          calls.add(jsonDecode(body as String) as Map<String, dynamic>);
          return http.Response(
            jsonEncode({'RetCode': 0, 'UHostId': 'ok'}),
            200,
          );
        },
      );
      final batch = InstanceBatchService(api);
      final result = await batch.stopMany([
        inst(id: 's1', state: 'Running', isSpot: true),
        inst(id: 's2', state: 'Initializing'),
        inst(id: 's3', state: 'Stopped'),
      ]);
      expect(result.succeeded, ['s1', 's2', 's3']);
      expect(result.skipped, isEmpty);
      expect(calls, hasLength(3));
      expect(calls.first['Force'], true);
      expect(calls[1]['Force'], isNot(true));
    });

    test('rebootMany only running', () async {
      final api = CompShareApiClient(
        credentials: const ApiCredentials(publicKey: 'pk', privateKey: 'sk'),
        poster: (url, {headers, body}) async {
          return http.Response(
            jsonEncode({'RetCode': 0, 'UHostId': 'r1'}),
            200,
          );
        },
      );
      final batch = InstanceBatchService(api);
      final result = await batch.rebootMany([
        inst(id: 'r1', state: 'Running'),
        inst(id: 'r2', state: 'Stopped'),
      ]);
      expect(result.succeeded, ['r1']);
      expect(result.skipped, ['r2']);
    });
  });
}
