# Account Abstraction (ERC-4337)

Modern patterns for smart accounts, gasless transactions, and improved user experience.

## Overview

Account Abstraction (AA) allows smart contracts to act as user accounts, enabling:
- **Gasless transactions** - Sponsors pay gas on behalf of users
- **Batch transactions** - Multiple operations in a single transaction
- **Social recovery** - Recover accounts without seed phrases
- **Session keys** - Limited permissions for specific actions
- **Custom validation** - Multi-sig, passkeys, or any signature scheme

## Core Concepts

### User Operations (UserOps)

Instead of regular transactions, users sign "UserOperations" that bundlers submit on-chain:

```solidity
struct PackedUserOperation {
    address sender;              // Smart account address
    uint256 nonce;              // Replay protection
    bytes initCode;             // Factory + data to create account (if new)
    bytes callData;             // What to execute
    bytes32 accountGasLimits;   // Verification + call gas limits
    uint256 preVerificationGas; // Gas for bundler overhead
    bytes32 gasFees;            // Max fee + priority fee
    bytes paymasterAndData;     // Paymaster address + context
    bytes signature;            // Validation signature
}
```

### Key Components

| Component | Role |
|-----------|------|
| **Smart Account** | Contract wallet owned by user |
| **EntryPoint** | Singleton that validates and executes UserOps |
| **Bundler** | Off-chain service that submits UserOps |
| **Paymaster** | Sponsors gas for users |
| **Account Factory** | Deploys new smart accounts |

## Implementation with Permissionless.js

### Installation

```bash
npm install permissionless viem
```

### Create a Smart Account

```typescript
import { createPublicClient, http } from 'viem'
import { sepolia } from 'viem/chains'
import { createSmartAccountClient } from 'permissionless'
import { toSafeSmartAccount } from 'permissionless/accounts'
import { createPimlicoClient } from 'permissionless/clients/pimlico'

// Public client for reads
const publicClient = createPublicClient({
  chain: sepolia,
  transport: http('https://rpc.ankr.com/eth_sepolia'),
})

// Bundler client (Pimlico, Alchemy, etc.)
const pimlicoClient = createPimlicoClient({
  chain: sepolia,
  transport: http('https://api.pimlico.io/v2/sepolia/rpc?apikey=YOUR_KEY'),
})

// Create Safe smart account
const safeAccount = await toSafeSmartAccount({
  client: publicClient,
  owners: [privateKeyToAccount(privateKey)],
  version: '1.4.1',
})

// Smart account client for sending UserOps
const smartAccountClient = createSmartAccountClient({
  account: safeAccount,
  chain: sepolia,
  bundlerTransport: http('https://api.pimlico.io/v2/sepolia/rpc?apikey=YOUR_KEY'),
  paymaster: pimlicoClient,
})
```

### Send a UserOperation

```typescript
// Send a transaction through the smart account
const txHash = await smartAccountClient.sendTransaction({
  to: '0x...',
  value: parseEther('0.1'),
  data: '0x',
})

// Or call a contract
const txHash = await smartAccountClient.writeContract({
  address: contractAddress,
  abi: contractAbi,
  functionName: 'mint',
  args: [tokenId],
})
```

### Batch Transactions

```typescript
// Execute multiple operations atomically
const txHash = await smartAccountClient.sendTransactions({
  transactions: [
    {
      to: tokenAddress,
      data: encodeFunctionData({
        abi: erc20Abi,
        functionName: 'approve',
        args: [spender, amount],
      }),
    },
    {
      to: protocolAddress,
      data: encodeFunctionData({
        abi: protocolAbi,
        functionName: 'deposit',
        args: [amount],
      }),
    },
  ],
})
```

## Paymaster Integration

### Sponsored Transactions

```typescript
import { createPimlicoClient } from 'permissionless/clients/pimlico'

const pimlicoClient = createPimlicoClient({
  chain: sepolia,
  transport: http('https://api.pimlico.io/v2/sepolia/rpc?apikey=YOUR_KEY'),
})

const smartAccountClient = createSmartAccountClient({
  account: safeAccount,
  chain: sepolia,
  bundlerTransport: http('https://api.pimlico.io/v2/sepolia/rpc?apikey=YOUR_KEY'),
  paymaster: pimlicoClient, // Pimlico sponsors gas
})

// User pays nothing - paymaster covers gas
const txHash = await smartAccountClient.sendTransaction({
  to: '0x...',
  value: 0n,
  data: '0x...',
})
```

