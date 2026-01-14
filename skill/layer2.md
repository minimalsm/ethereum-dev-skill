# Layer 2 Development

Patterns and considerations for deploying to Optimistic and ZK rollups.

## Overview

Layer 2 networks offer lower gas costs and higher throughput while inheriting Ethereum's security. Key differences to consider:

| Aspect | L1 (Mainnet) | L2 (Rollups) |
|--------|--------------|--------------|
| Gas costs | $5-100+ per tx | $0.01-1 per tx |
| Finality | ~12 minutes | Seconds (soft), days (hard) |
| Block time | 12 seconds | 2 seconds (varies) |
| Sequencer | Decentralized | Centralized (most L2s) |
| Native token | ETH | ETH (bridged) |

## Supported Networks

### Optimistic Rollups

| Network | Chain ID | RPC | Explorer |
|---------|----------|-----|----------|
| Optimism | 10 | https://mainnet.optimism.io | https://optimistic.etherscan.io |
| Base | 8453 | https://mainnet.base.org | https://basescan.org |
| Arbitrum One | 42161 | https://arb1.arbitrum.io/rpc | https://arbiscan.io |

### ZK Rollups

| Network | Chain ID | RPC | Explorer |
|---------|----------|-----|----------|
| zkSync Era | 324 | https://mainnet.era.zksync.io | https://explorer.zksync.io |
| Polygon zkEVM | 1101 | https://zkevm-rpc.com | https://zkevm.polygonscan.com |
| Linea | 59144 | https://rpc.linea.build | https://lineascan.build |

## Foundry Configuration

### Multi-Network Setup

```toml
# foundry.toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc = "0.8.20"

[rpc_endpoints]
mainnet = "${MAINNET_RPC_URL}"
optimism = "${OPTIMISM_RPC_URL}"
base = "${BASE_RPC_URL}"
arbitrum = "${ARBITRUM_RPC_URL}"
sepolia = "${SEPOLIA_RPC_URL}"
base_sepolia = "${BASE_SEPOLIA_RPC_URL}"

[etherscan]
mainnet = { key = "${ETHERSCAN_API_KEY}" }
optimism = { key = "${OPTIMISM_ETHERSCAN_API_KEY}", url = "https://api-optimistic.etherscan.io/api" }
base = { key = "${BASESCAN_API_KEY}", url = "https://api.basescan.org/api" }
arbitrum = { key = "${ARBISCAN_API_KEY}", url = "https://api.arbiscan.io/api" }
```

### Environment Variables

```bash
# .env
MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY
OPTIMISM_RPC_URL=https://opt-mainnet.g.alchemy.com/v2/YOUR_KEY
BASE_RPC_URL=https://base-mainnet.g.alchemy.com/v2/YOUR_KEY
ARBITRUM_RPC_URL=https://arb-mainnet.g.alchemy.com/v2/YOUR_KEY

ETHERSCAN_API_KEY=your_key
OPTIMISM_ETHERSCAN_API_KEY=your_key
BASESCAN_API_KEY=your_key
ARBISCAN_API_KEY=your_key
```

## Deployment

### Deploy Script

```solidity
// script/Deploy.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MyContract} from "../src/MyContract.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        MyContract myContract = new MyContract();
        console.log("Deployed to:", address(myContract));

        vm.stopBroadcast();
    }
}
```

### Deploy Commands

```bash
# Deploy to Base
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url base \
  --broadcast \
  --verify

# Deploy to Optimism
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url optimism \
  --broadcast \
  --verify

# Deploy to Arbitrum
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url arbitrum \
  --broadcast \
  --verify
```

## L2-Specific Considerations

### Gas Price Differences

L2s have different gas models. Always check current gas:

```typescript
import { createPublicClient, http } from 'viem'
import { base, optimism, arbitrum } from 'viem/chains'

async function getL2GasPrice(chain) {
  const client = createPublicClient({
    chain,
    transport: http(),
  })

  const gasPrice = await client.getGasPrice()
  console.log(`${chain.name} gas price: ${formatGwei(gasPrice)} gwei`)
}

// Compare across L2s
await Promise.all([
  getL2GasPrice(base),
  getL2GasPrice(optimism),
  getL2GasPrice(arbitrum),
])
```

