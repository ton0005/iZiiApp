# Multi-Server Deployment & Multi-Subnet Network Architecture
**System:** iZiiApp / Costa Mushroom Enterprise Farm Platform  
**Target Environment:** Multi-Plant Farm Network Infrastructure (Multi-Subnet / Multi-Router Environment)  
**Document Version:** 1.0.0  
**Date:** July 20, 2026  

---

## 1. Executive Summary & Architectural Context

The iZiiApp enterprise platform operates in a physical farm environment spanning multiple isolated operational units (e.g., **Plant M1**, **Plant M2**, and **Cool Room Storage**). 

To ensure continuous, zero-downtime operation, high availability (HA), and low latency for field workers (harvesters, supervisors, and growing leads), the platform transitions from a single-server architecture to a **Zone-Based Peer-to-Peer Mesh Multi-Server Architecture**.

### Key System Characteristics:
- **Zone Autonomy**: Each physical plant operates its own dedicated server node (PC/Laptop running FastAPI + SQLite WAL).
- **Subnet Independence**: Server nodes reside on separate physical routers/subnets (`192.168.1.x`, `192.168.2.x`, `192.168.3.x`).
- **Mesh Peer-to-Peer Sync**: Servers continuously synchronize mutation logs (`sync_mutations`) chao-to-chao using delta polling and real-time WebSocket relays.
- **Client Roaming & Auto-Discovery**: Mobile (iOS/Android) and Desktop (Windows) clients dynamically discover and connect to the nearest active server, with automatic fallback when moving across Wi-Fi networks.

---

## 2. Multi-Plant Infrastructure & Network Topology

### 2.1 Overall System Architecture Diagram

```mermaid
flowchart TB
    subgraph PLANT_M1["Plant M1 Zone (Subnet: 192.168.1.0/24)"]
        nodeM1["Server-M1 Node\nIP: 192.168.1.10:8080\n(FastAPI + SQLite WAL)\nZone: M1"]
        devM1_1["iPhone Harvester 1\n(Wi-Fi M1)"]
        devM1_2["iPad Supervisor 1\n(Wi-Fi M1)"]
        devM1_1 -->|WebSocket / HTTP| nodeM1
        devM1_2 -->|WebSocket / HTTP| nodeM1
    end

    subgraph PLANT_M2["Plant M2 Zone (Subnet: 192.168.2.0/24)"]
        nodeM2["Server-M2 Node\nIP: 192.168.2.10:8080\n(FastAPI + SQLite WAL)\nZone: M2"]
        devM2_1["Samsung Picker 2\n(Wi-Fi M2)"]
        devM2_2["iPad Supervisor 2\n(Wi-Fi M2)"]
        devM2_1 -->|WebSocket / HTTP| nodeM2
        devM2_2 -->|WebSocket / HTTP| nodeM2
    end

    subgraph COOL_ROOM["Cool Room Zone (Subnet: 192.168.3.0/24)"]
        nodeCR["Server-CR Node\nIP: 192.168.3.10:8080\n(FastAPI + SQLite WAL)\nZone: CR"]
        devCR_1["Desktop Dispatcher\n(Ethernet CR)"]
        devCR_1 -->|WebSocket / HTTP| nodeCR
    end

    subgraph OVERLAY_VPN["Inter-Plant Mesh VPN Layer (Tailscale / WireGuard)"]
        vpnM1["Virtual IP: 100.64.0.1"]
        vpnM2["Virtual IP: 100.64.0.2"]
        vpnCR["Virtual IP: 100.64.0.3"]
    end

    nodeM1 <--> vpnM1
    nodeM2 <--> vpnM2
    nodeCR <--> vpnCR

    vpnM1 <===>|"Peer-to-Peer Delta Sync\n(HTTP GET /peer-sync/pull)"| vpnM2
    vpnM2 <===>|"Peer-to-Peer Delta Sync\n(HTTP GET /peer-sync/pull)"| vpnCR
    vpnM1 <===>|"Peer-to-Peer Delta Sync\n(HTTP GET /peer-sync/pull)"| vpnCR
```

