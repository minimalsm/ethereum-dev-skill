# Smart Contract Development with Foundry

Foundry is a fast, portable, and modular toolkit for Ethereum development written in Rust.

## Installation

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Verify installation
forge --version
cast --version
anvil --version
```

## Project Setup

### New Project

```bash
# Create new project
forge init my-project
cd my-project

# Project structure
# ├── src/           # Contract source files
# ├── test/          # Test files
# ├── script/        # Deployment scripts
# ├── lib/           # Dependencies (git submodules)
# └── foundry.toml   # Configuration
```

### Install Dependencies

```bash
# OpenZeppelin contracts (recommended)
forge install OpenZeppelin/openzeppelin-contracts

# Other common dependencies
forge install transmissions11/solmate
forge install vectorized/solady

# Update remappings
forge remappings > remappings.txt
```

### foundry.toml Configuration

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc = "0.8.20"
optimizer = true
optimizer_runs = 200
via_ir = false

# Remappings
remappings = [
    "@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/",
    "solmate/=lib/solmate/src/",
]

# Testing
[fuzz]
runs = 1000
max_test_rejects = 65536

[invariant]
runs = 256
depth = 128
fail_on_revert = false

# RPC endpoints (use environment variables)
[rpc_endpoints]
mainnet = "${MAINNET_RPC_URL}"
sepolia = "${SEPOLIA_RPC_URL}"

# Etherscan verification
[etherscan]
mainnet = { key = "${ETHERSCAN_API_KEY}" }
sepolia = { key = "${ETHERSCAN_API_KEY}" }
```

## Writing Contracts

### Basic Contract Structure

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title MyContract
/// @notice Brief description of what the contract does
/// @dev Implementation details for developers
contract MyContract is Ownable, ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error InsufficientBalance();
    error InvalidAddress();
    error Unauthorized();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    mapping(address => uint256) public balances;
    uint256 public totalDeposits;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() Ownable(msg.sender) {}

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit ETH into the contract
    function deposit() external payable {
        if (msg.value == 0) revert InsufficientBalance();

        balances[msg.sender] += msg.value;
        totalDeposits += msg.value;

        emit Deposited(msg.sender, msg.value);
    }

    /// @notice Withdraw ETH from the contract
    /// @param amount The amount to withdraw
    function withdraw(uint256 amount) external nonReentrant {
        if (balances[msg.sender] < amount) revert InsufficientBalance();

        // Effects before interactions (CEI pattern)
        balances[msg.sender] -= amount;
        totalDeposits -= amount;

        // Interaction
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit Withdrawn(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get balance for an account
    /// @param account The account to check
    /// @return The balance
    function getBalance(address account) external view returns (uint256) {
        return balances[account];
    }
}
```

### ERC-20 Token

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC20, ERC20Permit, Ownable {
    constructor() ERC20("MyToken", "MTK") ERC20Permit("MyToken") Ownable(msg.sender) {
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
```

### ERC-721 NFT

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MyNFT is ERC721, ERC721URIStorage, Ownable {
    uint256 private _nextTokenId;

    constructor() ERC721("MyNFT", "MNFT") Ownable(msg.sender) {}

    function safeMint(address to, string memory uri) external onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        return tokenId;
    }

    // Required overrides
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
```

## Building and Compiling

```bash
# Build all contracts
forge build

# Build with specific solc version
forge build --use 0.8.20

# Build with optimizer
forge build --optimizer-runs 200

# Clean build artifacts
forge clean

# Check contract sizes
forge build --sizes
```

## Deployment Scripts

### Basic Deployment Script

```solidity
// script/Deploy.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MyContract} from "../src/MyContract.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        // Load private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        MyContract myContract = new MyContract();
        console.log("MyContract deployed to:", address(myContract));

        vm.stopBroadcast();
    }
}
```

### Deployment with Constructor Arguments

```solidity
// script/DeployToken.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MyToken} from "../src/MyToken.sol";

contract DeployTokenScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address initialOwner = vm.envAddress("INITIAL_OWNER");
        uint256 initialSupply = vm.envUint("INITIAL_SUPPLY");

        vm.startBroadcast(deployerPrivateKey);

        MyToken token = new MyToken(initialOwner, initialSupply);
        console.log("Token deployed to:", address(token));
        console.log("Initial supply:", initialSupply);

        vm.stopBroadcast();
    }
}
```

### Running Deployment Scripts

```bash
# Dry run (simulation)
forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL

# Deploy to testnet
forge script script/Deploy.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify

# Deploy to mainnet
forge script script/Deploy.s.sol \
  --rpc-url $MAINNET_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY

# Resume failed deployment
forge script script/Deploy.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --resume
```

## Local Development with Anvil

Anvil is Foundry's local Ethereum node.

### Starting Anvil

```bash
# Basic start (default: 10 accounts, 10000 ETH each)
anvil

