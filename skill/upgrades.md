# Upgradeable Contracts

Proxy patterns for deploying contracts that can be upgraded without changing addresses.

## When to Use Upgrades

**Use upgrades when:**
- Bug fixes might be needed post-deployment
- Features will be added over time
- Regulatory requirements may change
- Protocol governance needs flexibility

**Avoid upgrades when:**
- Immutability is a feature (trustless systems)
- Contract is simple and well-audited
- Users expect no admin control

## Proxy Patterns Overview

| Pattern | Gas (Deploy) | Gas (Call) | Complexity | Best For |
|---------|--------------|------------|------------|----------|
| UUPS | Lower | Lower | Medium | Most cases |
| Transparent | Higher | Higher | Lower | Simple admin needs |
| Beacon | Medium | Medium | Higher | Many instances |
| Diamond | Highest | Medium | Highest | Large contracts |

## UUPS Proxy (Recommended)

UUPS (Universal Upgradeable Proxy Standard) puts upgrade logic in the implementation.

### Implementation Contract

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract MyContractV1 is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    uint256 public value;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        value = 0;
    }

    function setValue(uint256 _value) external {
        value = _value;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
```

### V2 with New Features

```solidity
contract MyContractV2 is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    uint256 public value;
    string public name; // New storage variable

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // No initialize for V2 - storage already initialized

    function setValue(uint256 _value) external {
        value = _value;
    }

    // New function in V2
    function setName(string calldata _name) external {
        name = _name;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
```

### Deployment Script

```solidity
// script/DeployUpgradeable.s.sol
import {Script} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MyContractV1} from "../src/MyContractV1.sol";

contract DeployScript is Script {
    function run() external returns (address proxy) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);

        // Deploy implementation
        MyContractV1 implementation = new MyContractV1();

        // Deploy proxy pointing to implementation
        bytes memory initData = abi.encodeCall(
            MyContractV1.initialize,
            (deployer)
        );

        ERC1967Proxy proxyContract = new ERC1967Proxy(
            address(implementation),
            initData
        );

        proxy = address(proxyContract);

        vm.stopBroadcast();
    }
}
```

### Upgrade Script

```solidity
// script/Upgrade.s.sol
import {Script} from "forge-std/Script.sol";
import {MyContractV1} from "../src/MyContractV1.sol";
import {MyContractV2} from "../src/MyContractV2.sol";

contract UpgradeScript is Script {
    function run() external {
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerKey);

        // Deploy new implementation
        MyContractV2 newImplementation = new MyContractV2();

        // Upgrade proxy to new implementation
        MyContractV1 proxy = MyContractV1(proxyAddress);
        proxy.upgradeToAndCall(
            address(newImplementation),
            "" // No initialization data for V2
        );

        vm.stopBroadcast();
    }
}
```

## Transparent Proxy

Simpler but more expensive. Admin calls go to proxy, user calls go to implementation.

```solidity
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract DeployTransparent is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy implementation
        MyContract implementation = new MyContract();

        // Deploy ProxyAdmin (manages upgrades)
        ProxyAdmin admin = new ProxyAdmin(msg.sender);

        // Deploy proxy
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            address(admin),
            abi.encodeCall(MyContract.initialize, (msg.sender))
        );

        vm.stopBroadcast();
    }
}

// Upgrade via ProxyAdmin
// admin.upgradeAndCall(proxy, newImplementation, "")
```

## Beacon Proxy

For deploying many instances that upgrade together.

```solidity
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

contract BeaconFactory {
    UpgradeableBeacon public beacon;

    constructor(address implementation) {
        beacon = new UpgradeableBeacon(implementation, msg.sender);
    }

    function createInstance(bytes calldata initData) external returns (address) {
        BeaconProxy proxy = new BeaconProxy(address(beacon), initData);
        return address(proxy);
    }

    function upgrade(address newImplementation) external {
        // All instances upgrade at once
        beacon.upgradeTo(newImplementation);
    }
}
```

## Storage Layout Rules

**CRITICAL: Never change storage layout in upgrades**

```solidity
// V1 Storage
contract MyContractV1 {
    uint256 public value;      // Slot 0
    address public owner;      // Slot 1
}

// V2 - CORRECT: Append new variables
contract MyContractV2 {
    uint256 public value;      // Slot 0 (unchanged)
    address public owner;      // Slot 1 (unchanged)
    string public name;        // Slot 2 (new)
}

// V2 - WRONG: Changing existing slots
contract MyContractV2Bad {
    address public owner;      // Slot 0 - WRONG! Was uint256
    uint256 public value;      // Slot 1 - WRONG! Was address
}
```

### Storage Gaps

Reserve space for future variables:

```solidity
contract MyContractV1 {
    uint256 public value;

    // Reserve 50 storage slots for future upgrades
    uint256[50] private __gap;
}

contract MyContractV2 {
    uint256 public value;
    string public name; // Uses one slot from gap

    // Reduce gap by 1
    uint256[49] private __gap;
}
```

## Testing Upgrades

### Foundry Upgrade Test

```solidity
import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MyContractV1} from "../src/MyContractV1.sol";
import {MyContractV2} from "../src/MyContractV2.sol";

