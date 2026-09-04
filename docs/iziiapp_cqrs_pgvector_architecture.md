# Kiến trúc Toàn diện: CQRS & Read-Model Projection kết hợp PGVector
## Thiết kế dành riêng cho Hệ sinh thái iZiiApp / iZiiServer khi mở rộng chuỗi 1.000 – 10.000 Cửa hàng

- **Hệ thống:** iZiiApp / iZiiServer Enterprise Platform
- **Phiên bản tài liệu:** 2.0.0
- **Trạng thái:** Bản thiết kế kiến trúc chuẩn (Architectural Blueprint)
- **Mục tiêu quy mô:** 1.000 – 10.000 cửa hàng / điểm bán lẻ / nông trại phân tán (10.000 – 60.000 thiết bị kết nối)

---

## 1. Tóm tắt điều hành & Bối cảnh kỹ thuật

### 1.1. Hiện trạng hệ thống (Baseline)
- `iziiserver` hiện tại hoạt động theo mô hình **Generic Mutation-Log / Event Store** với 13 bảng hạ tầng trong PostgreSQL/SQLite (bảng cốt lõi là `sync_mutations`).
- Phía thiết bị di động (Flutter / Drift ORM) định nghĩa gần 60 bảng nghiệp vụ (`Products`, `StockQuants`, `PurchaseOrders`, `MushroomJobs`, `GrowRooms`, `Deals`,...).
- Toàn bộ thay đổi của ứng dụng được serialize thành JSON nhét vào cột `data` của `sync_mutations` và đồng bộ dạng delta qua con trỏ tuần tự `seq`.

### 1.2. Thách thức khi mở rộng lên 1.000 – 10.000 Cửa hàng
Khi hệ thống phát triển từ vài chục điểm lên 10.000 cửa hàng:
1. **Bế tắc Báo cáo / Analytics (OLAP / BI):** Không thể trích xuất dữ liệu tổng hợp (Doanh thu toàn chuỗi, tồn kho liên cửa hàng) từ hàng trăm triệu dòng JSON text trong `sync_mutations`.
2. **Thiếu Ràng buộc Toàn vẹn Dữ liệu (Relational Integrity):** Thiếu Foreign Keys, Check Constraints, Unique Index ở cấp Server.
3. **Bùng nổ dữ liệu & Tải khởi động (Storage & Cold-Start):** Thiết bị mới cài app phải kéo hàng triệu mutation cũ về để dựng lại SQLite cục bộ.
4. **Nhu cầu Tìm kiếm Thông minh & Trợ lý AI (AI-Powered Operations):** Tìm kiếm sản phẩm bằng ngôn ngữ tự nhiên, RAG tra cứu sổ tay quy chuẩn vận hành (SOP), phân tích sự cố an toàn ca làm việc (`Alone Worker`).

### 1.3. Giải pháp Kiến trúc: CQRS + Read-Model Projection + PGVector
- **Command / Ingestion (Write Path):** Giữ nguyên tốc độ ghi siêu nhanh của `sync_mutations` để phục vụ hàng vạn client Offline-first.
- **Query / Analytics (Read Path):** Tự động bóc tách JSON mutation thành **60+ bảng quan hệ chuẩn hóa trên PostgreSQL**.
- **Semantic / AI Search (Vector Path):** Tích hợp **PGVector** (HNSW Indexing) ngay trong PostgreSQL để cung cấp khả năng tìm kiếm ngữ nghĩa, Hybrid Search và RAG Assistant.

---

## 2. Sơ đồ Kiến trúc Tổng thể (Architecture Diagram)