# Custom configuration
anvil \
  --accounts 5 \
  --balance 1000 \
  --port 8545 \
  --chain-id 31337 \
  --block-time 1

# Fork mainnet
anvil --fork-url $MAINNET_RPC_URL

# Fork at specific block
anvil --fork-url $MAINNET_RPC_URL --fork-block-number 18000000
```

### Deploy to Anvil

```bash
# Start anvil in one terminal
anvil

# Deploy in another terminal
forge script script/Deploy.s.sol \
  --rpc-url http://localhost:8545 \
  --broadcast \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

## Cast CLI

Cast is a command-line tool for interacting with Ethereum.

### Read Operations

```bash
# Get ETH balance
cast balance 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045 --rpc-url $MAINNET_RPC_URL

# Call view function
cast call $CONTRACT_ADDRESS "balanceOf(address)" $USER_ADDRESS --rpc-url $MAINNET_RPC_URL

# Decode return data
cast call $CONTRACT_ADDRESS "name()" --rpc-url $MAINNET_RPC_URL | cast --to-ascii

# Get storage slot
cast storage $CONTRACT_ADDRESS 0 --rpc-url $MAINNET_RPC_URL
```

### Write Operations

```bash
# Send ETH
cast send $TO_ADDRESS --value 1ether --private-key $PRIVATE_KEY --rpc-url $RPC_URL

# Call function
cast send $CONTRACT_ADDRESS "transfer(address,uint256)" $TO_ADDRESS 1000000 \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL

# With gas settings
cast send $CONTRACT_ADDRESS "mint(uint256)" 1 \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --gas-limit 100000 \
  --gas-price 20gwei
```

### Utility Commands

```bash
# Convert units
cast --to-wei 1 ether        # 1000000000000000000
cast --from-wei 1000000000000000000  # 1.0

# Encode function call
cast calldata "transfer(address,uint256)" 0x123... 1000000

# Decode function call
cast 4byte-decode 0xa9059cbb000000...

# Get function selector
cast sig "transfer(address,uint256)"  # 0xa9059cbb

# Keccak hash
cast keccak "Transfer(address,address,uint256)"

# ABI encode
cast abi-encode "constructor(address,uint256)" 0x123... 1000

# Get block info
cast block latest --rpc-url $MAINNET_RPC_URL

# Get transaction
cast tx $TX_HASH --rpc-url $MAINNET_RPC_URL

# Get receipt
cast receipt $TX_HASH --rpc-url $MAINNET_RPC_URL
```

## Contract Verification

```bash
# Verify on Etherscan
forge verify-contract \
  $CONTRACT_ADDRESS \
  src/MyContract.sol:MyContract \
  --chain sepolia \
  --etherscan-api-key $ETHERSCAN_API_KEY

# With constructor arguments
forge verify-contract \
  $CONTRACT_ADDRESS \
  src/MyToken.sol:MyToken \
  --chain sepolia \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --constructor-args $(cast abi-encode "constructor(address,uint256)" 0x123... 1000000)

# Check verification status
forge verify-check $GUID --chain sepolia
```

## Gas Optimization

### Gas Snapshots

```bash
# Create gas snapshot
forge snapshot

# Compare with previous snapshot
forge snapshot --diff

# Check specific test
forge snapshot --match-test testTransfer
```

### Gas Reports

```bash
# Run tests with gas report
forge test --gas-report

# Detailed gas report
forge test --gas-report -vvv
```

## Common Patterns

### Proxy Pattern (UUPS)

```solidity
// Implementation
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MyContractV1 is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    uint256 public value;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }

    function setValue(uint256 _value) external {
        value = _value;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
```

### Factory Pattern

```solidity
contract TokenFactory {
    event TokenCreated(address indexed token, address indexed owner);

    function createToken(string memory name, string memory symbol) external returns (address) {
        MyToken token = new MyToken(name, symbol, msg.sender);
        emit TokenCreated(address(token), msg.sender);
        return address(token);
    }
}
```

## Environment Setup

### .env File

```bash
# .env (never commit this file!)
PRIVATE_KEY=0x...
MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
ETHERSCAN_API_KEY=YOUR_KEY
```

### Load Environment Variables

```bash
# Load .env file
source .env

# Or use direnv (recommended)
# .envrc
dotenv
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Stack too deep" | Use `via_ir = true` in foundry.toml or reduce local variables |
| "Contract size exceeds limit" | Enable optimizer, split contracts, use libraries |
| "Compiler version mismatch" | Check `pragma solidity` matches foundry.toml `solc` |
| "Import not found" | Run `forge remappings` and check remappings.txt |
| "Verification failed" | Ensure exact same compiler settings, check constructor args |
