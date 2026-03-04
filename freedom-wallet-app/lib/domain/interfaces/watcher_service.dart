import 'package:freedom_wallet/domain/models/transaction.dart';
import 'package:freedom_wallet/domain/models/utxo.dart';

/// Abstract service for blockchain monitoring and data retrieval.
abstract class WatcherService {
  /// Fetch current UTXOs for an address.
  Future<List<Utxo>> getUtxos(String address);

  /// Fetch current fee rate estimates.
  Future<FeeEstimates> getFeeEstimates();

  /// Broadcast a signed transaction hex.
  Future<BroadcastResult> broadcastTransaction(String txHex);

  /// Get transaction confirmation status.
  Future<Map<String, dynamic>> getTransactionStatus(String txid);

  /// Get total balance (sum of UTXO values) for an address.
  Future<int> getBalance(String address);
}
