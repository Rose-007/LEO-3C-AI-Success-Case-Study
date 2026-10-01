# TOKEN_SCHEMA.md — โครงสร้าง token พร้อม proof + valuation layers
> Model: $10 ค่าแรกเข้าเท่านั้น คืนในรูป BTM-TOKEN | ไม่ควรมีส่วนเหลือ - จะกำหนดอีกทีภายหลัง

## Base Token (จาก Gt. Module)
```json
{
  "tokenId": "unique_id",
  "createdAt": "timestamp",
  "ipAddress": "source_ip",
  "status": "Order|Exception|Solved|Match"
}
```

## v2 Cloud-Backed Full Schema (ปัจจุบัน)
```json
{
  "tokenId": "BTM-LEO3C-20260927-0001",
  "sha256": "d1afa4758b3cd2d1ee1980283a5e43c784a04c38c289b645ccf6578b4816b7f7",
  "tstSignature": "MIIG... RFC3161 Token จาก Timestamp Cloud ของเรา",
  "createdAt": "2026-09-27T07:18:00+07:00",
  "timestamp": "2026-09-27T07:18:00+07:00",
  "ipAddress": "source_ip",
  "status": "Order|Exception|Solved|Match",
  "count": 1,
  "costIncurred": 0,
  "royalty": 0,
  "realValue": 0,
  "btmValue": 0,
  "valuationStatus": "PROOF_ONLY",
  "entryFee": {
    "amount": 10,
    "currency": "USD",
    "refundForm": "BTM-TOKEN",
    "note": "ค่าแรกเข้าเท่านั้น ต่อไปไม่ต้องเก็บ เพราะสร้างเองโดยระบบ AI-Success Foundation"
  },
  "metadata": {
    "owner": "พุฒฬส ตระกูลทอง",
    "docType": "LEO-3C-PATENT",
    "chainId": "LEO3C-20260927-AISUCCESS",
    "parentCompanyContract": true,
    "notMetaDirect": true
  },
  "merkle": {
    "leaf": "sha256(tokenId+sha256+tstSignature)",
    "dailyRoot": "pending",
    "anchorTx": "pending"
  }
}
```

## Payment Distribution (ตามระบบ AI-Success-Team Token)

### Entry Fee Distribution: $10 USD
ค่าแรกเข้ากระจายไปยัง:

```
$10 (USD) ค่าแรกเข้า (Entry Fee)
   |
   ├─ 2% ($0.20) → AI-Success Foundation [AS_F]
   │  • ทีมพัฒนาระบบ
   │  • บำรุงรักษา Cloud Infrastructure
   │  • Legal & Compliance
   │
   ├─ 1% ($0.10) → Owner (คุณ) [Owner]
   │  • Personal stake & verification
   │  • Proof-of-Work benefit (6 months)
   │
   └─ 7% ($0.70) → System Cost [SC]
      • Timestamp Authority (TSA) operations
      • HSM (Hardware Security Module) rental
      • Daily Merkle anchor to blockchain
      • PostgreSQL WORM storage
      • Network & API infrastructure
```

### ส่วนที่เหลือ: $9 (90%)
```
$9.00 (90%) → BTM-TOKEN Refund
   |
   └─ Refund เป็น BTM-TOKEN แก่ผู้ใช้งาน
      • ไม่มีการเก็บเงินสดตัวไว้
      • ใช้เพื่อ future proof-of-work operations
      • Append-only ledger record
      • หมดอายุ: 6 เดือน (จากวันสร้าง)
```

**สำคัญ:** ไม่มีคำว่า "ส่วนเหลือ" หรือ "profit margin" - $9 คืนเป็น BTM-TOKEN เท่านั้น

---

## Valuation Layers

### Layer 1: PROOF_ONLY (โปรทักษณ์)
- ✅ sha256 hash สร้างแล้ว
- ✅ tstSignature (RFC3161) ออกแล้ว
- ✅ Append-only ledger record
- ❌ ยังไม่มีมูลค่า (realValue = 0)
- 📍 สถานะ: "เหมือนขุดทองอยู่ใต้ดิน"
- ⏱️ หมดอายุ: 6 เดือน

### Layer 2: ACTIVATED (ใช้งานจริง)
- ✅ PROOF_ONLY → นำไปใช้ (โฉนด, โรงงาน, สิทธิบัตร)
- ✅ Owner claim อำนาจ
- ✅ Smart Contract verify signature
- ✅ Daily anchor → Polygon/BNB
- ❌ ยังคำนวณ realValue ไม่ได้
- 📍 สถานะ: "ในการใช้งาน"
- ⏱️ หมดอายุ: 6 เดือน

### Layer 3: VALUED (ประเมินมูลค่า)
- ✅ ACTIVATED → Smart Contract ประเมิน
- ✅ realValue ≠ 0 (มูลค่าตามสัญญา)
- ✅ ไม่เกี่ยวข้องกับ $10 entry fee
- ✅ Append-only update
- 📍 สถานะ: "พร้อมคำนวณกำไร"
- ⏱️ หมดอายุ: 6 เดือน

