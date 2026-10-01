# PROOF_OF_WORK_CONTRACT.md — Smart Contract Architecture

## Overview

AI-Success Platform uses a dual-contract system for proof-of-work and token refunds:

```
User Entry
   ↓
$10 USD Payment
   ↓ (recorded in DailyAnchor)
   ├─→ Stored in Owner's Bank Account (external)
   ├─→ Audit trail in smart contract
   └─→ Awaiting system operational
        ↓
[System Fully Operational]
        ↓
   ├─→ Stop collecting new $10
   ├─→ Start issuing BTM-TOKEN refunds
   ├─→ Each refund = $10 USD value
   └─→ Issued via BTMToken.sol (ERC-1155)
```

---

## Contract 1: DailyAnchor.sol

### Purpose
- Daily Merkle root anchor to blockchain
- Record BTM-Token lifecycle (PROOF_ONLY → VALUED → REFUNDABLE)
- Track $10 entry fee payments (audit only)
- Manage 3 revenue streams

### Key Functions

#### `registerToken()`
```solidity
function registerToken(
    string memory _tokenId,
    bytes32 _sha256,
    string memory _tstSignature,
    uint8 _revenueStreamType,
    address _tokenOwner
)
```
Creates new BTM-Token (status: PROOF_ONLY)

#### `recordPayment()`
```solidity
function recordPayment(
    string memory _tokenId,
    address _paidBy,
    uint256 _amountUSDCents  // 1000 = $10.00
)
```
Records $10 entry fee (cannot be called after system operational)

#### `markSystemAsOperational()`
```solidity
function markSystemAsOperational()
```
Flags that system is ready to issue refunds

#### `issueRefundAsToken()`
```solidity
function issueRefundAsToken(
    string memory _tokenId,
    string memory _refundTokenId,
    string memory _refundTxHash
)
```
Marks token as REFUNDABLE (links to BTM-TOKEN refund)

### Token Lifecycle

```
┌──────────────────────────────────────┐
│ PROOF_ONLY (0 days - 6 months)      │
│ - Created with SHA256 + TST sig     │
│ - $10 payment recorded              │
│ - realValue = 0                     │
└──────────────────────────────────────┘
        ↓ (optional)
┌──────────────────────────────────────┐
│ ACTIVATED (0 days - 6 months)       │
│ - Revenue stream validated          │
│ - In use (proof-of-work active)     │
│ - realValue = 0                     │
└──────────────────────────────────────┘
        ↓ (when revenue realized)
┌──────────────────────────────────────┐
│ VALUED (0 days - 6 months)          │
│ - Revenue confirmed                 │
│ - realValue ≠ 0                     │
│ - Ready for refund                  │
└──────────────────────────────────────┘
        ↓ (when system operational)
┌──────────────────────────────────────┐
│ REFUNDABLE (0 days - 6 months)      │
│ - BTM-TOKEN issued ($10 value)      │
│ - Linked to payment record          │
│ - Payer notified                    │
└──────────────────────────────────────┘
        ↓ (after 6 months)
┌──────────────────────────────────────┐
│ EXPIRED                              │
│ - Window closed                     │
│ - Can renew for next cycle          │
└──────────────────────────────────────┘
```

### Event Flow Example

**Day 1 (User registration):**
```
User pays $10 USD → Owner's bank account
Event: PaymentRecorded
{
  tokenId: "BTM-LEO3C-20260927-0001",
  paidBy: 0xUser...,
  amount: 1000 (cents),
  timestamp: 1695797880
}
```

**Day N (System operational):**
```
Owner calls: markSystemAsOperational()
Event: SystemOperationalStatusChanged
{
  isOperational: true,
  timestamp: now
}
```

**Day N+1 (Issue refund):**
```
Owner calls: issueRefundAsToken(...)
Event: RefundIssuedAsToken
{
  tokenId: "BTM-LEO3C-20260927-0001",
  paidBy: 0xUser...,
  refundTokenId: "BTM-REFUND-0001",
  btmTokenValueUSD: 1000,
  refundTxHash: "0x...",
  timestamp: now
}
```

