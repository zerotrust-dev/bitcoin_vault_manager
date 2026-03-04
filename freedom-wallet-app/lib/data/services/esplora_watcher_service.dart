import 'package:freedom_wallet/data/datasources/esplora_client.dart';
import 'package:freedom_wallet/domain/interfaces/watcher_service.dart';
import 'package:freedom_wallet/domain/models/transaction.dart';
import 'package:freedom_wallet/domain/models/utxo.dart';

/// WatcherService backed by the Esplora (Blockstream) REST API.
class EsploraWatcherService implements WatcherService {
  final EsploraClient _client;

  EsploraWatcherService({required EsploraClient client}) : _client = client;

  @override
  Future<List<Utxo>> getUtxos(String address) => _client.getUtxos(address);

  @override
  Future<FeeEstimates> getFeeEstimates() => _client.getFeeEstimates();

  @override
  Future<BroadcastResult> broadcastTransaction(String txHex) =>
      _client.broadcastTransaction(txHex);

  @override
  Future<Map<String, dynamic>> getTransactionStatus(String txid) =>
      _client.getTransactionStatus(txid);

  @override
  Future<int> getBalance(String address) async {
    final utxos = await _client.getUtxos(address);
    return utxos.fold<int>(0, (sum, u) => sum + u.value);
  }
}
