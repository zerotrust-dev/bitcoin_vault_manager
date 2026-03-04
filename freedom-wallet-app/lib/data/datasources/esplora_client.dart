import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:freedom_wallet/domain/errors/blockchain_errors.dart';
import 'package:freedom_wallet/domain/models/transaction.dart';
import 'package:freedom_wallet/domain/models/utxo.dart';
import 'package:freedom_wallet/domain/models/vault.dart';

/// HTTP client for the Esplora (Blockstream) REST API.
class EsploraClient {
  final http.Client _http;
  final String _baseUrl;

  EsploraClient({
    http.Client? client,
    String baseUrl = 'https://blockstream.info/testnet/api',
  })  : _http = client ?? http.Client(),
        _baseUrl = baseUrl;

  /// Return the Esplora base URL for a given network.
  static String baseUrlForNetwork(Network network) {
    switch (network) {
      case Network.mainnet:
        return 'https://blockstream.info/api';
      case Network.testnet:
        return 'https://blockstream.info/testnet/api';
      case Network.signet:
        return 'https://mempool.space/signet/api';
      case Network.regtest:
        throw BlockchainApiException(
          'Esplora API not available for regtest',
        );
    }
  }

  /// Fetch UTXOs for a Bitcoin address.
  Future<List<Utxo>> getUtxos(String address) async {
    final body = await _get('/address/$address/utxo');
    final list = jsonDecode(body) as List<dynamic>;
    return list
        .map((e) => Utxo.fromEsploraJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetch fee rate estimates (sat/vB keyed by confirmation target).
  Future<FeeEstimates> getFeeEstimates() async {
    final body = await _get('/fee-estimates');
    final map = jsonDecode(body) as Map<String, dynamic>;
    return FeeEstimates(
      highPriority: (map['1'] as num?)?.toDouble() ?? 25.0,
      mediumPriority: (map['3'] as num?)?.toDouble() ?? 10.0,
      lowPriority: (map['6'] as num?)?.toDouble() ?? 2.0,
      fetchedAt: DateTime.now(),
    );
  }

  /// Broadcast a signed transaction hex. Returns txid on success.
  Future<BroadcastResult> broadcastTransaction(String txHex) async {
    final uri = Uri.parse('$_baseUrl/tx');
    try {
      final response = await _http
          .post(uri, body: txHex)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final txid = response.body.trim();
        return BroadcastResult(txid: txid, success: true);
      }
      return BroadcastResult(
        txid: '',
        success: false,
        error: response.body.trim(),
      );
    } on TimeoutException {
      throw const BlockchainTimeoutException(
        'Broadcast request timed out',
      );
    } catch (e) {
      if (e is BlockchainException) rethrow;
      throw BroadcastFailedException('Broadcast failed: $e');
    }
  }

  /// Get transaction confirmation status.
  Future<Map<String, dynamic>> getTransactionStatus(String txid) async {
    final body = await _get('/tx/$txid/status');
    return jsonDecode(body) as Map<String, dynamic>;
  }

  /// Internal GET helper with timeout and error handling.
  Future<String> _get(String path) async {
    final uri = Uri.parse('$_baseUrl$path');
    try {
      final response =
          await _http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return response.body;
      }
      throw BlockchainApiException(
        'Esplora returned ${response.statusCode}: ${response.body}',
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      throw const BlockchainTimeoutException();
    } catch (e) {
      if (e is BlockchainException) rethrow;
      throw BlockchainApiException('Esplora request failed: $e');
    }
  }

  void dispose() {
    _http.close();
  }
}