```
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                       10.000+ CỬA HÀNG (EDGE / CLIENTS)                                │
│   - Flutter App (iOS / Android / Windows) · Drift SQLite cục bộ                                        │
│   - Bán hàng, kiểm kho, chấm công ngoại tuyến 100% khi mất mạng Internet                               │
└──────────────────────────────────────────────────┬─────────────────────────────────────────────────────┘
                                                   │ 1. POST /sync/push (Batch Mutations JSON)
                                                   ▼
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                FASTAPI INGESTION CLUSTER (WRITE PATH)                                  │
│   - Stateless Uvicorn ASGI Workers chạy sau Global Load Balancer (Nginx / Cloudflare)                  │
│   - Xác thực Device Token, phân quyền, cấp seq đơn điệu, partial commit                                │
└──────────────────────────────────────────────────┬─────────────────────────────────────────────────────┘
                                                   │ 2. Append-only Transactional INSERT
                                                   ▼
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                               POSTGRESQL - WRITE MODEL (CDC / EVENT LOG)                               │
│   - Bảng: sync_mutations (id, client_id, table, operation, data JSONB, seq, store_id, tenant_id)       │
└──────────────────────────────────────────────────┬─────────────────────────────────────────────────────┘
                                                   │ 3. Streaming Event (PG NOTIFY / Redis Streams)
                                                   ▼
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                              PROJECTION & AI EMBEDDING WORKER PIPELINE                                 │
│                                                                                                        │
│   ┌──────────────────────────────────────────────┐  ┌──────────────────────────────────────────────┐   │
│   │         Relational Projector                 │  │             Vector Embedding Pipeline        │   │
│   │ - Bóc tách JSON mutation                     │  │ - Lọc mutation từ bảng products, tickets...  │   │
│   │ - UPSERT vào 60+ bảng quan hệ chuẩn hoá      │  │ - Gọi Embedding Model (BGE-M3 / OpenAI)      │   │
│   │ - Cập nhật số dư tồn kho, doanh thu          │  │ - Sinh vector biểu diễn 768 chiều            │   │
│   └──────────────────────┬───────────────────────┘  └──────────────────────┬───────────────────────┘   │
└──────────────────────────┼─────────────────────────────────────────────────┼───────────────────────────┘
                           │ 4a. SQL UPSERT                                  │ 4b. Vector UPSERT
                           ▼                                                 ▼
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                               POSTGRESQL - READ MODELS & PGVECTOR STORE                                │
│                                                                                                        │
│   ┌──────────────────────────────────────────────┐  ┌──────────────────────────────────────────────┐   │
│   │          TẦNG BẢNG QUAN HỆ (60+ TABLES)      │  │            TẦNG VECTOR EMBEDDINGS            │   │
│   │ - products (id, sku, name, price, store_id)  │  │ - product_embeddings (product_id, embedding) │   │
│   │ - stock_quants (product_id, qty, store_id)   │  │ - ticket_embeddings (ticket_id, embedding)   │   │
│   │ - orders & order_lines (có Foreign Keys)     │  │ - sop_knowledge_embeddings (doc_id, embed)   │   │
│   │ - customers, work_sessions, mushroom_jobs... │  │ - HNSW Indexes (vector_cosine_ops)           │   │
│   └──────────────────────┬───────────────────────┘  └──────────────────────┬───────────────────────┘   │
└──────────────────────────┼─────────────────────────────────────────────────┼───────────────────────────┘
                           │                                                 │
                           └───────────────────────┬─────────────────────────┘
                                                   │ 5. Hybrid Search (SQL Filter + Vector Cosine)
                                                   ▼
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                 HQ DASHBOARD / WEB PORTAL & AI AGENTS                                  │
│   - Báo cáo doanh thu & tồn kho toàn chuỗi theo thời gian thực (Truy vấn trong vài mili-giây)          │
│   - Tìm kiếm sản phẩm thông minh bằng ngôn ngữ tự nhiên                                                │
│   - Trợ lý AI hỗ trợ vận hành SOP & giám sát quy trình an toàn Alone Worker                            │
└────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Thiết kế Chi tiết Tầng Dữ liệu PostgreSQL & PGVector (Schema DDL)

### 3.1. Kích hoạt Extension và Bảng Quan hệ (Relational Domain Tables)

```sql
-- 1. Bật extension PGVector
CREATE EXTENSION IF NOT EXISTS vector;

