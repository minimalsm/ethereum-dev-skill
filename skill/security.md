# Smart Contract Security

Essential security patterns and vulnerability prevention for Solidity development.

## Security Mindset

1. **Assume external calls are hostile** - Any external call can trigger reentrancy
2. **Minimize trust** - Don't trust user input, external contracts, or oracles blindly
3. **Fail safely** - When something goes wrong, fail in a way that protects funds
4. **Keep it simple** - Complex code has more attack surface
5. **Test adversarially** - Write tests that try to break your contract

## Common Vulnerabilities

### 1. Reentrancy

**The Problem:** External calls can call back into your contract before state updates complete.

**Vulnerable Code:**
```solidity
// BAD - State updated after external call
function withdraw(uint256 amount) external {
    require(balances[msg.sender] >= amount);

    // External call before state update
    (bool success, ) = msg.sender.call{value: amount}("");
    require(success);

    // State update after - attacker can re-enter
    balances[msg.sender] -= amount;
}
```

**Fix 1: Checks-Effects-Interactions (CEI) Pattern:**
```solidity
// GOOD - State updated before external call
function withdraw(uint256 amount) external {
    // Checks
    require(balances[msg.sender] >= amount, "Insufficient balance");

    // Effects (state changes)
    balances[msg.sender] -= amount;

    // Interactions (external calls)
    (bool success, ) = msg.sender.call{value: amount}("");
    require(success, "Transfer failed");
}
```

**Fix 2: ReentrancyGuard:**
```solidity
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Vault is ReentrancyGuard {
    function withdraw(uint256 amount) external nonReentrant {
        require(balances[msg.sender] >= amount);
        balances[msg.sender] -= amount;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success);
    }
}
```

### 2. Access Control

**The Problem:** Functions that should be restricted are publicly accessible.

**Vulnerable Code:**
```solidity
// BAD - Anyone can call
function setPrice(uint256 _price) external {
    price = _price;
}

function withdrawAll() external {
    payable(owner).transfer(address(this).balance);
}
```

**Fix: Use OpenZeppelin Access Control:**
```solidity
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

// Simple ownership
contract MyContract is Ownable {
    constructor() Ownable(msg.sender) {}

    function setPrice(uint256 _price) external onlyOwner {
        price = _price;
    }
}

// Role-based access
contract MyContract is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function adminFunction() external onlyRole(ADMIN_ROLE) {
        // ...
    }
}
```

### 3. Integer Overflow/Underflow

**The Problem:** In Solidity < 0.8.0, arithmetic operations could overflow/underflow silently.

**Solidity 0.8.0+:** Built-in overflow checks. Operations revert on overflow.

```solidity
// Safe by default in 0.8+
uint256 a = type(uint256).max;
a + 1; // Reverts with Panic(0x11)

// Use unchecked for gas optimization ONLY when overflow is impossible
unchecked {
    // This will wrap around - only use when mathematically safe
    for (uint256 i = 0; i < arr.length; i++) {
        // i++ cannot overflow because arr.length is bounded
    }
}
```

### 4. Front-Running

**The Problem:** Attackers can see pending transactions and insert their own transactions before yours.

**Vulnerable Code:**
```solidity
// BAD - Predictable execution, can be front-run
function claimReward(bytes32 answer) external {
    require(keccak256(abi.encodePacked(answer)) == secretHash);
    payable(msg.sender).transfer(reward);
}
```

**Mitigations:**
```solidity
// Commit-reveal scheme
mapping(address => bytes32) public commitments;

function commit(bytes32 commitment) external {
    commitments[msg.sender] = commitment;
}

function reveal(bytes32 answer, bytes32 salt) external {
    require(commitments[msg.sender] == keccak256(abi.encodePacked(answer, salt)));
    // Process...
}

// Use block.timestamp for ordering (weak)
// Use Flashbots for MEV protection (better)
```

### 5. Oracle Manipulation

**The Problem:** Relying on easily manipulated price sources (e.g., spot prices from AMMs).

**Vulnerable Code:**
```solidity
// BAD - Spot price can be manipulated in same transaction
function getPrice() public view returns (uint256) {
    return uniswapPair.getReserves()[0] / uniswapPair.getReserves()[1];
}
```