### L1 Data Costs (Optimistic Rollups)

On Optimism/Base, you pay for L1 data submission. The total cost is:

```
Total Fee = L2 Execution Fee + L1 Data Fee
```

Check L1 data fee in contracts:

```solidity
// Optimism/Base specific
interface IL1Block {
    function baseFee() external view returns (uint256);
    function blobBaseFee() external view returns (uint256);
}

// Address on OP Stack chains
IL1Block constant L1_BLOCK = IL1Block(0x4200000000000000000000000000000000000015);
```

### Sequencer Uptime

Check if sequencer is up before relying on recent data:

```solidity
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// Sequencer uptime feed (Arbitrum example)
AggregatorV3Interface constant SEQUENCER_FEED =
    AggregatorV3Interface(0xFdB631F5EE196F0ed6FAa767959853A9F217697D);

function checkSequencer() internal view {
    (, int256 answer, uint256 startedAt,,) = SEQUENCER_FEED.latestRoundData();

    // Answer: 0 = up, 1 = down
    bool isSequencerUp = answer == 0;
    require(isSequencerUp, "Sequencer is down");

    // Don't trust data right after sequencer comes back up
    uint256 timeSinceUp = block.timestamp - startedAt;
    require(timeSinceUp > 1 hours, "Grace period not over");
}
```

### Block Timestamps

L2 block times differ from L1:

| Network | Block Time |
|---------|------------|
| Ethereum | ~12 seconds |
| Optimism | 2 seconds |
| Base | 2 seconds |
| Arbitrum | ~0.25 seconds |

Adjust time-based logic accordingly:

```solidity
// BAD - Assumes 12 second blocks
uint256 blocksPerDay = 7200;

// GOOD - Use timestamps
uint256 constant ONE_DAY = 1 days;
require(block.timestamp >= lastAction + ONE_DAY, "Too soon");
```

## Cross-Chain Messaging

### L1 → L2 (Optimism/Base)

```solidity
// On L1: Send message to L2
import {ICrossDomainMessenger} from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";

contract L1Contract {
    ICrossDomainMessenger public messenger =
        ICrossDomainMessenger(0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1); // Optimism

    function sendToL2(address l2Target, bytes calldata message) external {
        messenger.sendMessage(
            l2Target,
            message,
            1000000 // gas limit for L2 execution
        );
    }
}

// On L2: Receive message
contract L2Contract {
    address public l1Contract;
    address constant MESSENGER = 0x4200000000000000000000000000000000000007;

    modifier onlyL1Contract() {
        require(
            msg.sender == MESSENGER &&
            ICrossDomainMessenger(MESSENGER).xDomainMessageSender() == l1Contract,
            "Only L1 contract"
        );
        _;
    }

    function receiveFromL1(uint256 data) external onlyL1Contract {
        // Process message from L1
    }
}
```

### L2 → L1 (Requires Waiting Period)

```typescript
// Optimism SDK for withdrawals
import { CrossChainMessenger, MessageStatus } from '@eth-optimism/sdk'

const messenger = new CrossChainMessenger({
  l1ChainId: 1,
  l2ChainId: 10,
  l1SignerOrProvider: l1Signer,
  l2SignerOrProvider: l2Signer,
})

// Initiate withdrawal on L2
const tx = await messenger.withdrawETH(parseEther('1'))
await tx.wait()

// Wait for state root to be published (~1 hour)
await messenger.waitForMessageStatus(tx.hash, MessageStatus.READY_TO_PROVE)

// Prove the withdrawal
await messenger.proveMessage(tx.hash)

// Wait challenge period (~7 days on mainnet)
await messenger.waitForMessageStatus(tx.hash, MessageStatus.READY_FOR_RELAY)

// Finalize on L1
await messenger.finalizeMessage(tx.hash)
```

## Frontend Multi-Chain