---

## Contract 2: BTMToken.sol (ERC-1155)

### Purpose
- Mint $10 refund tokens
- Track refund proof (immutable)
- Prevent resale (non-transferable)
- Link to payment records

### Key Functions

#### `mintRefundToken()`
```solidity
function mintRefundToken(
    string memory _originalTokenId,
    address _recipient,
    string memory _linkedPaymentHash
) returns (uint256 refundTokenId)
```
Mints 1x BTM-TOKEN ($10 value) for recipient

**Returns:** Unique refund token ID

#### `batchMintRefundTokens()`
```solidity
function batchMintRefundTokens(
    string[] memory _originalTokenIds,
    address[] memory _recipients,
    string[] memory _linkedPaymentHashes
) returns (uint256[] memory refundTokenIds)
```
Batch mint multiple refunds (gas efficient)

#### `verifyRefundToken()`
```solidity
function verifyRefundToken(uint256 _refundTokenId)
    returns (
        bool isValid,
        uint256 paymentAmount,      // 1000 cents
        uint256 paymentTimestamp,
        bool isAlreadyUsed
    )
```
Verify refund token authenticity

#### `getUserRefundTokens()`
```solidity
function getUserRefundTokens(address _user)
    returns (uint256[] memory tokenIds)
```
Get all refund tokens for a user

#### `getUserTotalRefundValue()`
```solidity
function getUserTotalRefundValue(address _user)
    returns (uint256 totalValueCents)
```
Calculate total unused refund value

### Refund Token Properties

```json
{
  "refundTokenId": 1,
  "originalTokenId": "BTM-LEO3C-20260927-0001",
  "originalPayer": "0xUser...",
  "mintedAt": 1695797880,
  "usdValueCents": 1000,
  "linkedPaymentHash": "0x...",
  "isUsed": false,
  "erc1155TokenId": 1,
  "erc1155Quantity": 1
}
```

### Non-Transferability

```solidity
function safeTransferFrom(...) 
    reverts("BTM-Refund tokens cannot be transferred")
```

**Reason:** Refund tokens are proof of entry fee payment, not tradeable assets

---

## Integration Flow

### Phase 1: Collection (Before System Operational)

```
Timeline: Weeks 1-12
┌─────────────────────────────────────────┐
│ New users register                      │
│ - Create token (PROOF_ONLY)             │
│ - Pay $10 USD                           │
│ - Payment recorded in DailyAnchor       │
│ - $10 → Owner's bank account            │
│ - No BTM-TOKEN issued yet               │
└─────────────────────────────────────────┘
```

### Phase 2: System Ready (Mark Operational)

```
Timeline: Week 12 (decision point)
┌─────────────────────────────────────────┐
│ Owner calls: markSystemAsOperational()  │
│ ✓ System is ready                       │
│ ✓ Stop collecting new $10               │
│ ✓ Enable issueRefundAsToken()           │
└─────────────────────────────────────────┘
```

### Phase 3: Refund Issuance (BTM-TOKEN)

```
Timeline: Week 12+ (ongoing)
┌─────────────────────────────────────────┐
│ For each $10 payment recorded:          │
│ 1. Owner calls issueRefundAsToken()     │
│ 2. BTMToken.mintRefundToken() triggered │
│ 3. 1x BTM-TOKEN ($10 value) minted      │
│ 4. Sent to original payer               │
│ 5. Payment marked as REFUNDABLE         │
│ 6. Payment marked as refundedAsToken    │
└─────────────────────────────────────────┘
```

---

## Payment Accounting

### Before System Operational

```
Total $10 collected: N x $10 = N * 1000 cents
Where stored: Owner's personal bank account
Audit trail: DailyAnchor.paymentRecords[]
Status: isRefundedAsToken = false
```

### After System Operational

```
Total $10 refunded: N x BTM-TOKEN
Each token value: $10 USD equivalent
Where issued: User's wallet (ERC-1155)
Audit trail: BTMToken.refundTokens[]
Status: isUsed = false (until claimed)
```

### Accounting Example

