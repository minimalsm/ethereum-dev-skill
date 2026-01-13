# Testing Smart Contracts with Forge

Comprehensive guide to testing Solidity contracts using Foundry's Forge.

## Test File Structure

```solidity
// test/MyContract.t.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MyContract} from "../src/MyContract.sol";

contract MyContractTest is Test {
    MyContract public myContract;
    address public owner;
    address public user;

    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");

        vm.prank(owner);
        myContract = new MyContract();
    }

    function test_InitialState() public view {
        assertEq(myContract.owner(), owner);
    }
}
```

## Running Tests

```bash
# Run all tests
forge test

# Run with verbosity (see logs, traces)
forge test -v      # Show assertion failures
forge test -vv     # Show logs
forge test -vvv    # Show execution traces
forge test -vvvv   # Show full traces including setup

# Run specific test
forge test --match-test test_Transfer

# Run specific contract
forge test --match-contract MyContractTest

# Run tests matching path
forge test --match-path test/MyContract.t.sol

# Watch mode
forge test --watch
```

## Unit Testing

### Basic Assertions

```solidity
function test_Assertions() public {
    // Equality
    assertEq(value, expected);
    assertEq(value, expected, "Custom error message");

    // Inequality
    assertNotEq(value, unexpected);

    // Greater/Less than
    assertGt(value, threshold);
    assertGe(value, threshold);  // Greater or equal
    assertLt(value, threshold);
    assertLe(value, threshold);  // Less or equal

    // Boolean
    assertTrue(condition);
    assertFalse(condition);

    // Approximate equality (for decimals)
    assertApproxEqAbs(actual, expected, maxDelta);
    assertApproxEqRel(actual, expected, maxPercentDelta);  // Percentage
}
```

### Testing Reverts

```solidity
// Expect any revert
function test_RevertsOnInvalidInput() public {
    vm.expectRevert();
    myContract.doSomethingInvalid();
}

// Expect specific error message
function test_RevertsWithMessage() public {
    vm.expectRevert("Insufficient balance");
    myContract.withdraw(1000 ether);
}

// Expect custom error
function test_RevertsWithCustomError() public {
    vm.expectRevert(MyContract.InsufficientBalance.selector);
    myContract.withdraw(1000 ether);
}

// Custom error with parameters
function test_RevertsWithErrorParams() public {
    vm.expectRevert(
        abi.encodeWithSelector(MyContract.InsufficientBalance.selector, 100, 1000)
    );
    myContract.withdraw(1000);
}

// Expect revert from specific address
function test_RevertsFromAddress() public {
    vm.expectRevert();
    vm.prank(unauthorizedUser);
    myContract.adminFunction();
}
```

### Testing Events

```solidity
// Expect event emission
function test_EmitsTransferEvent() public {
    // Arguments: checkTopic1, checkTopic2, checkTopic3, checkData
    vm.expectEmit(true, true, false, true);
    emit Transfer(from, to, amount);

    myContract.transfer(to, amount);
}

// Expect event with specific address
function test_EmitsFromContract() public {
    vm.expectEmit(true, true, false, true, address(myContract));
    emit Transfer(from, to, amount);

    myContract.transfer(to, amount);
}

// Multiple events
function test_EmitsMultipleEvents() public {
    vm.expectEmit(true, true, false, true);
    emit Approval(owner, spender, amount);

    vm.expectEmit(true, true, false, true);
    emit Transfer(from, to, amount);

    myContract.transferFrom(from, to, amount);
}
```

## Cheatcodes Reference

### Account Management

```solidity
// Create labeled address
address alice = makeAddr("alice");
address bob = makeAddr("bob");

// Create address with private key
(address alice, uint256 alicePrivateKey) = makeAddrAndKey("alice");

// Prank (next call from address)
vm.prank(alice);
myContract.doSomething();

// Start/stop prank (multiple calls)
vm.startPrank(alice);
myContract.doSomething();
myContract.doSomethingElse();
vm.stopPrank();

// Set msg.sender and tx.origin
vm.prank(alice, alice);
```

### Balance Management

```solidity
// Set ETH balance
vm.deal(alice, 100 ether);

// Set ERC20 balance (uses storage manipulation)
deal(address(token), alice, 1000e18);

// Check balance
uint256 balance = alice.balance;
uint256 tokenBalance = token.balanceOf(alice);
```

### Time Manipulation

