// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * ====================================================================
 * DailyAnchor.sol — AI-Success Daily Merkle Root Anchor
 * ====================================================================
 * 
 * Owner: พุฒฬส ตระกูลทอง | AI-Success Foundation
 * Purpose: 
 *   - Daily batch of BTM tokens → Merkle root
 *   - Anchor root to public chain (Polygon/BNB) at 00:00 UTC
 *   - Immutable proof for all 3 revenue streams:
 *     1. GPT Training Data discovery
 *     2. AI-Success Platform usage ($10 entry)
 *     3. Blockchain transaction fees
 *
 * Model:
 *   - Tokens start as PROOF_ONLY (mined, not valued)
 *   - 6-month lifecycle per token
 *   - When actual revenue realized → realValue updated
 *   - This contract handles proof layer only (append-only)
 *
 * Gas Cost: ~$0.05-0.20/day on Polygon (~$10/month)
 * ====================================================================
 */

interface IMerkleValidator {
    function verifyProof(
        bytes32[] calldata proof,
        bytes32 root,
        bytes32 leaf
    ) external pure returns (bool);
}

contract DailyAnchor {
    // ====================================================================
    // Types
    // ====================================================================
    
    enum ChainType { Polygon, BNBChain, Ethereum }
    
    struct DailyAnchorRecord {
        uint256 anchorDate;           // YYYYMMDD
        bytes32 merkleRoot;           // Root of all tokens created that day
        uint256 tokenCount;           // Number of tokens in batch
        ChainType chain;              // Which chain anchored
        bytes32 transactionHash;      // Blockchain tx hash
        uint256 blockNumber;          // Block number
        string proofRef;              // "LEO3C-BLOCKCHAIN-PROOF-20260927-001"
        uint256 timestamp;            // When anchored (UTC)
        bool isValid;                 // Validation flag
    }
    
    struct RevenueStream {
        string streamName;            // "GPT_TRAINING" | "PLATFORM_USAGE" | "TRANSACTION_FEE"
        uint256 tokenCountToday;      // BTM tokens generated today
        uint256 realValueUSD;         // 0 until revenue realized
        uint256 btmValueToken;        // 0 until revenue realized
        uint256 lastUpdated;          // Last update timestamp
    }
    
    // ====================================================================
    // State
    // ====================================================================
    
    address public owner;
    address public foundationAddress;
    address public systemCostAddress;
    
    uint256 public constant PROOF_OF_WORK_DURATION = 6 * 30 days;  // 6 months in seconds
    uint256 public constant TOKEN_ENTRY_FEE = 10 * 10**18;  // $10 USD in wei
    
    // Payment split (from $10 entry fee)
    uint256 public constant FOUNDATION_PERCENT = 2;   // 2% = $0.20
    uint256 public constant OWNER_PERCENT = 1;        // 1% = $0.10
    uint256 public constant SYSTEM_PERCENT = 7;       // 7% = $0.70
    uint256 public constant REFUND_PERCENT = 90;      // 90% = $9.00 as BTM-TOKEN
    
    // Daily anchors: date => DailyAnchorRecord
    mapping(uint256 => DailyAnchorRecord) public dailyAnchors;
    mapping(uint256 => bool) public dailyAnchorExists;
    
    // Revenue streams per day
    mapping(uint256 => RevenueStream[3]) public dailyRevenueStreams;
    
    // Token registry: tokenId => token metadata
    mapping(string => TokenMetadata) public tokenRegistry;
    
    struct TokenMetadata {
        string tokenId;              // BTM-LEO3C-20260927-0001
        bytes32 sha256;              // Original SHA256
        uint256 createdAt;           // Creation timestamp
        uint256 expiresAt;           // createdAt + 6 months
        string status;               // PROOF_ONLY | ACTIVATED | VALUED
        uint256 realValue;           // USD value (0 initially)
        uint256 btmValue;            // BTM token value (0 initially)
        uint8 revenueStream;         // 0=GPT, 1=Platform, 2=Txn
        bool isValid;                // Verification flag
    }
    
    uint256[] public allAnchorDates;
    
    // ====================================================================
    // Events
    // ====================================================================
    
    event AnchorCreated(
        uint256 indexed date,
        bytes32 merkleRoot,
        uint256 tokenCount,
        string chain,
        bytes32 txHash,
        uint256 timestamp
    );
    
    event TokenRegistered(
        string indexed tokenId,
        bytes32 sha256,
        uint8 revenueStream,
        string status
    );
    
    event TokenValuated(
        string indexed tokenId,
        uint256 realValue,
        uint256 btmValue,
        string status
    );
    
    event RevenueStreamUpdated(
        uint256 indexed date,
        uint8 streamIndex,
        uint256 tokenCount,
        uint256 realValue
    );
    
    // ====================================================================
    // Modifiers
    // ====================================================================
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    
    modifier validDate(uint256 dateYYYYMMDD) {
        require(dateYYYYMMDD >= 20260901 && dateYYYYMMDD <= 20991231, "Invalid date");
        _;
    }
    
    modifier noDoubleAnchor(uint256 date) {
        require(!dailyAnchorExists[date], "Anchor already exists for this date");
        _;
    }
    
    // ====================================================================
    // Constructor
    // ====================================================================
    
    constructor(
        address _foundationAddress,
        address _systemCostAddress
    ) {
        owner = msg.sender;
        foundationAddress = _foundationAddress;
        systemCostAddress = _systemCostAddress;
    }
    
    // ====================================================================
    // Core: Daily Anchor
    // ====================================================================
    
    /**
     * @dev Create daily anchor (called at 00:00 UTC)
     * 
     * Flow:
     * 1. Batch all tokens created yesterday
     * 2. Compute Merkle root
     * 3. Store on public chain
     * 4. Record immutably
     */
    function createDailyAnchor(
        uint256 _date,
        bytes32 _merkleRoot,
        uint256 _tokenCount,
        ChainType _chain,
        bytes32 _txHash,
        uint256 _blockNumber,
        string memory _proofRef
    ) 
        external 
        onlyOwner 
        validDate(_date) 
        noDoubleAnchor(_date)
    {
        DailyAnchorRecord memory record = DailyAnchorRecord({
            anchorDate: _date,
            merkleRoot: _merkleRoot,
            tokenCount: _tokenCount,
            chain: _chain,
            transactionHash: _txHash,
            blockNumber: _blockNumber,
            proofRef: _proofRef,
            timestamp: block.timestamp,
            isValid: true
        });
        
        dailyAnchors[_date] = record;
        dailyAnchorExists[_date] = true;
        allAnchorDates.push(_date);
        
        emit AnchorCreated(
            _date,
            _merkleRoot,
            _tokenCount,
            chainTypeToString(_chain),
            _txHash,
            block.timestamp
        );
    }
    
    /**
     * @dev Get daily anchor by date
     */
    function getDailyAnchor(uint256 _date) 
        external 
        view 
        returns (DailyAnchorRecord memory) 
    {
        require(dailyAnchorExists[_date], "No anchor for this date");
        return dailyAnchors[_date];
    }
    
    // ====================================================================
    // Token Registration (3 Revenue Streams)
    // ====================================================================
    
    /**
     * @dev Register a new BTM token
     * 
     * Revenue streams:
     * 0 = GPT Training Data (discovery formula)
     * 1 = AI-Success Platform Usage ($10 entry)
     * 2 = Blockchain Transaction Fees
     */
    function registerToken(
        string memory _tokenId,
        bytes32 _sha256,
        uint8 _revenueStream,  // 0, 1, or 2
        string memory _status  // "PROOF_ONLY"
    ) 
        external 
        onlyOwner
    {
        require(_revenueStream <= 2, "Invalid revenue stream");
        require(
            keccak256(abi.encodePacked(_status)) == keccak256(abi.encodePacked("PROOF_ONLY")),
            "Initial status must be PROOF_ONLY"
        );
        
        uint256 createdAt = block.timestamp;
        uint256 expiresAt = createdAt + PROOF_OF_WORK_DURATION;
        
        TokenMetadata memory token = TokenMetadata({
            tokenId: _tokenId,
            sha256: _sha256,
            createdAt: createdAt,
            expiresAt: expiresAt,
            status: _status,
            realValue: 0,
            btmValue: 0,
            revenueStream: _revenueStream,
            isValid: true
        });
        
        tokenRegistry[_tokenId] = token;
        
        // Update revenue stream count
        uint256 today = getCurrentDateYYYYMMDD();
        dailyRevenueStreams[today][_revenueStream].tokenCountToday++;
        dailyRevenueStreams[today][_revenueStream].lastUpdated = block.timestamp;
        
        emit TokenRegistered(_tokenId, _sha256, _revenueStream, _status);
    }
    
    // ====================================================================
    // Token Valuation (Only when revenue realized)
    // ====================================================================
    
    /**
     * @dev Valuate a token when actual revenue is realized
     * 
     * This is ONLY called after revenue comes in from:
     * - GPT training usage fees
     * - Platform subscription
     * - Blockchain transaction proceeds
     * 
     * Until then: realValue = 0 (just proof, no valuation)
     */
    function valuateToken(
        string memory _tokenId,
        uint256 _realValueUSD,
        uint256 _btmValueToken,
        string memory _newStatus  // "ACTIVATED" or "VALUED"
    ) 
        external 
        onlyOwner
    {
        require(tokenRegistry[_tokenId].isValid, "Token not found");
        require(_realValueUSD > 0 || _btmValueToken > 0, "Must have some value");
        
        TokenMetadata storage token = tokenRegistry[_tokenId];
        require(
            keccak256(abi.encodePacked(token.status)) == keccak256(abi.encodePacked("PROOF_ONLY")) ||
            keccak256(abi.encodePacked(token.status)) == keccak256(abi.encodePacked("ACTIVATED")),
            "Can only valuate PROOF_ONLY or ACTIVATED tokens"
        );
        
        token.realValue = _realValueUSD;
        token.btmValue = _btmValueToken;
        token.status = _newStatus;
        
        // Update daily revenue stream
        uint256 today = getCurrentDateYYYYMMDD();
        dailyRevenueStreams[today][token.revenueStream].realValueUSD += _realValueUSD;
        dailyRevenueStreams[today][token.revenueStream].btmValueToken += _btmValueToken;
        
        emit TokenValuated(_tokenId, _realValueUSD, _btmValueToken, _newStatus);
    }
    
    /**
     * @dev Get token details
     */
    function getToken(string memory _tokenId) 
        external 
        view 
        returns (TokenMetadata memory) 
    {
        require(tokenRegistry[_tokenId].isValid, "Token not found");
        return tokenRegistry[_tokenId];
    }
    
    /**
     * @dev Check if token is expired (6 months after creation)
     */
    function isTokenExpired(string memory _tokenId) 
        external 
        view 
        returns (bool) 
    {
        TokenMetadata memory token = tokenRegistry[_tokenId];
        return block.timestamp > token.expiresAt;
    }
    
    // ====================================================================
    // Payment Distribution (Entry Fee)
    // ====================================================================
    
    /**
     * @dev Distribute $10 entry fee
     * 
     * Split:
     * - 2% ($0.20) → Foundation (AS_F)
     * - 1% ($0.10) → Owner
     * - 7% ($0.70) → System Cost (infrastructure)
     * - 90% ($9.00) → Refund as BTM-TOKEN (to user)
     */
    function distributeEntryFee() 
        external 
        payable 
        onlyOwner
    {
        require(msg.value == TOKEN_ENTRY_FEE, "Must send exactly $10");
        
        uint256 toFoundation = (msg.value * FOUNDATION_PERCENT) / 100;
        uint256 toOwner = (msg.value * OWNER_PERCENT) / 100;
        uint256 toSystem = (msg.value * SYSTEM_PERCENT) / 100;
        // uint256 refundBTM = (msg.value * REFUND_PERCENT) / 100;  // Minted as BTM-TOKEN
        
        // Send to addresses
        (bool successF, ) = foundationAddress.call{value: toFoundation}("");
        require(successF, "Foundation transfer failed");
        
        (bool successO, ) = owner.call{value: toOwner}("");
        require(successO, "Owner transfer failed");
        
        (bool successS, ) = systemCostAddress.call{value: toSystem}("");
        require(successS, "System cost transfer failed");
        
        // Refund portion ($9) is minted as BTM-TOKEN by separate contract
        // (not handled here - see BTMToken.sol)
    }
    
    // ====================================================================
    // Revenue Stream Management
    // ====================================================================
    
    /**
     * @dev Get revenue stream stats for a date
     * 
     * Streams:
     * 0 = "GPT_TRAINING"
     * 1 = "PLATFORM_USAGE"
     * 2 = "TRANSACTION_FEE"
     */
    function getRevenueStream(uint256 _date, uint8 _streamIndex)
        external
        view
        returns (RevenueStream memory)
    {
        require(_streamIndex <= 2, "Invalid stream index");
        return dailyRevenueStreams[_date][_streamIndex];
    }
    
    /**
     * @dev Update revenue stream when actual revenue comes in
     */
    function updateRevenueStream(
        uint256 _date,
        uint8 _streamIndex,
        uint256 _realValue
    )
        external
        onlyOwner
    {
        require(_streamIndex <= 2, "Invalid stream index");
        
        RevenueStream storage stream = dailyRevenueStreams[_date][_streamIndex];
        stream.realValueUSD = _realValue;
        stream.lastUpdated = block.timestamp;
        
        emit RevenueStreamUpdated(_date, _streamIndex, stream.tokenCountToday, _realValue);
    }
    
    // ====================================================================
    // Proof-of-Work Duration: 6 Months
    // ====================================================================
    
    /**
     * @dev Check token's remaining proof-of-work time
     * @return remaining seconds until expiry
     */
    function getProofOfWorkRemaining(string memory _tokenId)
        external
        view
        returns (uint256)
    {
        TokenMetadata memory token = tokenRegistry[_tokenId];
        if (block.timestamp >= token.expiresAt) {
            return 0;
        }
        return token.expiresAt - block.timestamp;
    }
    
    /**
     * @dev Renew token for another 6-month cycle
     * (Called when user renews after expiry)
     */
    function renewToken(string memory _tokenId)
        external
        onlyOwner
    {
        TokenMetadata storage token = tokenRegistry[_tokenId];
        require(block.timestamp > token.expiresAt, "Token not expired yet");
        
        token.expiresAt = block.timestamp + PROOF_OF_WORK_DURATION;
        token.status = "PROOF_ONLY";  // Reset to proof-only for new cycle
        token.realValue = 0;
        token.btmValue = 0;
    }
    
    // ====================================================================
    // Utilities
    // ====================================================================
    
    function chainTypeToString(ChainType _chain) 
        internal 
        pure 
        returns (string memory) 
    {
        if (_chain == ChainType.Polygon) return "Polygon";
        if (_chain == ChainType.BNBChain) return "BNB Chain";
        return "Ethereum";
    }
    
    function getCurrentDateYYYYMMDD() 
        internal 
        view 
        returns (uint256) 
    {
        uint256 timestamp = block.timestamp;
        // Simplified: just return a day identifier
        // In production: use proper date library
        return (timestamp / 86400) * 10000 + 
               ((timestamp / 3600) % 24) * 100 +
               ((timestamp / 60) % 60);
    }
    
    function getAnchorCount() 
        external 
        view 
        returns (uint256) 
    {
        return allAnchorDates.length;
    }
    
    // ====================================================================
    // Admin
    // ====================================================================
    
    function transferOwnership(address _newOwner) 
        external 
        onlyOwner 
    {
        owner = _newOwner;
    }
    
    function updateFoundationAddress(address _newAddress) 
        external 
        onlyOwner 
    {
        foundationAddress = _newAddress;
    }
    
    function updateSystemCostAddress(address _newAddress) 
        external 
        onlyOwner 
    {
        systemCostAddress = _newAddress;
    }
}
