use serde::{Deserialize, Serialize};

/// Bitcoin network selection
#[repr(C)]
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Network {
    Mainnet = 0,
    Testnet = 1,
    Signet = 2,
    Regtest = 3,
}

impl From<Network> for bitcoin::Network {
    fn from(n: Network) -> Self {
        match n {
            Network::Mainnet => bitcoin::Network::Bitcoin,
            Network::Testnet => bitcoin::Network::Testnet,
            Network::Signet => bitcoin::Network::Signet,
            Network::Regtest => bitcoin::Network::Regtest,
        }
    }
}

impl TryFrom<i32> for Network {
    type Error = crate::error::CoreError;

    fn try_from(value: i32) -> Result<Self, Self::Error> {
        match value {
            0 => Ok(Network::Mainnet),
            1 => Ok(Network::Testnet),
            2 => Ok(Network::Signet),
            3 => Ok(Network::Regtest),
            _ => Err(crate::error::CoreError::InvalidInput(
                format!("Invalid network value: {}", value)
            )),
        }
    }
}

/// Pre-defined vault security templates
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum VaultTemplate {
    #[serde(rename = "savings")]
    Savings {
        #[serde(default = "default_savings_delay")]
        delay_blocks: u32
    },

    #[serde(rename = "spending")]
    Spending {
        #[serde(default = "default_spending_delay")]
        delay_blocks: u32
    },

    #[serde(rename = "custom")]
    Custom {
        delay_blocks: u32,
        recovery_type: RecoveryType,
    },
}

fn default_savings_delay() -> u32 { 1008 }
fn default_spending_delay() -> u32 { 144 }

impl VaultTemplate {
    pub fn savings() -> Self {
        VaultTemplate::Savings { delay_blocks: 1008 }
    }

    pub fn spending() -> Self {
        VaultTemplate::Spending { delay_blocks: 144 }
    }

    pub fn delay_blocks(&self) -> u32 {
        match self {
            VaultTemplate::Savings { delay_blocks } => *delay_blocks,
            VaultTemplate::Spending { delay_blocks } => *delay_blocks,
            VaultTemplate::Custom { delay_blocks, .. } => *delay_blocks,
        }
    }

    pub fn template_id(&self) -> &str {
        match self {
            VaultTemplate::Savings { .. } => "savings_v1",
            VaultTemplate::Spending { .. } => "spending_v1",
            VaultTemplate::Custom { .. } => "custom_v1",
        }
    }
}

/// Recovery mechanism type
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RecoveryType {
    EmergencyKey,
    TimelockOnly,
    MultiSig,
}

/// Metadata encoded in Taproot script leaf for recovery
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VaultMetadata {
    /// Schema version for future compatibility
    pub version: u8,

    /// Template identifier
    pub template_id: String,

    /// Delay in blocks before spend completes
    pub delay_blocks: u32,

    /// Indices into approved destinations list
    pub destination_indices: Vec<u8>,

    /// Recovery mechanism type
    pub recovery_type: RecoveryType,

    /// Creation timestamp (block height)
    pub created_at_block: u32,

    /// Derivation index for this vault
    pub vault_index: u32,
}

impl VaultMetadata {
    /// Encode metadata to bytes for script leaf
    pub fn to_bytes(&self) -> Vec<u8> {
        let mut bytes = Vec::with_capacity(64);

        // Version (1 byte)
        bytes.push(self.version);

        // Template ID length + bytes
        let template_bytes = self.template_id.as_bytes();
        bytes.push(template_bytes.len() as u8);
        bytes.extend_from_slice(template_bytes);

        // Delay blocks (4 bytes, little-endian)
        bytes.extend_from_slice(&self.delay_blocks.to_le_bytes());

        // Destination indices count + bytes
        bytes.push(self.destination_indices.len() as u8);
        bytes.extend_from_slice(&self.destination_indices);

        // Recovery type (1 byte)
        bytes.push(match self.recovery_type {
            RecoveryType::EmergencyKey => 0,
            RecoveryType::TimelockOnly => 1,
            RecoveryType::MultiSig => 2,
        });

        // Created at block (4 bytes)
        bytes.extend_from_slice(&self.created_at_block.to_le_bytes());

        // Vault index (4 bytes)
        bytes.extend_from_slice(&self.vault_index.to_le_bytes());

        bytes
    }

