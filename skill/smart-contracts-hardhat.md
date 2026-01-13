# Smart Contract Development with Hardhat

Hardhat is a JavaScript/TypeScript-based Ethereum development environment with extensive plugin ecosystem.

## When to Use Hardhat

- Team is more comfortable with JavaScript/TypeScript
- Need extensive plugin ecosystem
- Complex deployment scripts with JavaScript logic
- Integration with web frontend workflows
- Using Hardhat Ignition for deployments

## Installation

```bash
# Create new project
mkdir my-project && cd my-project
npm init -y

# Install Hardhat
npm install --save-dev hardhat

# Initialize project
npx hardhat init
# Choose "Create a TypeScript project"

# Install common dependencies
npm install --save-dev \
  @nomicfoundation/hardhat-toolbox \
  @openzeppelin/contracts \
  dotenv
```

## Project Structure

```
my-project/
├── contracts/          # Solidity contracts
├── ignition/
│   └── modules/        # Deployment modules
├── test/               # Test files
├── scripts/            # Utility scripts
├── hardhat.config.ts   # Configuration
├── .env                # Environment variables (don't commit)
└── package.json
```

## Configuration

### hardhat.config.ts

```typescript
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {
      // Local development network
    },
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL || "",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    mainnet: {
      url: process.env.MAINNET_RPC_URL || "",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS === "true",
    currency: "USD",
  },
};

export default config;
```

### .env File

```bash
PRIVATE_KEY=0x...
MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
ETHERSCAN_API_KEY=YOUR_KEY
REPORT_GAS=true
```

## Writing Contracts

Contracts are identical to Foundry. Place them in `contracts/`:

```solidity
// contracts/MyContract.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MyContract is Ownable {
    uint256 public value;

    event ValueChanged(uint256 oldValue, uint256 newValue);

    constructor(uint256 _initialValue) Ownable(msg.sender) {
        value = _initialValue;
    }

    function setValue(uint256 _value) external onlyOwner {
        uint256 oldValue = value;
        value = _value;
        emit ValueChanged(oldValue, _value);
    }
}
```

## Building

```bash
# Compile contracts
npx hardhat compile

# Clean artifacts
npx hardhat clean

# Check contract sizes
npx hardhat compile --force
```

## Testing with Hardhat

### Basic Test Structure

```typescript
// test/MyContract.test.ts
import { expect } from "chai";
import { ethers } from "hardhat";
import { MyContract } from "../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

describe("MyContract", function () {
  let myContract: MyContract;
  let owner: SignerWithAddress;
  let otherAccount: SignerWithAddress;

  beforeEach(async function () {
    [owner, otherAccount] = await ethers.getSigners();

    const MyContractFactory = await ethers.getContractFactory("MyContract");
    myContract = await MyContractFactory.deploy(100);
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await myContract.owner()).to.equal(owner.address);
    });

    it("Should set the initial value", async function () {
      expect(await myContract.value()).to.equal(100);
    });
  });

  describe("setValue", function () {
    it("Should update the value", async function () {
      await myContract.setValue(200);
      expect(await myContract.value()).to.equal(200);
    });

    it("Should emit ValueChanged event", async function () {
      await expect(myContract.setValue(200))
        .to.emit(myContract, "ValueChanged")
        .withArgs(100, 200);
    });

    it("Should revert if called by non-owner", async function () {
      await expect(
        myContract.connect(otherAccount).setValue(200)
      ).to.be.revertedWithCustomError(myContract, "OwnableUnauthorizedAccount");
    });
  });
});
```

### Testing with Fixtures

```typescript
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";

describe("MyContract", function () {
  async function deployFixture() {
    const [owner, otherAccount] = await ethers.getSigners();
    const MyContract = await ethers.getContractFactory("MyContract");
    const myContract = await MyContract.deploy(100);
    return { myContract, owner, otherAccount };
  }

  it("Should work with fixture", async function () {
    const { myContract, owner } = await loadFixture(deployFixture);
    expect(await myContract.owner()).to.equal(owner.address);
  });
});
```

### Time Manipulation

```typescript
import { time } from "@nomicfoundation/hardhat-toolbox/network-helpers";

it("Should handle time-based logic", async function () {
  // Increase time by 1 day
  await time.increase(24 * 60 * 60);

  // Set to specific timestamp
  await time.increaseTo(1893456000);

  // Get current block timestamp
  const timestamp = await time.latest();
});
```

### Impersonation

```typescript
import { impersonateAccount, setBalance } from "@nomicfoundation/hardhat-network-helpers";

it("Should impersonate account", async function () {
  const whaleAddress = "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045";

  // Impersonate account
  await impersonateAccount(whaleAddress);

  // Give them ETH for gas
  await setBalance(whaleAddress, ethers.parseEther("10"));

  // Get signer
  const whaleSigner = await ethers.getSigner(whaleAddress);

  // Use impersonated signer
  await token.connect(whaleSigner).transfer(recipient, amount);
});
```

### Fork Testing

```typescript
// hardhat.config.ts
networks: {
  hardhat: {
    forking: {
      url: process.env.MAINNET_RPC_URL!,
      blockNumber: 18000000, // Optional: pin to block
    },
  },
},
```

