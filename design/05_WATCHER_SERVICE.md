# Watcher Service Specification

## Overview

The `vault-watcher` is a lightweight backend service that monitors the Bitcoin blockchain for vault activity and sends push notifications to users when action is needed. It is stateless, non-custodial, and can be self-hosted.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                      Flutter App                                     │
│                                                                      │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐           │
│  │ Register    │     │ Receive     │     │ Cancel      │           │
│  │ Vault       │     │ Push Alert  │     │ Transaction │           │
│  └──────┬──────┘     └──────▲──────┘     └──────┬──────┘           │
└─────────┼────────────────────┼────────────────────┼─────────────────┘
          │                    │                    │
          ▼                    │                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      Watcher Service                                 │
│                                                                      │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐           │
│  │ Registration│     │ Push        │     │ Cancel      │           │
│  │ API         │     │ Service     │     │ API         │           │
│  └──────┬──────┘     └──────▲──────┘     └──────┬──────┘           │
│         │                   │                   │                    │
│         ▼                   │                   ▼                    │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │                    Monitoring Engine                        │    │
│  │  - Watches registered descriptors                          │    │
│  │  - Detects UTXO activity                                   │    │
│  │  - Triggers alerts on spend attempts                       │    │
│  └────────────────────────────────────────────────────────────┘    │
│                              │                                       │
└──────────────────────────────┼───────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   Bitcoin Node / Electrum                            │
│                                                                      │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐           │
│  │ Mempool     │     │ Blockchain  │     │ UTXO Set    │           │
│  │ Monitor     │     │ Scanner     │     │ Query       │           │
│  └─────────────┘     └─────────────┘     └─────────────┘           │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Technology Stack

- **Runtime:** Python 3.11+
- **Framework:** FastAPI
- **Bitcoin Interface:** Electrum protocol via `electrum-client` or Esplora HTTP API
- **Push Notifications:** Firebase Cloud Messaging (FCM)
- **Queue:** Redis (optional, for scaling)
- **Database:** None (stateless) or Redis for ephemeral state

---

## Project Structure

```
vault-watcher/
├── requirements.txt
├── Dockerfile
├── docker-compose.yml
├── config.py
├── main.py                    # FastAPI app entry
├── api/
│   ├── __init__.py
│   ├── routes.py              # API endpoints
│   └── models.py              # Request/response models
├── monitoring/
│   ├── __init__.py
│   ├── watcher.py             # Main monitoring loop
│   ├── electrum.py            # Electrum client
│   └── esplora.py             # Esplora client (alternative)
├── notifications/
│   ├── __init__.py
│   └── fcm.py                 # Firebase push notifications
└── tests/
    ├── __init__.py
    ├── test_api.py
    └── test_monitoring.py
```

---

## Configuration

```python
# config.py

from pydantic_settings import BaseSettings
from typing import Optional

class Settings(BaseSettings):
    # Server
    host: str = "0.0.0.0"
    port: int = 8000
    debug: bool = False
    
    # Bitcoin Network
    network: str = "mainnet"  # mainnet, testnet, signet
    
    # Electrum Server
    electrum_host: str = "electrum.blockstream.info"
    electrum_port: int = 50002
    electrum_ssl: bool = True
    
    # Esplora (alternative)
    esplora_url: Optional[str] = "https://blockstream.info/api"
    
    # Firebase
    firebase_credentials_file: str = "firebase-credentials.json"
    
    # Monitoring
    poll_interval_seconds: int = 10
    mempool_check_interval: int = 5
    
    # Redis (optional)
    redis_url: Optional[str] = None
    
    class Config:
        env_file = ".env"

settings = Settings()
```

---

## API Specification

### Health Check

```
GET /health

Response:
{
  "status": "ok",
  "service": "vault-watcher",
  "version": "0.1.0",
  "network": "mainnet",
  "block_height": 830000,
  "connected_to_node": true
}
```

### Register Vault