-- 2. Bảng sản phẩm chuẩn hoá (Read Model)
CREATE TABLE IF NOT EXISTS products (
    id TEXT PRIMARY KEY,
    store_id TEXT NOT NULL,
    tenant_id TEXT NOT NULL,
    sku TEXT,
    barcode TEXT,
    name TEXT NOT NULL,
    description TEXT,
    category TEXT,
    price NUMERIC(12, 2) DEFAULT 0,
    cost_price NUMERIC(12, 2) DEFAULT 0,
    unit TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    -- Cột tìm kiếm Full-Text tự động (tsvector)
    text_search_tsv TSVECTOR GENERATED ALWAYS AS (
        to_tsvector('simple', coalesce(name, '') || ' ' || coalesce(description, '') || ' ' || coalesce(category, '') || ' ' || coalesce(sku, ''))
    ) STORED
);

-- Index quan hệ & Full-text search
CREATE INDEX IF NOT EXISTS idx_products_tenant_store ON products(tenant_id, store_id);
CREATE INDEX IF NOT EXISTS idx_products_sku ON products(sku);
CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode);
CREATE INDEX IF NOT EXISTS idx_products_tsv ON products USING GIN(text_search_tsv);

-- 3. Bảng tồn kho thời gian thực (Real-time Stock Quants)
CREATE TABLE IF NOT EXISTS stock_quants (
    id TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL,
    store_id TEXT NOT NULL,
    product_id TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    location_id TEXT NOT NULL,
    quantity NUMERIC(12, 3) NOT NULL DEFAULT 0,
    reserved_quantity NUMERIC(12, 3) NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT uq_stock_quant_location UNIQUE (tenant_id, store_id, product_id, location_id)
);

CREATE INDEX IF NOT EXISTS idx_stock_quants_lookup ON stock_quants(tenant_id, store_id, product_id);