---

## 3. Network Interconnection & Routing Strategies

When deploying servers across different physical routers or subnets, multicast packets used by default mDNS (Zeroconf) broadcasts cannot cross router boundaries without explicit configuration. To resolve this, two complementary strategies are employed:

### 3.1 Inter-Server Overlay Mesh VPN (Recommended Primary Strategy)
* **Technology**: **Tailscale** or **WireGuard** point-to-point mesh.
* **Mechanism**: Each server node runs a lightweight daemon creating an encrypted virtual network interface (`100.64.x.x`).
* **Advantages**:
  - Completely bypasses local physical router restrictions, NAT firewalls, and subnet isolation.
  - Zero router reconfiguration required.
  - End-to-end encrypted (E2EE) inter-server communications.

### 3.2 Static IP & Inter-VLAN Routing (Alternative Strategy)
* **Mechanism**: Assign fixed DHCP reservations for all server PCs (`192.168.1.10`, `192.168.2.10`, `192.168.3.10`).
* **Configuration**: Declare static peer endpoints in each server's `.env` configuration file:
  ```env
  # Server-M1 Configuration (.env)
  IZIIAPP_SERVER_ID=server-m1
  IZIIAPP_ZONE=M1
  IZIIAPP_PEERS=http://192.168.2.10:8080,http://192.168.3.10:8080
  IZIIAPP_SYNC_INTERVAL_SECONDS=45
  ```

---

## 4. Inter-Server Synchronization Protocol (`peer_sync.py`)

The Server-to-Server synchronization engine utilizes an idempotent, delta-based mutation relay mechanism designed to prevent echo loops and bandwidth exhaustion.

```mermaid
sequenceDiagram
    autonumber
    participant S2 as Server-M2 (Requester)
    participant S1 as Server-M1 (Provider)
    participant DB1 as SQLite DB (Server-M1)
    participant WS1 as Connected Clients (Server-M1)

    Note over S2,S1: Phase 1: Background Polling Task (_peer_sync_loop) every 45s
    S2->>S1: GET /peer-sync/pull?since=2026-07-20T12:00:00Z&requester_server_id=server-m2
    S1->>DB1: Query sync_mutations WHERE server_received_at > timestamp<br/>AND (origin_server_id != 'server-m2')
    DB1-->>S1: Return filtered mutations array
    S1-->>S2: HTTP 200 OK { server_id: "server-m1", updates: [...], server_time: "..." }
    
    Note over S2: Apply mutations via repo.push_mutations()<br/>(INSERT OR REPLACE by mutation ID)
    
    Opt Real-Time Cross-Zone Relay
        S2->>WS1: Broadcast WebSocket event: sync_trigger { tables: [...] }
        Note over WS1: Connected mobile apps trigger instant UI refresh
    End
```

### Key Protocol Safety Principles:

1. **Anti-Echo Loop Protection (`exclude_origin_server_id`)**:
   When `Server-M2` pulls updates from `Server-M1`, `Server-M1` excludes any mutations that originated on `Server-M2`. This prevents infinite back-and-forth relay loops.
2. **Idempotency (`INSERT OR REPLACE`)**:
   Mutations are applied by unique deterministic ID (`UUID`). Receiving the same mutation multiple times due to network retries causes no side effects or state corruption.
3. **Preservation of Origin Metadata**:
   When relaying mutations between peer servers, the original `origin_server_id` is preserved intact.

---

## 5. Client Auto-Discovery & Roaming Logic

Mobile and Desktop clients support automatic network discovery combined with fallback server switching when workers move between plant Wi-Fi zones.