**Scenario:** 50 users paid $10 each, system ready on day 30

```
DailyAnchor.sol:
├─ totalCollectedFeesUSDCents = 50,000 (= $500)
├─ totalRefundedAsTokens = 0 (pending issuance)
└─ paymentRecords: [50 entries]

After issueRefundAsToken() x 50:
├─ totalRefundedAsTokens = 50
└─ paymentRecords[i].isRefundedAsToken = true

BTMToken.sol:
├─ refundTokenIdCounter = 51 (1-50 minted)
├─ totalRefundTokensMinted = 50
├─ totalRefundValueMinted = 50,000 cents ($500)
└─ refundTokens: [50 entries with metadata]
```

---

## Security & Audit Trail

### DailyAnchor Append-Only
```
✓ paymentRecords: immutable once recorded
✓ tokenRegistry: only status updates allowed
✓ dailyAnchors: immutable blockchain proof
✓ Events: all transactions logged
```

### BTMToken Non-Transferable
```
✓ safeTransferFrom() disabled
✓ safeBatchTransferFrom() disabled
✓ Only minted once per refund
✓ Linked to original payer permanently
```

### Verification
```solidity
// Verify refund token
(bool isValid, uint256 amount, uint256 time, bool used) = 
    btmToken.verifyRefundToken(refundTokenId);

// Cross-check with payment
PaymentRecord memory payment = dailyAnchor.getPaymentRecord(tokenId);
require(payment.isRefundedAsToken == true);
require(payment.refundTokenId == refundTokenId);
```

---

## Admin Operations

### Daily Operations
```solidity
// Record new $10 payment
dailyAnchor.recordPayment(tokenId, payer, 1000);

// Update revenue streams
dailyAnchor.updateRevenueStream(date, streamType, count, usd, isRealized);

// Create daily anchor
dailyAnchor.createDailyAnchor(date, merkleRoot, count, chain, txHash, blockNum, proofRef);
```

### System Transition
```solidity
// When ready to issue refunds
dailyAnchor.markSystemAsOperational();

// Issue refunds in batch
for each payment:
    dailyAnchor.issueRefundAsToken(tokenId, refundTokenId, txHash);
    btmToken.mintRefundToken(tokenId, recipient, paymentHash);
```

### Audit & Verification
```solidity
// Check system status
(bool isOp, uint256 fees, uint256 refunded) = dailyAnchor.getSystemStatus();

// Verify user's refunds
uint256[] memory refunds = btmToken.getUserRefundTokens(userAddress);
uint256 totalValue = btmToken.getUserTotalRefundValue(userAddress);

// Get all refund details
for each refund:
    RefundTokenInfo info = btmToken.getRefundToken(refundId);
```

---

## Gas Optimization

### Polygon Network (~$0.05-0.20 per tx)

| Operation | Gas | Cost (Polygon) |
|---|---|---|
| registerToken() | ~100K | $0.03-0.08 |
| recordPayment() | ~80K | $0.02-0.05 |
| createDailyAnchor() | ~120K | $0.04-0.10 |
| issueRefundAsToken() | ~90K | $0.03-0.07 |
| mintRefundToken() | ~150K | $0.05-0.12 |
| batchMintRefundTokens() (x50) | ~6M | $1.50-2.50 |

**Monthly cost estimate:**
- 50 users x $10 = 1 x issueRefundAsToken batch
- Daily anchors: 30 x createDailyAnchor
- **Total: ~$20-30/month on Polygon**

---

## Compliance & Legal

### Audit Trail
- ✅ Every payment recorded immutably
- ✅ Every refund linked to original payment
- ✅ Blockchain-verifiable proof
- ✅ No alterations possible (append-only)

### Tax & Accounting
- Owner's bank deposits = income (record separately)
- BTM-TOKEN issuance = non-cash refund (record for accounting)
- No profit or margin retained in system
- Full $10 accounted for in audit trail

### User Rights
- Original payer can verify refund via refundTokenId
- Non-transferable = no resale/trading
- 6-month window to claim/use
- Can dispute with audit trail evidence

