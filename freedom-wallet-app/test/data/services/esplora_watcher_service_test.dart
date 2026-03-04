import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:freedom_wallet/data/datasources/esplora_client.dart';
import 'package:freedom_wallet/data/services/esplora_watcher_service.dart';

void main() {
  group('EsploraWatcherService', () {
    late MockClient mockHttpClient;
    late EsploraClient esploraClient;
    late EsploraWatcherService service;

    setUp(() {
      mockHttpClient = MockClient((request) async {
        final path = request.url.path;

        if (path.endsWith('/utxo')) {
          return http.Response(
            jsonEncode([
              {
                'txid': 'tx1',
                'vout': 0,
                'value': 25000,
                'status': {'confirmed': true, 'block_height': 100},
              },
              {
                'txid': 'tx2',
                'vout': 1,
                'value': 75000,
                'status': {'confirmed': true, 'block_height': 101},
              },
            ]),
            200,
          );
        }
        if (path.endsWith('/fee-estimates')) {
          return http.Response(
            jsonEncode({'1': 20.0, '3': 8.0, '6': 3.0}),
            200,
          );
        }
        if (path.endsWith('/tx') && request.method == 'POST') {
          return http.Response('broadcast_txid_123', 200);
        }
        if (path.contains('/status')) {
          return http.Response(
            jsonEncode({'confirmed': false}),
            200,
          );
        }
        return http.Response('', 404);
      });

      esploraClient = EsploraClient(
        client: mockHttpClient,
        baseUrl: 'https://test.example.com/api',
      );
      service = EsploraWatcherService(client: esploraClient);
    });

    test('getUtxos delegates to EsploraClient', () async {
      final utxos = await service.getUtxos('bc1paddr');
      expect(utxos, hasLength(2));
      expect(utxos[0].txid, 'tx1');
      expect(utxos[1].value, 75000);
    });

    test('getBalance sums UTXO values', () async {
      final balance = await service.getBalance('bc1paddr');
      expect(balance, 100000); // 25000 + 75000
    });

    test('getFeeEstimates returns parsed estimates', () async {
      final fees = await service.getFeeEstimates();
      expect(fees.highPriority, 20.0);
      expect(fees.mediumPriority, 8.0);
      expect(fees.lowPriority, 3.0);
    });

    test('broadcastTransaction returns result', () async {
      final result = await service.broadcastTransaction('rawhex');
      expect(result.success, true);
      expect(result.txid, 'broadcast_txid_123');
    });

    test('getTransactionStatus returns status', () async {
      final status = await service.getTransactionStatus('sometxid');
      expect(status['confirmed'], false);
    });
  });
}
