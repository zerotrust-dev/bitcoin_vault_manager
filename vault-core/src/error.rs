use thiserror::Error;

/// Core library errors
#[derive(Debug, Error)]
pub enum CoreError {
    #[error("Invalid xpub format: {0}")]
    InvalidXpub(String),

    #[error("Invalid address: {0}")]
    InvalidAddress(String),

    #[error("Invalid network: expected {expected}, got {actual}")]
    NetworkMismatch { expected: String, actual: String },

    #[error("PSBT building failed: {0}")]
    PsbtError(String),

    #[error("Key derivation failed: {0}")]
    DerivationError(String),

    #[error("Invalid metadata encoding: {0}")]
    MetadataError(String),

    #[error("Insufficient funds: need {needed} sats, have {available} sats")]
    InsufficientFunds { needed: u64, available: u64 },

    #[error("Policy violation: {0}")]
    PolicyViolation(String),

    #[error("Serialization error: {0}")]
    SerializationError(String),

    #[error("Invalid input: {0}")]
    InvalidInput(String),
}

impl CoreError {
    /// Get error code for FFI responses
    pub fn code(&self) -> i32 {
        match self {
            CoreError::InvalidXpub(_) => 1001,
            CoreError::InvalidAddress(_) => 1002,
            CoreError::NetworkMismatch { .. } => 1003,
            CoreError::PsbtError(_) => 2001,
            CoreError::InsufficientFunds { .. } => 2002,
            CoreError::PolicyViolation(_) => 2003,
            CoreError::DerivationError(_) => 3001,
            CoreError::MetadataError(_) => 3002,
            CoreError::SerializationError(_) => 4001,
            CoreError::InvalidInput(_) => 4002,
        }
    }
}

/// Result type for core operations
pub type CoreResult<T> = Result<T, CoreError>;