Register a vault descriptor for monitoring.

```
POST /vaults/register

Request:
{
  "vault_id": "vault_abc123",
  "descriptor": "tr(xpub.../0/*)",
  "addresses": ["bc1p..."],
  "device_token": "fcm_token_xyz",
  "user_id": "user_123",
  "notification_preferences": {
    "on_spend_attempt": true,
    "on_timelock_maturing": true,
    "on_confirmation": true
  }
}

Response:
{
  "success": true,
  "vault_id": "vault_abc123",
  "monitoring_started": true,
  "current_balance_sats": 100000
}
```

### Unregister Vault

Stop monitoring a vault.

```
DELETE /vaults/{vault_id}

Response:
{
  "success": true,
  "vault_id": "vault_abc123",
  "monitoring_stopped": true
}
```

### Get Vault Status

```
GET /vaults/{vault_id}

Response:
{
  "vault_id": "vault_abc123",
  "addresses": ["bc1p..."],
  "balance_sats": 100000,
  "utxos": [
    {
      "txid": "abc123...",
      "vout": 0,
      "value_sats": 100000,
      "confirmations": 6
    }
  ],
  "pending_spends": [],
  "last_activity": "2025-01-15T10:30:00Z"
}
```

### Get UTXOs

```
GET /vaults/{vault_id}/utxos

Response:
{
  "vault_id": "vault_abc123",
  "utxos": [
    {
      "txid": "abc123...",
      "vout": 0,
      "value_sats": 100000,
      "confirmations": 6,
      "script_pubkey": "5120...",
      "block_height": 829994
    }
  ],
  "total_sats": 100000
}
```

### Broadcast Transaction

```
POST /broadcast

Request:
{
  "tx_hex": "0100000001..."
}

Response:
{
  "success": true,
  "txid": "def456...",
  "broadcast_time": "2025-01-15T10:35:00Z"
}
```

### Fee Estimates

```
GET /fees

Response:
{
  "low": {
    "sat_per_vb": 5,
    "target_blocks": 6,
    "estimated_minutes": 60
  },
  "medium": {
    "sat_per_vb": 10,
    "target_blocks": 3,
    "estimated_minutes": 30
  },
  "high": {
    "sat_per_vb": 20,
    "target_blocks": 1,
    "estimated_minutes": 10
  },
  "timestamp": "2025-01-15T10:30:00Z"
}
```

---

## Monitoring Engine

### Watcher Implementation