```mermaid
flowchart TD
    Start([App Launches / Network Switches]) --> ScanMDNS[Scan Local Network via mDNS<br/>_iziiapp._tcp.local.]
    ScanMDNS --> FoundMDNS{Server Found on<br/>Current Subnet?}
    
    FoundMDNS -- Yes --> ConnectLocal[Connect to Discovered Local Server<br/>e.g., Server-M1: 192.168.1.10]
    
    FoundMDNS -- No --> TrySaved[Try Last Known Saved Servers List<br/>Server-M1, Server-M2, Server-CR]
    
    TrySaved --> PingCheck{Any Server<br/>Responding?}
    
    PingCheck -- Yes --> SwitchServer[Switch Active Connection to Available Server<br/>Show Toast: 'Connected to Server-M2']
    PingCheck -- No --> ManualIP[Prompt Manual Server IP Input / Local Offline Mode]
    
    ConnectLocal --> SaveLast[Save Connected Server to App Preferences]
    SwitchServer --> SaveLast
    SaveLast --> End([Ready for Operation])
```

---

## 6. Fault Tolerance & Outage Resilience

```mermaid
stateDiagram-v2
    [*] --> NormalOperation: Inter-Plant Network Healthy
    
    state NormalOperation {
        [*] --> PeerSyncActive: Server-M1 <--> Server-M2 Syncing
        PeerSyncActive --> LocalClientServing: Serving local harvesters & room sensors
    }

    NormalOperation --> NetworkPartition: Inter-Plant Cable Cut / Link Failure

    state NetworkPartition {
        [*] --> StandaloneM1: Server-M1 operates 100% autonomously
        [*] --> StandaloneM2: Server-M2 operates 100% autonomously
        Note left of StandaloneM1: All local harvests, room edits & jobs<br/>are logged locally in sync_mutations
    }

    NetworkPartition --> Recovery: Physical Network Link Restored

    state Recovery {
        [*] --> AutoCatchUp: _peer_sync_loop triggers
        AutoCatchUp --> DeltaPull: Pull mutations WHERE server_received_at > last_successful_sync
        DeltaPull --> FullySynced: Zero data loss, all state reconciled
    }

    FullySynced --> NormalOperation
```

---

## 7. Implementation & Migration Phases

| Phase | Target Scope | Key Tasks | Impact / Risk |
| :--- | :--- | :--- | :--- |
| **Phase 0** | Core Server Prep | Integrate `server_config.py`, `server_discovery.py`, and `routers/peer_sync.py`. Add `origin_server_id` column to `sync_mutations` table. | Low — Server runs in standalone mode initially. |
| **Phase 1** | Inter-Server Polling | Deploy Server-M1 and Server-M2. Enable `_peer_sync_loop` background polling task (45s interval) over Tailscale Mesh or Static IP. | Low — Background server sync; client connections remain unchanged. |
| **Phase 2** | Client mDNS & Roaming | Enable mDNS advertising on servers and auto-discovery/fallback switching on Mobile and Windows apps. | Medium — Managed rollout; client keeps manual IP fallback. |
| **Phase 3** | Cross-Server Backup | Implement automated cross-server database snapshot replication across all 3 plant servers. | Low — Background periodic compressed DB dumps. |
| **Phase 4** | WebSocket Real-Time Relay | Upgrade polling sync to immediate WebSocket event push (`POST /peer-sync/push`) for urgent events (Safety Alarms, Chat). | Low — Retains polling sync as secondary fallback safety net. |

---

## 8. Conclusion

By adopting this **Zone-Based Peer-to-Peer Mesh Architecture**, the Costa Mushroom iZiiApp platform achieves:
1. **Uninterrupted Autonomy**: Each physical plant functions independently even during total network isolates.
2. **Infinite Horizontal Scale**: Easily add new plant servers (e.g., Plant M3) without modifying existing server configs.
3. **Zero Single Point of Failure**: Eliminates central server dependency and preserves all operational data securely across cross-server peer backups.
