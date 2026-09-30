# Daily Anchor API Contract

This API defines how the daily token batch is assembled, hashed into a Merkle root, and anchored to a public chain for immutable proof.

## 1. Endpoint

```http
POST /api/v1/anchor/daily
```

## 2. Request Body

```json
{
  "anchorDate": "2026-09-27",
  "sessionId": "session-uuid",
  "proofRef": "LEO3C-BLOCKCHAIN-PROOF-20260927-001",
  "tokens": [
    {
      "tokenId": "BTM-LEO3C-20260927-0001",
      "sha256": "d1afa4758b3cd2d1ee1980283a5e43c784a04c38c289b645ccf6578b4816b7f7",
      "createdAt": "2026-09-27T07:18:00+07:00",
      "tstSignature": "MIIG...",
      "tstTimestamp": "2026-09-27T07:18:00+07:00"
    },
    {
      "tokenId": "BTM-LEO3C-20260927-0002",
      "sha256": "3f7d5d1a3a9b8...",
      "createdAt": "2026-09-27T07:19:00+07:00",
      "tstSignature": "MIIG...",
      "tstTimestamp": "2026-09-27T07:19:00+07:00"
    }
  ]
}
```

## 3. Server Processing

The server must:

1. Validate all token hashes and timestamp signatures
2. Order tokens by `tokenId` or creation time
3. Compute a Merkle root of the batch
4. Store the daily batch in append-only storage
5. Submit the Merkle root or anchor payload to the configured public chain
6. Return the chain transaction metadata

## 4. Success Response

```json
{
  "status": "success",
  "anchorId": "ANCHOR-20260927-001",
  "anchorDate": "2026-09-27",
  "tokenCount": 2,
  "merkleRoot": "0x91d2...",
  "txHash": "0x3fe7...",
  "blockNumber": 4191821,
  "chain": "Polygon",
  "proofRef": "LEO3C-BLOCKCHAIN-PROOF-20260927-001",
  "timestamp": "2026-09-27T08:00:00+07:00",
  "message": "Daily anchor created successfully"
}
```

## 5. Validation Rules

- `anchorDate` must be valid date string in `YYYY-MM-DD`
- Every token in batch must include valid `sha256`
- Every token must include valid `tstSignature`
- `tokenCount` must equal number of tokens submitted
- `merkleRoot` must be deterministic based on ordered token hashes
- `txHash` must be returned by the public chain after anchoring

## 6. Public Chain Anchoring Rules

The daily anchor can be submitted to a public chain such as:
- Polygon
- BNB Smart Chain
- Another approved immutable chain

The anchor payload should include:
- `anchorId`
- `anchorDate`
- `merkleRoot`
- `proofRef`
- `tokenCount`
- `timestamp`

## 7. Error Responses

### 400 Bad Request

```json
{
  "status": "error",
  "code": "INVALID_ANCHOR_REQUEST",
  "message": "Request is missing tokens or proofRef"
}
```

### 409 Conflict

```json
{
  "status": "error",
  "code": "ANCHOR_ALREADY_EXISTS",
  "message": "Daily anchor already exists for this date"
}
```

### 500 Internal Server Error

```json
{
  "status": "error",
  "code": "ANCHOR_FAILURE",
  "message": "Daily anchor creation failed"
}
```

## 8. Audit & Proof Notes

- Daily batches must be append-only
- Merkle root is the immutable record used to validate token integrity
- The token hashes used in the daily batch must remain unchanged after the anchor is created
- Chain transaction hash and anchor timestamp must be stored for legal and proof-of-work verification