    /// Decode metadata from bytes
    pub fn from_bytes(data: &[u8]) -> Result<Self, crate::error::CoreError> {
        if data.is_empty() {
            return Err(crate::error::CoreError::MetadataError(
                "Empty metadata bytes".to_string()
            ));
        }

        let mut pos = 0;

        // Version
        let version = data[pos];
        pos += 1;

        // Template ID
        if pos >= data.len() {
            return Err(crate::error::CoreError::MetadataError("Truncated metadata".to_string()));
        }
        let template_id_len = data[pos] as usize;
        pos += 1;

        if pos + template_id_len > data.len() {
            return Err(crate::error::CoreError::MetadataError("Invalid template_id length".to_string()));
        }
        let template_id = String::from_utf8(data[pos..pos + template_id_len].to_vec())
            .map_err(|e| crate::error::CoreError::MetadataError(format!("Invalid UTF-8: {}", e)))?;
        pos += template_id_len;

        // Delay blocks
        if pos + 4 > data.len() {
            return Err(crate::error::CoreError::MetadataError("Truncated delay_blocks".to_string()));
        }
        let delay_blocks = u32::from_le_bytes([data[pos], data[pos+1], data[pos+2], data[pos+3]]);
        pos += 4;

        // Destination indices
        if pos >= data.len() {
            return Err(crate::error::CoreError::MetadataError("Truncated destination_indices".to_string()));
        }
        let dest_count = data[pos] as usize;
        pos += 1;

        if pos + dest_count > data.len() {
            return Err(crate::error::CoreError::MetadataError("Invalid destination_indices length".to_string()));
        }
        let destination_indices = data[pos..pos + dest_count].to_vec();
        pos += dest_count;

        // Recovery type
        if pos >= data.len() {
            return Err(crate::error::CoreError::MetadataError("Truncated recovery_type".to_string()));
        }
        let recovery_type = match data[pos] {
            0 => RecoveryType::EmergencyKey,
            1 => RecoveryType::TimelockOnly,
            2 => RecoveryType::MultiSig,
            v => return Err(crate::error::CoreError::MetadataError(format!("Invalid recovery_type: {}", v))),
        };
        pos += 1;

        // Created at block
        if pos + 4 > data.len() {
            return Err(crate::error::CoreError::MetadataError("Truncated created_at_block".to_string()));
        }
        let created_at_block = u32::from_le_bytes([data[pos], data[pos+1], data[pos+2], data[pos+3]]);
        pos += 4;

        // Vault index
        if pos + 4 > data.len() {
            return Err(crate::error::CoreError::MetadataError("Truncated vault_index".to_string()));
        }
        let vault_index = u32::from_le_bytes([data[pos], data[pos+1], data[pos+2], data[pos+3]]);

        Ok(VaultMetadata {
            version,
            template_id,
            delay_blocks,
            destination_indices,
            recovery_type,
            created_at_block,
            vault_index,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_metadata_roundtrip() {
        let metadata = VaultMetadata {
            version: 1,
            template_id: "savings_v1".to_string(),
            delay_blocks: 1008,
            destination_indices: vec![0, 1, 2],
            recovery_type: RecoveryType::EmergencyKey,
            created_at_block: 800000,
            vault_index: 42,
        };

        let encoded = metadata.to_bytes();
        let decoded = VaultMetadata::from_bytes(&encoded).unwrap();

        assert_eq!(metadata.version, decoded.version);
        assert_eq!(metadata.template_id, decoded.template_id);
        assert_eq!(metadata.delay_blocks, decoded.delay_blocks);
        assert_eq!(metadata.destination_indices, decoded.destination_indices);
        assert_eq!(metadata.created_at_block, decoded.created_at_block);
        assert_eq!(metadata.vault_index, decoded.vault_index);
    }

    #[test]
    fn test_vault_template_delay_blocks() {
        assert_eq!(VaultTemplate::savings().delay_blocks(), 1008);
        assert_eq!(VaultTemplate::spending().delay_blocks(), 144);
    }

    #[test]
    fn test_network_conversion() {
        assert_eq!(bitcoin::Network::Bitcoin, Network::Mainnet.into());
        assert_eq!(bitcoin::Network::Testnet, Network::Testnet.into());
        assert_eq!(bitcoin::Network::Signet, Network::Signet.into());
        assert_eq!(bitcoin::Network::Regtest, Network::Regtest.into());
    }
}