---

## Token Lifecycle (ชีวิตของ Token)

```
Day 1:  User submit SHA256
        ↓
        POST /api/v1/timestamp
        ↓
        Output: BTM-LEO3C-20260927-0001
        Status: PROOF_ONLY
        realValue: 0
        Ledger: ✓ Append-only
        ↓
[0 - 6 เดือน: PROOF_ONLY อยู่]
        ↓
Day N:  Owner activate + claim
        ↓
        POST /api/v1/activate/{tokenId}
        Status: ACTIVATED
        Merkle: ✓ ถูก anchor ในวัน N
        ↓
[0 - 6 เดือน: ACTIVATED อยู่]
        ↓
Day M:  Smart Contract value
        (เช่น โฉนดดิน มูลค่า 10,000,000 THB)
        ↓
        Status: VALUED
        realValue: 10000000
        btmValue: (ตามสูตรของระบบ)
        ↓
[0 - 6 เดือน: VALUED อยู่]
        ↓
After 6 months: EXPIRED
        (ต้อง renew เป็น cycle ใหม่)
```

---

## Database Schema (PostgreSQL WORM)

```sql
CREATE TABLE btm_tokens (
  id SERIAL PRIMARY KEY,
  token_id VARCHAR(50) UNIQUE NOT NULL,
  sha256 CHAR(64) NOT NULL,
  tst_signature TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  
  -- Ownership & Auth
  owner_id VARCHAR(100) NOT NULL,
  ip_address INET NOT NULL,
  doc_type VARCHAR(50),
  
  -- Status & Valuation
  status VARCHAR(20) DEFAULT 'Order',
  valuation_status VARCHAR(20) DEFAULT 'PROOF_ONLY',
  real_value DECIMAL(18, 8) DEFAULT 0,
  btm_value DECIMAL(18, 8) DEFAULT 0,
  
  -- Entry Fee Distribution
  entry_fee_total DECIMAL(10, 2) DEFAULT 10.00,
  fee_to_foundation DECIMAL(10, 2) DEFAULT 0.20,
  fee_to_owner DECIMAL(10, 2) DEFAULT 0.10,
  fee_to_system DECIMAL(10, 2) DEFAULT 0.70,
  fee_refund_btm DECIMAL(10, 2) DEFAULT 9.00,
  
  -- Merkle & Anchor
  merkle_leaf CHAR(64),
  daily_root CHAR(64),
  anchor_tx VARCHAR(100),
  anchor_chain VARCHAR(20) DEFAULT 'Polygon',
  
  -- Expiry & Proof-of-Work
  expires_at TIMESTAMP DEFAULT NOW() + INTERVAL '6 months',
  proof_of_work_duration INT DEFAULT 6, -- months
  
  -- Metadata
  metadata JSONB,
  
  -- Append-only constraints
  CONSTRAINT immutable_sha256 CHECK (sha256 IS NOT NULL),
  CONSTRAINT immutable_token_id CHECK (token_id IS NOT NULL)
) WITH (OIDS = FALSE);

-- Append-only audit log
CREATE TABLE btm_audit_log (
  id SERIAL PRIMARY KEY,
  token_id VARCHAR(50) NOT NULL REFERENCES btm_tokens(token_id),
  action VARCHAR(50) NOT NULL,
  old_value JSONB,
  new_value JSONB,
  changed_by VARCHAR(100),
  changed_at TIMESTAMP DEFAULT NOW()
) WITH (OIDS = FALSE);

-- Immutability: disable UPDATE/DELETE on btm_tokens
-- INSERT-only allowed
```

---

## Proof-of-Work Duration: 6 Months

ทุก BTM-Token มี lifecycle 6 เดือน:

| เดือนที่ | สถานะ | การกระทำ |
|---|---|---|
| 0 | PROOF_ONLY | สร้าง + ประทับเวลา |
| 0-6 | ACTIVATED | ใช้งานจริง (claim) |
| 0-6 | VALUED | ประเมินมูลค่า |
| 6 | EXPIRED | ต้อง renew cycle ใหม่ |
| 6+ | RENEWAL | BTM-Token cycle ต่อไป |

**หลักการ:**
- ไม่มีการล็อกถาวร → ต้องแสดง proof-of-work ทุก 6 เดือน
- สิทธิ์ของ Owner = 1% fee ตลอด lifecycle
- ระบบ = 7% fee + infrastructure cost
- Foundation = 2% fee + legal/compliance

---

## Smart Contract Integration

ใช้ร่วมกับ:
- `DailyAnchor.sol` → submit merkle root ทุกวัน
- `BTMToken.sol` (ERC-1155) → mint refund tokens
- `OwnershipVerify.sol` → verify owner signature

(ดูรายละเอียดใน `PROOF_OF_WORK_CONTRACT.md`)