-- 4. Bảng đơn hàng (Orders) & Chi tiết đơn hàng (Order Lines)
CREATE TABLE IF NOT EXISTS orders (
    id TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL,
    store_id TEXT NOT NULL,
    order_number TEXT NOT NULL,
    customer_id TEXT,
    cashier_user_id TEXT,
    total_amount NUMERIC(14, 2) NOT NULL DEFAULT 0,
    discount_amount NUMERIC(14, 2) NOT NULL DEFAULT 0,
    payment_method TEXT NOT NULL,
    status TEXT NOT NULL, -- 'completed', 'pending', 'cancelled'
    created_at TIMESTAMPTZ NOT NULL,
    synced_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_orders_analytics ON orders(tenant_id, store_id, created_at, status);

CREATE TABLE IF NOT EXISTS order_lines (
    id TEXT PRIMARY KEY,
    order_id TEXT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id TEXT NOT NULL REFERENCES products(id),
    product_name TEXT NOT NULL,
    quantity NUMERIC(12, 3) NOT NULL,
    unit_price NUMERIC(12, 2) NOT NULL,
    subtotal NUMERIC(14, 2) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_order_lines_product ON order_lines(product_id);
```

### 3.2. Bảng Vector Embeddings với Chỉ mục HNSW

```sql
-- 5. Bảng lưu trữ Vector Embedding cho Sản phẩm
CREATE TABLE IF NOT EXISTS product_embeddings (
    product_id TEXT PRIMARY KEY REFERENCES products(id) ON DELETE CASCADE,
    tenant_id TEXT NOT NULL,
    store_id TEXT NOT NULL,
    -- Vector 768 chiều (tương thích mô hình BGE-M3 / Nomic-Embed / text-embedding-3-small)
    embedding vector(768) NOT NULL,
    embedded_content TEXT NOT NULL,
    last_embedded_at TIMESTAMPTZ NOT NULL
);

-- Chỉ mục HNSW (Hierarchical Navigable Small World) tối ưu tốc độ tìm kiếm dưới 5ms
CREATE INDEX IF NOT EXISTS idx_product_embeddings_hnsw 
ON product_embeddings 
USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);

CREATE INDEX IF NOT EXISTS idx_product_embeddings_tenant ON product_embeddings(tenant_id, store_id);

-- 6. Bảng lưu trữ Vector Embedding cho Sự cố An toàn & Ticket Vận hành
CREATE TABLE IF NOT EXISTS ticket_embeddings (
    ticket_id TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL,
    zone_id TEXT NOT NULL,
    job_type TEXT,
    embedding vector(768) NOT NULL,
    content_summary TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_ticket_embeddings_hnsw 
ON ticket_embeddings 
USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);
```

---

## 4. Pipeline Xử lý Projection & Vector Embedding (Code Blueprint)

Dưới đây là mã nguồn thành phần Worker chạy ngầm, chịu trách nhiệm nhận mutation từ `sync_mutations` và đồng thời cập nhật cả **Relational State** lẫn **Vector Embedding**.

```python
# server/projection_worker.py
"""
Projection & Embedding Worker:
Lắng nghe Mutation Log -> Chiếu dữ liệu vào bảng quan hệ -> Sinh Vector Embeddings.
"""
import json
import asyncio
import httpx
from datetime import datetime, timezone
from db_postgres import pg_connection
from server_config import CONFIG

EMBEDDING_API_URL = "http://ai-service.internal:8000/embed"  # Hoặc dịch vụ LLM/Embedding nội bộ

async def generate_embedding(text: str) -> list[float]:
    """Sinh vector 768 chiều từ chuỗi văn bản."""
    if not text.strip():
        return []
    async with httpx.AsyncClient(timeout=5.0) as client:
        try:
            resp = await client.post(EMBEDDING_API_URL, json={"text": text})
            resp.raise_for_status()
            return resp.json()["embedding"]
        except Exception as e:
            print(f"⚠️ [AI] Lỗi sinh embedding: {e}")
            return []

async def project_single_mutation(conn, mutation: dict):
    table_name = mutation.get("table", "").lower()
    operation = mutation.get("operation", "").lower()
    data = mutation.get("data", {})
    tenant_id = data.get("tenant_id", "default_tenant")
    store_id = data.get("store_id", CONFIG.zone)
    now = datetime.now(timezone.utc)

    # ── 1. PROJECTION CHO BẢNG SẢN PHẨM (PRODUCTS) ────────────────────────
    if table_name == "products":
        product_id = data.get("id")
        if operation in ("insert", "update", "create", "upsert"):
            # 1a. Upsert vào bảng quan hệ products
            conn.execute("""
                INSERT INTO products (
                    id, store_id, tenant_id, sku, barcode, name, description, 
                    category, price, cost_price, unit, is_active, created_at, updated_at
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (id) DO UPDATE SET
                    store_id    = EXCLUDED.store_id,
                    tenant_id   = EXCLUDED.tenant_id,
                    sku         = EXCLUDED.sku,
                    barcode     = EXCLUDED.barcode,
                    name        = EXCLUDED.name,
                    description = EXCLUDED.description,
                    category    = EXCLUDED.category,
                    price       = EXCLUDED.price,
                    cost_price  = EXCLUDED.cost_price,
                    unit        = EXCLUDED.unit,
                    is_active   = EXCLUDED.is_active,
                    updated_at  = EXCLUDED.updated_at
            """, (
                product_id, store_id, tenant_id, data.get("sku"), data.get("barcode"),
                data.get("name", ""), data.get("description", ""), data.get("category"),
                data.get("price", 0), data.get("cost_price", 0), data.get("unit", "cái"),
                data.get("is_active", True), data.get("created_at") or now, now
            ))

            # 1b. Sinh vector embedding nếu có thông tin văn bản
            search_content = f"{data.get('name', '')} {data.get('category', '')} {data.get('description', '')}".strip()
            vec = await generate_embedding(search_content)
            if vec:
                vec_str = "[" + ",".join(map(str, vec)) + "]"
                conn.execute("""
                    INSERT INTO product_embeddings (
                        product_id, tenant_id, store_id, embedding, embedded_content, last_embedded_at
                    ) VALUES (%s, %s, %s, %s, %s, %s)
                    ON CONFLICT (product_id) DO UPDATE SET
                        embedding        = EXCLUDED.embedding,
                        embedded_content = EXCLUDED.embedded_content,
                        last_embedded_at = EXCLUDED.last_embedded_at
                """, (product_id, tenant_id, store_id, vec_str, search_content, now))

        elif operation == "delete":
            conn.execute("DELETE FROM products WHERE id = %s", (product_id,))

    # ── 2. PROJECTION CHO BẢNG TỒN KHO (STOCK_QUANTS) ─────────────────────
    elif table_name in ("stock_quants", "stockmoves"):
        # Logic cập nhật tồn kho tức thời vào bảng stock_quants
        pass
```

---

## 5. Công cụ Tìm kiếm Lai (Hybrid Search Engine: Full-Text + Vector Cosine)

Hệ thống sử dụng giải thuật **Reciprocal Rank Fusion (RRF)** kết hợp giữa độ chính xác từ khóa chính xác của **TsVector** và khả năng hiểu ngữ cảnh của **PGVector**.

```python
# server/routers/ai_search.py
from fastapi import APIRouter, Depends, Query
from dependencies import get_db
from projection_worker import generate_embedding

router = APIRouter(prefix="/search", tags=["AI Hybrid Search"])

@router.get("/products")
async def search_products(
    q: str = Query(..., description="Từ khóa hoặc câu hỏi tự nhiên"),
    store_id: str = Query(None, description="Lọc theo cửa hàng cụ thể"),
    tenant_id: str = Query("default_tenant"),
    limit: int = 20,
    conn = Depends(get_db)
):
    query_vec = await generate_embedding(q)
    vec_str = "[" + ",".join(map(str, query_vec)) + "]"

    sql = """
    WITH semantic_ranking AS (
        SELECT p.id, p.name, p.sku, p.price, p.category, p.store_id,
               ROW_NUMBER() OVER (ORDER BY pe.embedding <=> %s::vector) AS rank_vec
        FROM products p
        JOIN product_embeddings pe ON p.id = pe.product_id
        WHERE p.tenant_id = %s
          AND (p.store_id = %s OR %s IS NULL)
          AND p.is_active = TRUE
        LIMIT 50
    ),
    keyword_ranking AS (
        SELECT p.id, p.name, p.sku, p.price, p.category, p.store_id,
               ROW_NUMBER() OVER (ORDER BY ts_rank(p.text_search_tsv, plainto_tsquery('simple', %s)) DESC) AS rank_text
        FROM products p
        WHERE p.tenant_id = %s
          AND p.text_search_tsv @@ plainto_tsquery('simple', %s)
          AND (p.store_id = %s OR %s IS NULL)
          AND p.is_active = TRUE
        LIMIT 50
    )
    SELECT COALESCE(s.id, k.id) AS id,
           COALESCE(s.name, k.name) AS name,
           COALESCE(s.sku, k.sku) AS sku,
           COALESCE(s.price, k.price) AS price,
           COALESCE(s.category, k.category) AS category,
           COALESCE(s.store_id, k.store_id) AS store_id,
           -- Điểm số kết hợp RRF (k=60 tiêu chuẩn)
           (COALESCE(1.0 / (60 + s.rank_vec), 0.0) + COALESCE(1.0 / (60 + k.rank_text), 0.0)) AS rrf_score
    FROM semantic_ranking s
    FULL OUTER JOIN keyword_ranking k ON s.id = k.id
    ORDER BY rrf_score DESC
    LIMIT %s;
    """

    cursor = conn.cursor()
    cursor.execute(sql, (
        vec_str, tenant_id, store_id, store_id,
        q, tenant_id, q, store_id, store_id,
        limit
    ))
    rows = cursor.fetchall()
    return {
        "query": q,
        "total": len(rows),
        "items": [dict(r) for r in rows]
    }
```

---

## 6. Chiến lược Quản trị Hạ tầng & Tối ưu hóa Bộ nhớ cho 10.000 Cửa hàng

### 6.1. Dự toán Bộ nhớ RAM cho PGVector
- Mỗi vector 768 chiều (float32) chiếm: $768 \times 4 \text{ bytes} \approx 3.072 \text{ bytes (3 KB)}$.
- Với chỉ mục **HNSW**, chi phí index overhead là khoảng 64 bytes cho mỗi vector node.
- **Tính toán cho 2.000.000 sản phẩm & tài liệu trên toàn bộ 10.000 cửa hàng:**
  $$\text{Dung lượng Vector} = 2.000.000 \times 3,14 \text{ KB} \approx 6,28 \text{ GB RAM}$$
- **Khuyến nghị phần cứng:** 1 máy chủ Database với **32 GB – 64 GB RAM** hoàn toàn đủ sức chứa toàn bộ HNSW Index trong bộ nhớ đệm (RAM Buffers), đảm bảo độ trễ truy vấn vector luôn $\le 5\text{ ms}$.

### 6.2. Cấu hình Tham số PostgreSQL Tối ưu
```ini
# postgresql.conf tối ưu cho PGVector + CQRS
shared_buffers = 16GB                  # 25% - 50% tổng RAM
work_mem = 64MB
maintenance_work_mem = 2GB             # Cần thiết khi xây dựng chỉ mục HNSW
effective_cache_size = 48GB

# Tối ưu HNSW Index Search
hnsw.ef_search = 40                    # Cân bằng tối ưu giữa độ chính xác (recall 99%) và tốc độ (3ms)
```

### 6.3. Chiến lược Data Compaction & Archiving
1. **Dọn dẹp `sync_mutations` định kỳ:** Nhờ có tầng Read Model lưu trữ trạng thái mới nhất, bảng `sync_mutations` chỉ cần lưu trữ lịch sử 30 – 60 ngày. Sau thời gian này, các mutation cũ được chuyển sang lưu trữ dạng Parquet trên **AWS S3 / MinIO Cold Storage**.
2. **Initial Sync Snapshot cho Thiết bị mới:** Khi một cửa hàng mở mới hoặc nhân viên cài lại ứng dụng, thiết bị chỉ cần gọi API `/snapshot/state?store_id=...` để tải trạng thái hiện tại từ các bảng Domain về SQLite, thay vì phải tải và chạy hàng triệu mutation log từ đầu.

---

## 7. Lộ trình Triển khai Chi tiết (Implementation Roadmap)

| Giai đoạn | Mục tiêu | Hạng mục thực hiện | Thời gian dự kiến |
| :--- | :--- | :--- | :--- |
| **Phase 1** | **Chuẩn bị Schema & PGVector** | - Cài đặt extension `vector` trên PostgreSQL.<br>- Thêm DDL các bảng quan hệ (`products`, `orders`, `stock_quants`) và bảng embeddings vào `db_init_postgres.py`. | 1 – 2 tuần |
| **Phase 2** | **Triển khai Projection Worker** | - Xây dựng module `projection_worker.py` lắng nghe mutation log.<br>- Tích hợp cơ chế UPSERT bất đồng bộ vào `event_engine.py`. | 2 tuần |
| **Phase 3** | **Tích hợp Embedding Pipeline & AI Search** | - Dựng microservice sinh embedding nội bộ.<br>- Mở endpoint `/search/products` với giải thuật Hybrid Search (RRF). | 2 tuần |
| **Phase 4** | **Báo cáo Trung tâm & Snapshot API** | - Xây dựng API báo cáo tài chính/tồn kho thời gian thực cho HQ Dashboard.<br>- Cung cấp endpoint khởi tạo nhanh Snapshot State cho thiết bị mới. | 2 tuần |

---

*Tài liệu này là thiết kế kiến trúc chuẩn — phục vụ định hướng phát triển dài hạn cho hệ thống iZiiApp.*  
*Ngày lập: 04/09/2026*
