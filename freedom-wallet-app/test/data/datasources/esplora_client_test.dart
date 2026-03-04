import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:freedom_wallet/data/datasources/esplora_client.dart';
import 'package:freedom_wallet/domain/errors/blockchain_errors.dart';
import 'package:freedom_wallet/domain/models/vault.dart';

void main() {
  group('EsploraClient', () {
    test('getUtxos parses Esplora response', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/utxo')) {
          return http.Response(
            jsonEncode([
              {
                'txid': 'abc123',
                'vout': 0,
                'value': 50000,
                'status': {'confirmed': true, 'block_height': 2500000},
              },
              {
                'txid': 'def456',
                'vout': 1,
                'value': 30000,
                'status': {'confirmed': false},
              },
            ]),
            200,
          );
        }
        return http.Response('', 404);
      });

      final client = EsploraClient(
        client: mockClient,
        baseUrl: 'https://test.example.com/api',
      );

      final utxos = await client.getUtxos('bc1ptest');
      expect(utxos, hasLength(2));
      expect(utxos[0].txid, 'abc123');
      expect(utxos[0].vout, 0);
      expect(utxos[0].value, 50000);
      expect(utxos[0].confirmed, true);
      expect(utxos[0].blockHeight, 2500000);
      expect(utxos[1].confirmed, false);
      expect(utxos[1].blockHeight, isNull);
    });

    test('getUtxos returns empty list for unfunded address', () async {
      final mockClient = MockClient((request) async {
        return http.Response('[]', 200);
      });

      final client = EsploraClient(
        client: mockClient,
        baseUrl: 'https://test.example.com/api',
      );

      final utxos = await client.getUtxos('bc1punfunded');
      expect(utxos, isEmpty);
    });

    test('getFeeEstimates parses target blocks', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/fee-estimates')) {
          return http.Response(
            jsonEncode({
              '1': 28.5,
              '3': 12.0,
              '6': 3.5,
              '25': 1.0,
            }),
            200,
          );
        }
        return http.Response('', 404);
      });

      final client = EsploraClient(
        client: mockClient,
        baseUrl: 'https://test.example.com/api',
      );

      final fees = await client.getFeeEstimates();
      expect(fees.highPriority, 28.5);
      expect(fees.mediumPriority, 12.0);
      expect(fees.lowPriority, 3.5);
    });

    test('broadcastTransaction returns txid on success', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'POST' && request.url.path.endsWith('/tx')) {
          return http.Response('abc123def456txid', 200);
        }
        return http.Response('', 404);
      });

      final client = EsploraClient(
        client: mockClient,
        baseUrl: 'https://test.example.com/api',
      );

      final result = await client.broadcastTransaction('rawtxhex');
      expect(result.success, true);
      expect(result.txid, 'abc123def456txid');
    });

    test('broadcastTransaction returns error on rejection', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Missing inputs', 400);
      });

      final client = EsploraClient(
        client: mockClient,
        baseUrl: 'https://test.example.com/api',
      );

      final result = await client.broadcastTransaction('badtx');
      expect(result.success, false);
      expect(result.error, 'Missing inputs');
    });

    test('getUtxos throws BlockchainApiException on server error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final client = EsploraClient(
        client: mockClient,
        baseUrl: 'https://test.example.com/api',
      );

      expect(
        () => client.getUtxos('bc1ptest'),
        throwsA(isA<BlockchainApiException>()),
      );
    });

    test('baseUrlForNetwork returns correct URLs', () {
      expect(
        EsploraClient.baseUrlForNetwork(Network.mainnet),
        'https://blockstream.info/api',
      );
      expect(
        EsploraClient.baseUrlForNetwork(Network.testnet),
        'https://blockstream.info/testnet/api',
      );
      expect(
        EsploraClient.baseUrlForNetwork(Network.signet),
        'https://mempool.space/signet/api',
      );
      expect(
        () => EsploraClient.baseUrlForNetwork(Network.regtest),
        throwsA(isA<BlockchainApiException>()),
      );
    });

    test('getTransactionStatus returns status map', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/status')) {
          return http.Response(
            jsonEncode({
              'confirmed': true,
              'block_height': 2500100,
              'block_hash': 'hash123',
            }),
            200,
          );
        }
        return http.Response('', 404);
      });

      final client = EsploraClient(
        client: mockClient,
        baseUrl: 'https://test.example.com/api',
      );

      final status = await client.getTransactionStatus('txid123');
      expect(status['confirmed'], true);
      expect(status['block_height'], 2500100);
    });
  });
}