```python
# monitoring/watcher.py

import asyncio
from typing import Dict, Set
from dataclasses import dataclass
from datetime import datetime

@dataclass
class WatchedVault:
    vault_id: str
    addresses: Set[str]
    descriptor: str
    device_token: str
    user_id: str
    last_known_utxos: Dict[str, int]  # txid:vout -> value
    notification_prefs: dict

class VaultWatcher:
    def __init__(self, bitcoin_client, notification_service):
        self.bitcoin = bitcoin_client
        self.notifications = notification_service
        self.watched_vaults: Dict[str, WatchedVault] = {}
        self._running = False
    
    async def register_vault(self, vault: WatchedVault):
        """Add vault to monitoring"""
        # Get current UTXOs
        utxos = await self.bitcoin.get_utxos(vault.addresses)
        vault.last_known_utxos = {
            f"{u['txid']}:{u['vout']}": u['value']
            for u in utxos
        }
        self.watched_vaults[vault.vault_id] = vault
    
    async def unregister_vault(self, vault_id: str):
        """Remove vault from monitoring"""
        self.watched_vaults.pop(vault_id, None)
    
    async def start_monitoring(self):
        """Main monitoring loop"""
        self._running = True
        while self._running:
            try:
                await self._check_all_vaults()
                await asyncio.sleep(settings.poll_interval_seconds)
            except Exception as e:
                logger.error(f"Monitoring error: {e}")
                await asyncio.sleep(5)
    
    async def _check_all_vaults(self):
        """Check all registered vaults for activity"""
        for vault in self.watched_vaults.values():
            await self._check_vault(vault)
    
    async def _check_vault(self, vault: WatchedVault):
        """Check single vault for changes"""
        current_utxos = await self.bitcoin.get_utxos(vault.addresses)
        current_set = {
            f"{u['txid']}:{u['vout']}": u['value']
            for u in current_utxos
        }
        
        # Check for spent UTXOs (spend attempt)
        spent = set(vault.last_known_utxos.keys()) - set(current_set.keys())
        if spent:
            await self._handle_spend_detected(vault, spent)
        
        # Check for new UTXOs (incoming funds)
        new = set(current_set.keys()) - set(vault.last_known_utxos.keys())
        if new:
            await self._handle_new_funds(vault, new, current_utxos)
        
        # Update last known state
        vault.last_known_utxos = current_set
    
    async def _handle_spend_detected(self, vault: WatchedVault, spent_utxos: Set[str]):
        """Handle detected spend attempt"""
        if not vault.notification_prefs.get('on_spend_attempt', True):
            return
        
        total_spent = sum(
            vault.last_known_utxos.get(utxo, 0) 
            for utxo in spent_utxos
        )
        
        # Send push notification
        await self.notifications.send_alert(
            device_token=vault.device_token,
            title="⚠️ Vault Activity Detected",
            body=f"Your vault is attempting to spend {total_spent} sats. "
                 f"If you didn't do this, open the app to cancel.",
            data={
                "type": "spend_detected",
                "vault_id": vault.vault_id,
                "amount_sats": total_spent,
            }
        )
    
    async def _handle_new_funds(
        self, 
        vault: WatchedVault, 
        new_utxos: Set[str],
        current_utxos: list
    ):
        """Handle incoming funds"""
        if not vault.notification_prefs.get('on_confirmation', True):
            return
        
        total_new = sum(
            u['value'] for u in current_utxos
            if f"{u['txid']}:{u['vout']}" in new_utxos
        )
        
        await self.notifications.send_alert(
            device_token=vault.device_token,
            title="✅ Vault Funded",
            body=f"Your vault received {total_new} sats.",
            data={
                "type": "vault_funded",
                "vault_id": vault.vault_id,
                "amount_sats": total_new,
            }
        )
```

### Electrum Client

```python
# monitoring/electrum.py

import ssl
import json
import asyncio
from typing import List, Dict, Any

class ElectrumClient:
    def __init__(self, host: str, port: int, use_ssl: bool = True):
        self.host = host
        self.port = port
        self.use_ssl = use_ssl
        self.reader = None
        self.writer = None
        self._request_id = 0
    
    async def connect(self):
        """Establish connection to Electrum server"""
        if self.use_ssl:
            ssl_context = ssl.create_default_context()
            self.reader, self.writer = await asyncio.open_connection(
                self.host, self.port, ssl=ssl_context
            )
        else:
            self.reader, self.writer = await asyncio.open_connection(
                self.host, self.port
            )
    
    async def _request(self, method: str, params: list) -> Any:
        """Send JSON-RPC request"""
        self._request_id += 1
        request = {
            "jsonrpc": "2.0",
            "method": method,
            "params": params,
            "id": self._request_id
        }
        
        data = json.dumps(request) + "\n"
        self.writer.write(data.encode())
        await self.writer.drain()
        
        response_line = await self.reader.readline()
        response = json.loads(response_line.decode())
        
        if "error" in response and response["error"]:
            raise ElectrumError(response["error"])
        
        return response.get("result")
    
    async def get_utxos(self, addresses: List[str]) -> List[Dict]:
        """Get UTXOs for addresses"""
        utxos = []
        for address in addresses:
            script_hash = self._address_to_script_hash(address)
            result = await self._request(
                "blockchain.scripthash.listunspent",
                [script_hash]
            )
            for utxo in result:
                utxos.append({
                    "txid": utxo["tx_hash"],
                    "vout": utxo["tx_pos"],
                    "value": utxo["value"],
                    "confirmations": utxo.get("height", 0),
                })
        return utxos
    
    async def get_balance(self, address: str) -> Dict[str, int]:
        """Get confirmed and unconfirmed balance"""
        script_hash = self._address_to_script_hash(address)
        result = await self._request(
            "blockchain.scripthash.get_balance",
            [script_hash]
        )
        return {
            "confirmed": result.get("confirmed", 0),
            "unconfirmed": result.get("unconfirmed", 0)
        }
    
    async def broadcast_tx(self, tx_hex: str) -> str:
        """Broadcast raw transaction"""
        return await self._request(
            "blockchain.transaction.broadcast",
            [tx_hex]
        )
    
    async def get_fee_estimate(self, target_blocks: int) -> float:
        """Get fee estimate in BTC/kvB"""
        result = await self._request(
            "blockchain.estimatefee",
            [target_blocks]
        )
        return result
    
    async def get_block_height(self) -> int:
        """Get current block height"""
        result = await self._request(
            "blockchain.headers.subscribe",
            []
        )
        return result.get("height", 0)
    
    def _address_to_script_hash(self, address: str) -> str:
        """Convert address to Electrum script hash"""
        # Implementation depends on address type
        # Uses hashlib.sha256(script_pubkey)[::-1].hex()
        pass

class ElectrumError(Exception):
    pass
```