**Fix: Use Time-Weighted Average Prices (TWAP) or Chainlink:**
```solidity
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PriceConsumer {
    AggregatorV3Interface internal priceFeed;

    constructor() {
        // ETH/USD on Ethereum mainnet
        priceFeed = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
    }

    function getLatestPrice() public view returns (int256) {
        (
            ,
            int256 price,
            ,
            uint256 updatedAt,
        ) = priceFeed.latestRoundData();

        // Check staleness
        require(block.timestamp - updatedAt < 1 hours, "Stale price");

        return price;
    }
}
```

### 6. Flash Loan Attacks

**The Problem:** Attackers borrow massive amounts instantly (no collateral) to manipulate prices, drain funds, or exploit logic that assumes users have limited capital.

**How Flash Loans Work:**
```solidity
// Attacker in a single transaction:
// 1. Borrow $100M from Aave/dYdX
// 2. Manipulate a price oracle
// 3. Exploit a protocol using that oracle
// 4. Repay the $100M + tiny fee
// 5. Profit
```

**Vulnerable Code:**
```solidity
// BAD - Uses spot price that can be manipulated
function getCollateralValue(address user) public view returns (uint256) {
    uint256 tokenBalance = balanceOf(user);
    uint256 price = uniswapPair.getReserves()[0] / uniswapPair.getReserves()[1];
    return tokenBalance * price;
}

// BAD - Assumes users can't have massive balances
function vote(uint256 proposalId) external {
    uint256 votingPower = token.balanceOf(msg.sender);
    proposals[proposalId].votes += votingPower;
}
```

**Mitigations:**

```solidity
// 1. Use time-weighted prices (TWAP) or Chainlink
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

function getPrice() internal view returns (uint256) {
    (, int256 price,, uint256 updatedAt,) = priceFeed.latestRoundData();
    require(block.timestamp - updatedAt < 1 hours, "Stale price");
    return uint256(price);
}

// 2. Snapshot voting power (prevents flash loan governance attacks)
function vote(uint256 proposalId) external {
    uint256 snapshotBlock = proposals[proposalId].snapshotBlock;
    uint256 votingPower = token.getPastVotes(msg.sender, snapshotBlock);
    proposals[proposalId].votes += votingPower;
}

// 3. Delay sensitive operations
mapping(address => uint256) public lastDeposit;

function withdraw() external {
    require(block.timestamp >= lastDeposit[msg.sender] + 1, "Same block");
    // ... withdraw logic
}

// 4. Compare against previous block
function swap() external {
    uint256 currentPrice = getPrice();
    uint256 previousPrice = getPriceAtBlock(block.number - 1);
    require(
        currentPrice * 100 / previousPrice > 95 &&
        currentPrice * 100 / previousPrice < 105,
        "Price deviation too high"
    );
}
```

**Key Defenses:**
- Use Chainlink or TWAP instead of spot prices
- Snapshot token balances for governance
- Add same-block restrictions for sensitive operations
- Implement price deviation checks
- Consider using `block.number` checks

### 7. Denial of Service (DoS)

**The Problem:** Contract becomes unusable due to unbounded operations or griefing.

**Vulnerable Code:**
```solidity
// BAD - Unbounded loop, can run out of gas
function distributeRewards() external {
    for (uint256 i = 0; i < users.length; i++) {
        users[i].transfer(rewards[i]);
    }
}

// BAD - External call can fail, blocking everyone
function withdrawAll() external {
    for (uint256 i = 0; i < users.length; i++) {
        require(users[i].send(balances[users[i]]));
    }
}
```

**Fix: Pull over Push:**
```solidity
// GOOD - Users withdraw their own funds
mapping(address => uint256) public pendingWithdrawals;

function withdraw() external {
    uint256 amount = pendingWithdrawals[msg.sender];
    require(amount > 0, "Nothing to withdraw");

    pendingWithdrawals[msg.sender] = 0;

    (bool success, ) = msg.sender.call{value: amount}("");
    require(success);
}
```

### 8. Signature Replay

**The Problem:** Signatures can be reused across different contexts.

**Vulnerable Code:**
```solidity
// BAD - Same signature can be used multiple times
function executeWithSignature(
    address to,
    uint256 amount,
    bytes memory signature
) external {
    bytes32 hash = keccak256(abi.encodePacked(to, amount));
    address signer = recoverSigner(hash, signature);
    require(signer == owner);
    // Execute...
}
```