```typescript
it("Should interact with mainnet contracts", async function () {
  const USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
  const usdc = await ethers.getContractAt("IERC20", USDC_ADDRESS);

  const balance = await usdc.balanceOf(someAddress);
  expect(balance).to.be.gt(0);
});
```

### Running Tests

```bash
# Run all tests
npx hardhat test

# Run specific test file
npx hardhat test test/MyContract.test.ts

# Run with gas reporting
REPORT_GAS=true npx hardhat test

# Run with coverage
npx hardhat coverage
```

## Deployment with Ignition

Hardhat Ignition is the recommended deployment system (replaces scripts).

### Basic Deployment Module

```typescript
// ignition/modules/MyContract.ts
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const MyContractModule = buildModule("MyContractModule", (m) => {
  const initialValue = m.getParameter("initialValue", 100n);

  const myContract = m.contract("MyContract", [initialValue]);

  return { myContract };
});

export default MyContractModule;
```

### Deployment with Dependencies

```typescript
// ignition/modules/TokenAndVault.ts
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const TokenAndVaultModule = buildModule("TokenAndVaultModule", (m) => {
  // Deploy token first
  const token = m.contract("MyToken", ["MyToken", "MTK"]);

  // Deploy vault with token address
  const vault = m.contract("Vault", [token]);

  // Call function after deployment
  m.call(token, "mint", [m.getAccount(0), 1_000_000n * 10n ** 18n]);

  return { token, vault };
});

export default TokenAndVaultModule;
```

### Running Deployments

```bash
# Deploy to local network
npx hardhat ignition deploy ignition/modules/MyContract.ts

# Deploy to testnet
npx hardhat ignition deploy ignition/modules/MyContract.ts \
  --network sepolia \
  --verify

# With parameters
npx hardhat ignition deploy ignition/modules/MyContract.ts \
  --network sepolia \
  --parameters '{"initialValue": 500}'

# Resume failed deployment
npx hardhat ignition deploy ignition/modules/MyContract.ts \
  --network sepolia \
  --deployment-id my-deployment
```

## Legacy Script Deployment

For complex deployment logic, you can still use scripts:

```typescript
// scripts/deploy.ts
import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with:", deployer.address);

  const MyContract = await ethers.getContractFactory("MyContract");
  const myContract = await MyContract.deploy(100);
  await myContract.waitForDeployment();

  console.log("MyContract deployed to:", await myContract.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
```

```bash
npx hardhat run scripts/deploy.ts --network sepolia
```

## Verification

```bash
# Verify with Ignition (automatic with --verify flag)
npx hardhat ignition deploy ignition/modules/MyContract.ts --network sepolia --verify

# Manual verification
npx hardhat verify --network sepolia $CONTRACT_ADDRESS 100
# (100 is the constructor argument)

# Verify with complex constructor args
npx hardhat verify --network sepolia $CONTRACT_ADDRESS \
  --constructor-args scripts/arguments.ts
```

```typescript
// scripts/arguments.ts
module.exports = [
  "MyToken",
  "MTK",
  "0x1234567890123456789012345678901234567890",
  1000000n,
];
```

## Hardhat Network

### Local Node

```bash
# Start local node
npx hardhat node

# Start with fork
npx hardhat node --fork $MAINNET_RPC_URL
```

### Console

```bash
# Interactive console
npx hardhat console --network localhost

# In console:
const MyContract = await ethers.getContractFactory("MyContract")
const contract = await MyContract.deploy(100)
await contract.value()
```

## Common Tasks

### Custom Tasks

```typescript
// hardhat.config.ts
import { task } from "hardhat/config";

task("balance", "Prints an account's balance")
  .addParam("account", "The account's address")
  .setAction(async (taskArgs, hre) => {
    const balance = await hre.ethers.provider.getBalance(taskArgs.account);
    console.log(hre.ethers.formatEther(balance), "ETH");
  });
```

```bash
npx hardhat balance --account 0x123...
```

## TypeChain Integration

TypeChain generates TypeScript types for your contracts automatically with `@nomicfoundation/hardhat-toolbox`.

```typescript
// Types are auto-generated in typechain-types/
import { MyContract } from "../typechain-types";

// Full type safety
const contract: MyContract = await MyContract.deploy(100);
const value: bigint = await contract.value();
```

## Gas Reporting

```bash
# Enable in .env
REPORT_GAS=true

# Run tests
npx hardhat test
```

Output shows gas used per function and deployment costs.

## Comparison: Hardhat vs Foundry

| Feature | Hardhat | Foundry |
|---------|---------|---------|
| Language | JavaScript/TypeScript | Rust CLI, Solidity tests |
| Speed | Slower | 2-5x faster |
| Test Language | JS/TS | Solidity |
| Fuzzing | Plugin required | Built-in |
| Plugins | Extensive ecosystem | Growing |
| Learning Curve | Easier for JS devs | Steeper |

## Migration to Foundry

If starting with Hardhat but want Foundry testing:

```bash
npm install --save-dev @nomicfoundation/hardhat-foundry
```

```typescript
// hardhat.config.ts
import "@nomicfoundation/hardhat-foundry";
```

Now you can use both:
- `npx hardhat test` for JS tests
- `forge test` for Solidity tests
