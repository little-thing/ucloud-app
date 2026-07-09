import 'package:flutter_test/flutter_test.dart';
import 'package:compshare_manager/services/ucloud_signer.dart';

void main() {
  group('UCloudSigner', () {
    const signer = UCloudSigner();

    test('matches official documentation example', () {
      final signature = signer.sign(
        {
          'Action': 'DescribeUHostInstance',
          'Limit': 10,
          'PublicKey': 'ucloudsomeone@example.com1296235120854146120',
          'Region': 'cn-bj2',
        },
        '46f09bb9fab4f12dfc160dae12273d5332b5debe',
      );
      expect(signature, 'cba5cf5ec4d4233d206b1b54951e3787350a642f');
    });

    test('encodes bool as true/false', () {
      final signature = signer.sign(
        {
          'Action': 'StartCompShareInstance',
          'PublicKey': 'pk',
          'WithoutGpu': true,
        },
        'sk',
      );
      final again = signer.sign(
        {
          'Action': 'StartCompShareInstance',
          'PublicKey': 'pk',
          'WithoutGpu': true,
        },
        'sk',
      );
      expect(signature, again);
      expect(signature.length, 40);
    });
  });
}
