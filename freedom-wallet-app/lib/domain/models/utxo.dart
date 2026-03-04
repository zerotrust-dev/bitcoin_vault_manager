/// Unspent transaction output from the blockchain.
class Utxo {
  final String txid;
  final int vout;
  final int value; // satoshis
  final bool confirmed;
  final int? blockHeight;

  const Utxo({
    required this.txid,
    required this.vout,
    required this.value,
    required this.confirmed,
    this.blockHeight,
  });

  /// Parse from Esplora `/address/{addr}/utxo` JSON shape.
  factory Utxo.fromEsploraJson(Map<String, dynamic> json) {
    final status = json['status'] as Map<String, dynamic>?;
    return Utxo(
      txid: json['txid'] as String,
      vout: json['vout'] as int,
      value: json['value'] as int,
      confirmed: status?['confirmed'] as bool? ?? false,
      blockHeight: status?['block_height'] as int?,
    );
  }

  /// Convert to the map shape Rust FFI expects for PSBT construction.
  Map<String, dynamic> toFfiJson() => {
        'txid': txid,
        'vout': vout,
        'value': value,
      };
}

/// Fee rate estimates from the blockchain.
class FeeEstimates {
  final double highPriority; // 1-block target, sat/vB
  final double mediumPriority; // 3-block target
  final double lowPriority; // 6-block target
  final DateTime fetchedAt;

  const FeeEstimates({
    required this.highPriority,
    required this.mediumPriority,
    required this.lowPriority,
    required this.fetchedAt,
  });
}
