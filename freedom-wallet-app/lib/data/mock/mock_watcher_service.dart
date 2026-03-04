import 'package:freedom_wallet/domain/interfaces/watcher_service.dart';
import 'package:freedom_wallet/domain/models/transaction.dart';
import 'package:freedom_wallet/domain/models/utxo.dart';

/// Mock WatcherService for development without a real blockchain connection.
class MockWatcherService implements WatcherService {
  @override
  Future<List<Utxo>> getUtxos(String address) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const [
      Utxo(
        txid: 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
        vout: 0,
        value: 50000,
        confirmed: true,
        blockHeight: 2500000,
      ),
    ];
  }

  @override
  Future<FeeEstimates> getFeeEstimates() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return FeeEstimates(
      highPriority: 25.0,
      mediumPriority: 10.0,
      lowPriority: 2.0,
      fetchedAt: DateTime.now(),
    );
  }

  @override
  Future<BroadcastResult> broadcastTransaction(String txHex) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return const BroadcastResult(
      txid: 'mock_broadcast_txid_abc123',
      success: true,
    );
  }

  @override
  Future<Map<String, dynamic>> getTransactionStatus(String txid) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return {
      'confirmed': true,
      'block_height': 2500000,
      'block_hash': 'mock_block_hash',
    };
  }

  @override
  Future<int> getBalance(String address) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return 50000;
  }
}