### ERC-20 Gas Payment

```typescript
// Pay gas in USDC instead of ETH
const smartAccountClient = createSmartAccountClient({
  account: safeAccount,
  chain: sepolia,
  bundlerTransport: http(bundlerUrl),
  paymasterContext: {
    token: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', // USDC
  },
})
```

## Smart Account Development

### Minimal Account Contract

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IAccount} from "@account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract SimpleAccount is IAccount {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    address public owner;
    address public immutable entryPoint;

    constructor(address _entryPoint, address _owner) {
        entryPoint = _entryPoint;
        owner = _owner;
    }

    /// @notice Validates UserOperation signature
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external returns (uint256 validationData) {
        require(msg.sender == entryPoint, "Only EntryPoint");

        // Verify signature
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        address signer = hash.recover(userOp.signature);

        if (signer != owner) {
            return 1; // SIG_VALIDATION_FAILED
        }

        // Pay prefund if needed
        if (missingAccountFunds > 0) {
            (bool success,) = payable(entryPoint).call{value: missingAccountFunds}("");
            require(success, "Prefund failed");
        }

        return 0; // Success
    }

    /// @notice Execute a call (only via EntryPoint)
    function execute(
        address dest,
        uint256 value,
        bytes calldata data
    ) external {
        require(msg.sender == entryPoint, "Only EntryPoint");
        (bool success, bytes memory result) = dest.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /// @notice Execute batch of calls
    function executeBatch(
        address[] calldata dest,
        uint256[] calldata values,
        bytes[] calldata data
    ) external {
        require(msg.sender == entryPoint, "Only EntryPoint");
        require(dest.length == values.length && values.length == data.length, "Length mismatch");

        for (uint256 i = 0; i < dest.length; i++) {
            (bool success, bytes memory result) = dest[i].call{value: values[i]}(data[i]);
            if (!success) {
                assembly {
                    revert(add(result, 32), mload(result))
                }
            }
        }
    }

    receive() external payable {}
}
```

### Account Factory

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SimpleAccount} from "./SimpleAccount.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

contract SimpleAccountFactory {
    address public immutable entryPoint;

    constructor(address _entryPoint) {
        entryPoint = _entryPoint;
    }

    /// @notice Create account at deterministic address
    function createAccount(
        address owner,
        uint256 salt
    ) external returns (SimpleAccount account) {
        address addr = getAddress(owner, salt);

        // Return existing if deployed
        if (addr.code.length > 0) {
            return SimpleAccount(payable(addr));
        }

        // Deploy new account
        account = new SimpleAccount{salt: bytes32(salt)}(entryPoint, owner);
    }

    /// @notice Get counterfactual address
    function getAddress(
        address owner,
        uint256 salt
    ) public view returns (address) {
        return Create2.computeAddress(
            bytes32(salt),
            keccak256(abi.encodePacked(
                type(SimpleAccount).creationCode,
                abi.encode(entryPoint, owner)
            ))
        );
    }
}
```

## Session Keys

Session keys allow temporary, limited permissions:

```solidity
struct SessionKey {
    address key;           // Temporary signer
    uint48 validAfter;     // Start time
    uint48 validUntil;     // Expiry time
    address[] allowedTargets; // Contracts it can call
}

mapping(bytes32 => SessionKey) public sessionKeys;

function validateUserOp(
    PackedUserOperation calldata userOp,
    bytes32 userOpHash,
    uint256 missingAccountFunds
) external returns (uint256 validationData) {
    // Decode signature to get session key ID
    (bytes32 sessionId, bytes memory sig) = abi.decode(
        userOp.signature,
        (bytes32, bytes)
    );

    SessionKey storage session = sessionKeys[sessionId];

    // Verify session key signed
    bytes32 hash = userOpHash.toEthSignedMessageHash();
    address signer = hash.recover(sig);
    require(signer == session.key, "Invalid session key");

    // Check target is allowed
    address target = address(bytes20(userOp.callData[16:36]));
    bool allowed = false;
    for (uint i = 0; i < session.allowedTargets.length; i++) {
        if (session.allowedTargets[i] == target) {
            allowed = true;
            break;
        }
    }
    require(allowed, "Target not allowed");

    // Return validation data with time range
    return _packValidationData(false, session.validUntil, session.validAfter);
}
```

## React Integration

### useSmartAccount Hook