```solidity
// Set block timestamp
vm.warp(1893456000);

// Increase timestamp
vm.warp(block.timestamp + 1 days);

// Set block number
vm.roll(18000000);

// Skip time (both timestamp and block)
skip(1 days);
```

### Storage Manipulation

```solidity
// Read storage slot
bytes32 value = vm.load(address(contract), bytes32(uint256(0)));

// Write storage slot
vm.store(address(contract), bytes32(uint256(0)), bytes32(uint256(123)));
```

### Environment

```solidity
// Set environment variable
vm.setEnv("API_KEY", "secret");

// Read environment variable
string memory apiKey = vm.envString("API_KEY");
uint256 value = vm.envUint("VALUE");
address addr = vm.envAddress("ADDRESS");
```

## Fuzz Testing

Fuzz testing automatically generates random inputs to find edge cases.

### Basic Fuzzing

```solidity
// Forge generates random values for `amount`
function testFuzz_Deposit(uint256 amount) public {
    vm.assume(amount > 0);
    vm.assume(amount < type(uint96).max);

    vm.deal(user, amount);
    vm.prank(user);
    vault.deposit{value: amount}();

    assertEq(vault.balanceOf(user), amount);
}
```

### Bounding Inputs

```solidity
function testFuzz_Transfer(uint256 amount, address recipient) public {
    // Bound to valid range
    amount = bound(amount, 1, token.balanceOf(user));

    // Exclude zero address
    vm.assume(recipient != address(0));

    // Exclude contract addresses
    vm.assume(recipient.code.length == 0);

    vm.prank(user);
    token.transfer(recipient, amount);

    assertEq(token.balanceOf(recipient), amount);
}
```

### Fuzz Configuration

```toml
# foundry.toml
[fuzz]
runs = 1000              # Number of fuzz runs
max_test_rejects = 65536 # Max rejected inputs before failure
seed = 0x1234            # Reproducible seed (optional)
dictionary_weight = 40   # Weight for dictionary values
```

### Fuzz Best Practices

```solidity
contract FuzzBestPractices is Test {
    // 1. Use bound() over vm.assume() when possible
    function testFuzz_Good(uint256 amount) public {
        amount = bound(amount, 1, 1000 ether);
        // Won't reject any runs
    }

    // 2. Use specific types to constrain range
    function testFuzz_TypeBound(uint96 amount) public {
        // amount is already bounded to uint96 max
    }

    // 3. Avoid expensive vm.assume conditions
    function testFuzz_Avoid(uint256 amount) public {
        // Bad: most values rejected
        vm.assume(amount > 1 ether && amount < 2 ether);

        // Good: all values usable
        amount = bound(amount, 1 ether, 2 ether);
    }
}
```

## Invariant Testing

Invariant testing verifies properties that should always hold true, regardless of the sequence of operations.

### Basic Invariant Test

```solidity
// test/invariants/Invariant.t.sol
contract InvariantTest is Test {
    Vault vault;
    Handler handler;

    function setUp() public {
        vault = new Vault();
        handler = new Handler(vault);

        // Only target the handler
        targetContract(address(handler));
    }

    // Invariant: total assets should equal sum of deposits
    function invariant_totalAssets() public view {
        assertEq(vault.totalAssets(), handler.ghost_totalDeposited());
    }

    // Invariant: no user should have negative balance (impossible, but example)
    function invariant_noNegativeBalances() public view {
        address[] memory actors = handler.getActors();
        for (uint256 i = 0; i < actors.length; i++) {
            assertGe(vault.balanceOf(actors[i]), 0);
        }
    }
}
```

### Handler Contract

```solidity
// test/handlers/Handler.sol
contract Handler is Test {
    Vault vault;

    // Ghost variables track expected state
    uint256 public ghost_totalDeposited;
    uint256 public ghost_totalWithdrawn;

    // Track actors
    address[] public actors;
    mapping(address => bool) public isActor;

    constructor(Vault _vault) {
        vault = _vault;
    }

    // Modifier to track actors
    modifier useActor(uint256 actorSeed) {
        address actor = actors.length > 0
            ? actors[bound(actorSeed, 0, actors.length - 1)]
            : makeAddr("actor");

        if (!isActor[actor]) {
            actors.push(actor);
            isActor[actor] = true;
        }

        vm.startPrank(actor);
        _;
        vm.stopPrank();
    }

    function deposit(uint256 amount, uint256 actorSeed) public useActor(actorSeed) {
        amount = bound(amount, 1, 100 ether);

        vm.deal(msg.sender, amount);
        vault.deposit{value: amount}();

        ghost_totalDeposited += amount;
    }

    function withdraw(uint256 amount, uint256 actorSeed) public useActor(actorSeed) {
        uint256 balance = vault.balanceOf(msg.sender);
        if (balance == 0) return;

        amount = bound(amount, 1, balance);
        vault.withdraw(amount);

        ghost_totalWithdrawn += amount;
    }

    function getActors() external view returns (address[] memory) {
        return actors;
    }
}
```