**Fix: Include nonce and chain ID:**
```solidity
mapping(address => uint256) public nonces;

function executeWithSignature(
    address to,
    uint256 amount,
    uint256 nonce,
    bytes memory signature
) external {
    require(nonce == nonces[msg.sender]++, "Invalid nonce");

    bytes32 hash = keccak256(abi.encodePacked(
        address(this),  // Contract address
        block.chainid,  // Chain ID
        to,
        amount,
        nonce
    ));

    address signer = recoverSigner(hash, signature);
    require(signer == owner);
    // Execute...
}
```

### 9. Unsafe External Calls

**The Problem:** Low-level calls don't revert on failure.

**Vulnerable Code:**
```solidity
// BAD - Ignoring return value
target.call(data);

// BAD - Using transfer (2300 gas limit, can fail)
payable(to).transfer(amount);
```

**Fix:**
```solidity
// GOOD - Check return value
(bool success, ) = target.call(data);
require(success, "Call failed");

// GOOD - Use call with check
(bool success, ) = payable(to).call{value: amount}("");
require(success, "Transfer failed");
```

## Security Patterns

### Safe ERC-20 Handling

Always use SafeERC20 for token transfers:

```solidity
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Vault {
    using SafeERC20 for IERC20;

    function deposit(IERC20 token, uint256 amount) external {
        // Handles tokens that don't return bool (like USDT)
        token.safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw(IERC20 token, uint256 amount) external {
        token.safeTransfer(msg.sender, amount);
    }
}
```

### Pausable Contracts

Add emergency stop functionality:

```solidity
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract MyContract is Pausable, Ownable {
    function deposit() external payable whenNotPaused {
        // ...
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
```

### Rate Limiting

Prevent rapid repeated actions:

```solidity
mapping(address => uint256) public lastActionTime;
uint256 public constant COOLDOWN = 1 hours;

modifier rateLimited() {
    require(
        block.timestamp >= lastActionTime[msg.sender] + COOLDOWN,
        "Rate limited"
    );
    lastActionTime[msg.sender] = block.timestamp;
    _;
}

function sensitiveAction() external rateLimited {
    // ...
}
```

## Security Checklist

### Before Deployment

- [ ] All external/public functions have appropriate access control
- [ ] Reentrancy protection on functions that transfer value
- [ ] Input validation on all external functions
- [ ] No hardcoded addresses (use constructor/immutable)
- [ ] Events emitted for all state changes
- [ ] No use of `tx.origin` for authorization
- [ ] Proper handling of ERC-20 tokens (SafeERC20)
- [ ] No unbounded loops
- [ ] Checked arithmetic or explicit unchecked blocks
- [ ] Oracle prices validated for staleness

### Testing

- [ ] Unit tests for all functions
- [ ] Fuzz tests for numeric inputs
- [ ] Invariant tests for critical properties
- [ ] Fork tests for mainnet interactions
- [ ] Test for expected reverts
- [ ] Test edge cases (0, max values, empty arrays)

### Code Quality

- [ ] No compiler warnings
- [ ] Contracts under 24KB (deployment limit)
- [ ] NatSpec documentation on all public functions
- [ ] Consistent naming conventions
- [ ] No dead code

## Security Tools

### Static Analysis

```bash
# Slither - Fast static analysis
pip install slither-analyzer
slither .

# Common issues it catches:
# - Reentrancy
# - Unused variables
# - Missing zero-address checks
# - Dangerous strict equality
```

### Fuzzing

```bash
# Foundry fuzzing (built-in)
forge test --fuzz-runs 10000

# Echidna (property-based fuzzing)
echidna . --contract MyContract --test-mode assertion
```

### Formal Verification

For high-value contracts, consider formal verification with:
- **Certora** - Automated formal verification
- **Halmos** - Symbolic execution for Foundry

## Audit Preparation

Before requesting an audit:

1. **Documentation** - README, architecture docs, known issues
2. **Test coverage** - Aim for >90% line coverage
3. **Clean code** - No commented-out code, clear naming
4. **Deployment plan** - Networks, upgrade strategy, admin keys
5. **Previous audits** - Share any prior audit reports

## Resources

- [Solidity Security Considerations](https://docs.soliditylang.org/en/latest/security-considerations.html)
- [OpenZeppelin Security](https://docs.openzeppelin.com/contracts/5.x/)
- [Smart Contract Weakness Classification (SWC)](https://swcregistry.io/)
- [Consensys Smart Contract Best Practices](https://consensys.github.io/smart-contract-best-practices/)
- [Trail of Bits Building Secure Contracts](https://github.com/crytic/building-secure-contracts)