### Push Notifications

```python
# notifications/fcm.py

import firebase_admin
from firebase_admin import credentials, messaging
from typing import Dict, Any

class FCMNotificationService:
    def __init__(self, credentials_file: str):
        cred = credentials.Certificate(credentials_file)
        firebase_admin.initialize_app(cred)
    
    async def send_alert(
        self,
        device_token: str,
        title: str,
        body: str,
        data: Dict[str, Any] = None
    ) -> bool:
        """Send push notification to device"""
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data={k: str(v) for k, v in (data or {}).items()},
            token=device_token,
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    click_action="FLUTTER_NOTIFICATION_CLICK",
                    priority="high",
                )
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        alert=messaging.ApsAlert(
                            title=title,
                            body=body,
                        ),
                        sound="default",
                        content_available=True,
                    )
                )
            )
        )
        
        try:
            response = messaging.send(message)
            return True
        except Exception as e:
            logger.error(f"FCM send failed: {e}")
            return False
```

---

## Deployment

### Docker

```dockerfile
# Dockerfile

FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Docker Compose

```yaml
# docker-compose.yml

version: "3.8"

services:
  watcher:
    build: .
    ports:
      - "8000:8000"
    environment:
      - NETWORK=mainnet
      - ELECTRUM_HOST=electrum.blockstream.info
      - ELECTRUM_PORT=50002
    volumes:
      - ./firebase-credentials.json:/app/firebase-credentials.json:ro
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    volumes:
      - redis_data:/data

volumes:
  redis_data:
```

### Requirements

```
# requirements.txt

fastapi==0.109.0
uvicorn[standard]==0.27.0
pydantic==2.5.0
pydantic-settings==2.1.0
firebase-admin==6.3.0
aiohttp==3.9.0
python-dotenv==1.0.0
```

---

## Security Considerations

1. **No Private Keys:** Watcher only receives public descriptors
2. **Rate Limiting:** Protect registration endpoint
3. **Authentication:** Consider JWT for production
4. **HTTPS:** Always use TLS in production
5. **Minimal State:** Designed to be stateless/ephemeral

---

## Self-Hosting Guide

Users can run their own watcher:

```bash
# Clone repository
git clone https://github.com/freedomwallet/vault-watcher.git
cd vault-watcher

# Configure
cp .env.example .env
# Edit .env with your settings

# Run with Docker
docker-compose up -d

# Or run directly
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
```

Configure Flutter app to use custom watcher URL in Settings.