### Invariant Configuration

```toml
# foundry.toml
[invariant]
runs = 256               # Number of sequences
depth = 128              # Calls per sequence
fail_on_revert = false   # Don't fail on handler reverts
call_override = false    # Use target selectors
```

## Fork Testing

Test against real blockchain state by forking mainnet.

### Setup Fork

```solidity
contract ForkTest is Test {
    uint256 mainnetFork;
    uint256 sepoliaFork;

    function setUp() public {
        // Create forks
        mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"));
        sepoliaFork = vm.createFork(vm.envString("SEPOLIA_RPC_URL"));
    }

    function test_MainnetFork() public {
        // Select fork
        vm.selectFork(mainnetFork);
        assertEq(vm.activeFork(), mainnetFork);

        // Now interact with mainnet state
        IERC20 usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        uint256 totalSupply = usdc.totalSupply();
        assertGt(totalSupply, 0);
    }
}
```

### Impersonating Accounts

```solidity
function test_ImpersonateWhale() public {
    vm.selectFork(mainnetFork);

    address usdcWhale = 0x55FE002aefF02F77364de339a1292923A15844B8;
    IERC20 usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    // Check whale balance
    uint256 whaleBalance = usdc.balanceOf(usdcWhale);
    assertGt(whaleBalance, 1_000_000e6);

    // Impersonate and transfer
    vm.prank(usdcWhale);
    usdc.transfer(address(this), 1_000_000e6);

    assertEq(usdc.balanceOf(address(this)), 1_000_000e6);
}
```

### Rolling Fork State

```solidity
function test_RollFork() public {
    vm.selectFork(mainnetFork);

    // Roll to specific block
    vm.rollFork(18000000);
    assertEq(block.number, 18000000);

    // Roll to timestamp
    vm.rollFork(1700000000);
}
```

## Coverage

```bash
# Generate coverage report
forge coverage

# Generate LCOV report
forge coverage --report lcov

# View in browser (requires genhtml)
genhtml lcov.info -o coverage
open coverage/index.html
```

## Gas Testing

### Gas Snapshots

```bash
# Create snapshot
forge snapshot

# Compare with previous
forge snapshot --diff

# Check gas changed
forge snapshot --check
```

### Inline Gas Measurement

```solidity
function test_GasMeasurement() public {
    uint256 gasBefore = gasleft();
    myContract.expensiveFunction();
    uint256 gasUsed = gasBefore - gasleft();

    console.log("Gas used:", gasUsed);
    assertLt(gasUsed, 100_000);
}
```

## Test Organization

### Recommended Structure

```
test/
├── unit/                    # Unit tests per contract
│   ├── MyContract.t.sol
│   └── MyToken.t.sol
├── integration/             # Integration tests
│   └── Protocol.t.sol
├── invariants/              # Invariant tests
│   ├── Invariant.t.sol
│   └── handlers/
│       └── Handler.sol
├── fork/                    # Fork tests
│   └── Mainnet.t.sol
└── utils/                   # Test utilities
    └── BaseTest.sol
```

### Base Test Contract

```solidity
// test/utils/BaseTest.sol
abstract contract BaseTest is Test {
    address internal owner;
    address internal user1;
    address internal user2;

    function setUp() public virtual {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        vm.deal(owner, 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }

    function _deployContracts() internal virtual;
}
```

## Debugging

### Console Logging

```solidity
import {console} from "forge-std/console.sol";

function test_Debug() public {
    console.log("Value:", value);
    console.log("Address:", addr);
    console.logBytes32(data);

    // Formatted
    console.log("Balance: %s ETH", balance / 1e18);
}
```

### Trace Debugging

```bash
# Show execution trace
forge test --match-test test_Failing -vvvv

# Debug specific test
forge debug --test test_Failing
```