```tsx
import { useEffect, useState } from 'react'
import { createSmartAccountClient } from 'permissionless'
import { toSafeSmartAccount } from 'permissionless/accounts'
import { useWalletClient, usePublicClient } from 'wagmi'

export function useSmartAccount() {
  const { data: walletClient } = useWalletClient()
  const publicClient = usePublicClient()
  const [smartAccount, setSmartAccount] = useState(null)
  const [isLoading, setIsLoading] = useState(false)

  useEffect(() => {
    async function initAccount() {
      if (!walletClient || !publicClient) return

      setIsLoading(true)
      try {
        const safeAccount = await toSafeSmartAccount({
          client: publicClient,
          owners: [walletClient],
          version: '1.4.1',
        })

        const client = createSmartAccountClient({
          account: safeAccount,
          chain: publicClient.chain,
          bundlerTransport: http(process.env.BUNDLER_URL),
        })

        setSmartAccount(client)
      } finally {
        setIsLoading(false)
      }
    }

    initAccount()
  }, [walletClient, publicClient])

  return { smartAccount, isLoading }
}
```

### Gasless Transaction Component

```tsx
function GaslessTransfer() {
  const { smartAccount, isLoading } = useSmartAccount()
  const [isPending, setIsPending] = useState(false)

  async function handleTransfer() {
    if (!smartAccount) return

    setIsPending(true)
    try {
      const hash = await smartAccount.sendTransaction({
        to: recipientAddress,
        value: parseEther('0.01'),
      })

      // Wait for confirmation
      const receipt = await publicClient.waitForTransactionReceipt({ hash })
      console.log('Gasless transfer complete:', receipt.transactionHash)
    } catch (error) {
      console.error('Transfer failed:', error)
    } finally {
      setIsPending(false)
    }
  }

  return (
    <button onClick={handleTransfer} disabled={isLoading || isPending}>
      {isPending ? 'Sending...' : 'Send (Gasless)'}
    </button>
  )
}
```

## EntryPoint Addresses

| Network | EntryPoint v0.7 |
|---------|-----------------|
| Ethereum Mainnet | `0x0000000071727De22E5E9d8BAf0edAc6f37da032` |
| Sepolia | `0x0000000071727De22E5E9d8BAf0edAc6f37da032` |
| Base | `0x0000000071727De22E5E9d8BAf0edAc6f37da032` |
| Arbitrum | `0x0000000071727De22E5E9d8BAf0edAc6f37da032` |
| Optimism | `0x0000000071727De22E5E9d8BAf0edAc6f37da032` |

## Bundler Providers

| Provider | URL |
|----------|-----|
| Pimlico | https://pimlico.io |
| Alchemy | https://www.alchemy.com/account-abstraction |
| Stackup | https://stackup.sh |
| Biconomy | https://biconomy.io |

## Testing

### Fork Test with Bundler Mock

```solidity
import {Test} from "forge-std/Test.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";

contract AccountTest is Test {
    IEntryPoint entryPoint;
    SimpleAccountFactory factory;
    SimpleAccount account;

    address owner = makeAddr("owner");
    uint256 ownerKey = 0x1234;

    function setUp() public {
        // Fork mainnet to get real EntryPoint
        vm.createSelectFork("mainnet");
        entryPoint = IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032);

        // Deploy factory and account
        factory = new SimpleAccountFactory(address(entryPoint));
        account = factory.createAccount(owner, 0);

        // Fund the account
        vm.deal(address(account), 10 ether);
    }

    function test_ExecuteViaEntryPoint() public {
        // Build UserOp
        PackedUserOperation memory userOp = _buildUserOp(
            address(account),
            abi.encodeCall(
                SimpleAccount.execute,
                (address(0xdead), 1 ether, "")
            )
        );

        // Sign it
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, userOpHash.toEthSignedMessageHash());
        userOp.signature = abi.encodePacked(r, s, v);

        // Execute via EntryPoint
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;

        entryPoint.handleOps(ops, payable(address(this)));

        assertEq(address(0xdead).balance, 1 ether);
    }
}
```

## Resources

- [ERC-4337 Specification](https://eips.ethereum.org/EIPS/eip-4337)
- [Permissionless.js Docs](https://docs.pimlico.io/permissionless)
- [Safe Smart Account](https://docs.safe.global)
- [eth-infinitism Reference](https://github.com/eth-infinitism/account-abstraction)
