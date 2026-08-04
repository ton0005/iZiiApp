# iZiiApp Authentication & Security Architecture Plan (iZii-VZKP)

## 📌 Executive Summary

This document specifies the technical security architecture for **iZiiApp**, featuring the **iZii Visual Zero-Knowledge Protocol (iZii-VZKP)**. It provides a multi-layer security design suited for offline-first, BLE Mesh P2P, and cloud-synced operational environments.

---

## 🛡️ Architecture Overview

```
 ┌─────────────────────────────────────────────────────────────────────────┐
 │                            User Device Enclave                          │
 │                                                                         │
 │  ┌──────────────────┐    Argon2id / HKDF    ┌────────────────────────┐  │
 │  │ Secret Image /   │ ────────────────────> │ Master Seed (32 bytes) │  │
 │  │ Image Hash Seed  │                       └───────────┬────────────┘  │
 │  └──────────────────┘                                   │               │
 │                                             ┌───────────┴───────────┐   │
 │                                             ▼                       ▼   │
 │                                    ┌────────────────┐  ┌──────────┐ │
 │                                    │ Ed25519 Keypair│  │  X25519  │ │
 │                                    │ (Sign/Verify)  │  │  (ECDH)  │ │
 │                                    └────────────────┘  └──────────┘ │
 └─────────────────────────────────────────────┬───────────────────────────┘
                                               │ BLE P2P / WebSocket
                                               ▼
 ┌─────────────────────────────────────────────────────────────────────────┐
 │                   Remote Peer / Server Verification                     │
 │                                                                         │
 │  1. Ephemeral X25519 ECDH Handshake ──> Compute Shared Secret           │
 │  2. Generate 4x4 Color Identicon (Mutual Visual Check on Screens)      │
 │  3. Challenge-Response Signed with Ed25519 (Zero Knowledge Proof)       │
 └─────────────────────────────────────────────────────────────────────────┘
```

---

## 1. Image-Key KDF Engine (`ImageKeyKdfEngine`)

### 1.1 Entropy Normalization & Key Derivation
1. **Raw Image Input**: Takes raw bytes of a user-selected image ($I_{user}$).
2. **Argon2id Key Derivation Function**:
   - `Memory`: 64 MB
   - `Iterations`: 3
   - `Parallelism`: 1
   - `Salt`: Device-unique salt combined with user ID.
   $$\text{MasterSeed} = \text{Argon2id}(I_{user}, \text{Salt})$$
3. **KeyPair Generation**:
   - **Ed25519**: `newKeyPairFromSeed(MasterSeed)` for offline & P2P transaction signing.
   - **X25519**: `newKeyPairFromSeed(MasterSeed)` for ECDH key exchange.

---

## 2. P2P BLE Visual Handshake Protocol (`BleP2pHandshakeService`)

### 2.1 Mutual Handshake Steps
1. **Ephemeral Key Exchange**: Alice and Bob exchange temporary X25519 public keys over BLE.
2. **Shared Secret Derivation**: Both devices compute $S_{shared} = \text{X25519}(Priv_{Alice}, Pub_{Bob})$.
3. **Visual Identicon Generation**:
   - Derives a 4x4 color matrix and 4-digit hex verification code using HKDF-SHA256 on $S_{shared}$.
   - Both devices render the exact same color matrix pattern on screen for physical visual verification.
4. **Challenge-Response Sign & Verify**:
   - Alice signs $\text{Payload} = \text{TransactionData} \parallel Nonce \parallel S_{shared}$ using Ed25519.
   - Bob verifies signature against Alice's public key before committing SQLite transaction.

---

## 3. Database & Storage Security

1. **Local Encryption at Rest**: SQLite database (`izii_app_db.sqlite`) is encrypted using AES-256 via SQLCipher.
2. **Secure Key Enclave**: Private key seeds and tokens are stored inside `FlutterSecureStorage` (Android Keystore / iOS Keychain / Windows DPAPI).