### Viem Multi-Chain Setup

```typescript
import { createPublicClient, http } from 'viem'
import { mainnet, optimism, base, arbitrum } from 'viem/chains'

// Create clients for each chain
const clients = {
  mainnet: createPublicClient({ chain: mainnet, transport: http() }),
  optimism: createPublicClient({ chain: optimism, transport: http() }),
  base: createPublicClient({ chain: base, transport: http() }),
  arbitrum: createPublicClient({ chain: arbitrum, transport: http() }),
}

// Read from multiple chains in parallel
async function getBalancesAllChains(address: `0x${string}`) {
  const results = await Promise.all(
    Object.entries(clients).map(async ([name, client]) => ({
      chain: name,
      balance: await client.getBalance({ address }),
    }))
  )
  return results
}
```

### Wagmi Multi-Chain Config

```typescript
import { createConfig, http } from 'wagmi'
import { mainnet, optimism, base, arbitrum } from 'wagmi/chains'

export const config = createConfig({
  chains: [mainnet, optimism, base, arbitrum],
  transports: {
    [mainnet.id]: http(),
    [optimism.id]: http(),
    [base.id]: http(),
    [arbitrum.id]: http(),
  },
})
```

### Chain-Specific Contract Addresses

```typescript
const CONTRACT_ADDRESSES = {
  [mainnet.id]: '0x...',
  [optimism.id]: '0x...',
  [base.id]: '0x...',
  [arbitrum.id]: '0x...',
} as const

function useContract() {
  const chainId = useChainId()
  const address = CONTRACT_ADDRESSES[chainId]

  return useReadContract({
    address,
    abi: contractAbi,
    functionName: 'getValue',
  })
}
```

## Fork Testing L2s

```solidity
contract L2ForkTest is Test {
    function setUp() public {
        // Fork Base mainnet
        vm.createSelectFork("base");
    }

    function test_InteractWithUniswap() public {
        // Use real Uniswap deployment on Base
        address uniswapRouter = 0x2626664c2603336E57B271c5C0b26F421741e481;
        // Test with actual mainnet state...
    }
}

contract MultiChainTest is Test {
    uint256 mainnetFork;
    uint256 baseFork;

    function setUp() public {
        mainnetFork = vm.createFork("mainnet");
        baseFork = vm.createFork("base");
    }

    function test_CrossChainScenario() public {
        // Test on mainnet
        vm.selectFork(mainnetFork);
        // ... mainnet operations

        // Switch to Base
        vm.selectFork(baseFork);
        // ... Base operations
    }
}
```

## Common L2 Addresses

### OP Stack (Optimism, Base)

```
L2CrossDomainMessenger: 0x4200000000000000000000000000000000000007
L2StandardBridge:       0x4200000000000000000000000000000000000010
L1Block:                0x4200000000000000000000000000000000000015
GasPriceOracle:         0x420000000000000000000000000000000000000F
```

### Arbitrum

```
ArbSys:                 0x0000000000000000000000000000000000000064
NodeInterface:          0x00000000000000000000000000000000000000C8
ArbRetryableTx:         0x000000000000000000000000000000000000006E
```

## Best Practices

1. **Test on L2 testnets first** - Base Sepolia, OP Sepolia, Arbitrum Sepolia
2. **Account for L1 data costs** - Calldata is still expensive on optimistic rollups
3. **Don't rely on block numbers** - Use timestamps for time-based logic
4. **Check sequencer status** - For time-sensitive operations on Arbitrum
5. **Consider withdrawal delays** - 7 days for optimistic rollups, faster for ZK
6. **Use chain-specific oracles** - Chainlink has separate feeds per network
7. **Monitor gas across chains** - Prices vary significantly

## Resources

- [Optimism Docs](https://docs.optimism.io)
- [Base Docs](https://docs.base.org)
- [Arbitrum Docs](https://docs.arbitrum.io)
- [zkSync Docs](https://docs.zksync.io)
- [L2Beat](https://l2beat.com) - L2 comparison and risk analysis