contract UpgradeTest is Test {
    MyContractV1 proxy;
    address owner = makeAddr("owner");

    function setUp() public {
        // Deploy V1
        MyContractV1 implementation = new MyContractV1();
        ERC1967Proxy proxyContract = new ERC1967Proxy(
            address(implementation),
            abi.encodeCall(MyContractV1.initialize, (owner))
        );
        proxy = MyContractV1(address(proxyContract));
    }

    function test_Upgrade() public {
        // Set value in V1
        proxy.setValue(42);
        assertEq(proxy.value(), 42);

        // Deploy V2
        MyContractV2 v2Implementation = new MyContractV2();

        // Upgrade
        vm.prank(owner);
        proxy.upgradeToAndCall(address(v2Implementation), "");

        // Cast to V2
        MyContractV2 proxyV2 = MyContractV2(address(proxy));

        // Value preserved
        assertEq(proxyV2.value(), 42);

        // New function works
        proxyV2.setName("test");
        assertEq(proxyV2.name(), "test");
    }

    function test_OnlyOwnerCanUpgrade() public {
        MyContractV2 v2 = new MyContractV2();

        vm.prank(makeAddr("attacker"));
        vm.expectRevert();
        proxy.upgradeToAndCall(address(v2), "");
    }
}
```

### OpenZeppelin Upgrades Plugin

For automated storage layout checks:

```bash
npm install @openzeppelin/upgrades-core
```

```javascript
// hardhat.config.js
require('@openzeppelin/hardhat-upgrades');

// scripts/deploy.js
const { ethers, upgrades } = require("hardhat");

async function main() {
  const V1 = await ethers.getContractFactory("MyContractV1");
  const proxy = await upgrades.deployProxy(V1, [owner], {
    initializer: 'initialize',
  });

  // Upgrade
  const V2 = await ethers.getContractFactory("MyContractV2");
  await upgrades.upgradeProxy(proxy.address, V2);
}
```

## Security Considerations

### 1. Initializer Protection

```solidity
/// @custom:oz-upgrades-unsafe-allow constructor
constructor() {
    _disableInitializers(); // Prevent implementation initialization
}
```

### 2. Authorization

```solidity
function _authorizeUpgrade(address) internal override onlyOwner {}

// Or with timelock
function _authorizeUpgrade(address) internal override {
    require(msg.sender == timelock, "Only timelock");
}
```

### 3. Storage Collision

Use namespaced storage (ERC-7201):

```solidity
// ERC-7201 namespaced storage
bytes32 private constant StorageLocation =
    keccak256(abi.encode(uint256(keccak256("myproject.storage.MyContract")) - 1)) & ~bytes32(uint256(0xff));

struct MyStorage {
    uint256 value;
    mapping(address => uint256) balances;
}

function _getStorage() private pure returns (MyStorage storage $) {
    bytes32 position = StorageLocation;
    assembly {
        $.slot := position
    }
}
```

### 4. Function Selector Clashes

UUPS avoids this by putting upgrade logic in implementation. For transparent proxies, the admin address cannot call implementation functions.

## Timelock for Upgrades

Add delay before upgrades take effect:

```solidity
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

// Deploy timelock with 2-day delay
address[] memory proposers = new address[](1);
proposers[0] = multisig;
address[] memory executors = new address[](1);
executors[0] = multisig;

TimelockController timelock = new TimelockController(
    2 days,    // Minimum delay
    proposers,
    executors,
    address(0) // No admin
);

// Set timelock as upgrade authority
proxy.transferOwnership(address(timelock));
```

## Common Patterns

### Pausable Upgrades

```solidity
contract MyContract is UUPSUpgradeable, PausableUpgradeable {
    function _authorizeUpgrade(address) internal override onlyOwner whenPaused {
        // Can only upgrade when paused
    }
}
```

### Two-Step Upgrade

```solidity
address public pendingImplementation;
uint256 public upgradeTimestamp;

function proposeUpgrade(address newImpl) external onlyOwner {
    pendingImplementation = newImpl;
    upgradeTimestamp = block.timestamp + 2 days;
}

function executeUpgrade() external onlyOwner {
    require(block.timestamp >= upgradeTimestamp, "Too early");
    require(pendingImplementation != address(0), "No pending upgrade");

    _upgradeToAndCallUUPS(pendingImplementation, "", false);
    pendingImplementation = address(0);
}
```

## Resources

- [OpenZeppelin Upgrades Docs](https://docs.openzeppelin.com/upgrades-plugins/1.x/)
- [ERC-1967: Proxy Storage Slots](https://eips.ethereum.org/EIPS/eip-1967)
- [ERC-7201: Namespaced Storage](https://eips.ethereum.org/EIPS/eip-7201)
- [UUPS vs Transparent](https://docs.openzeppelin.com/contracts/5.x/api/proxy#transparent-vs-uups)
