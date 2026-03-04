/// Base class for blockchain-related exceptions.
abstract class BlockchainException implements Exception {
  final String message;
  const BlockchainException(this.message);

  @override
  String toString() => message;
}

/// HTTP error from blockchain API.
class BlockchainApiException extends BlockchainException {
  final int? statusCode;
  const BlockchainApiException(super.message, {this.statusCode});
}

/// Timeout when calling blockchain API.
class BlockchainTimeoutException extends BlockchainException {
  const BlockchainTimeoutException(
      [super.message = 'Blockchain API request timed out']);
}

/// Transaction broadcast was rejected.
class BroadcastFailedException extends BlockchainException {
  const BroadcastFailedException(super.message);
}
