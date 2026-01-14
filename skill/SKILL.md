---
name: ethereum-dev
description: Comprehensive Ethereum development guidance for viem, wagmi, Foundry, and Solidity. Use for any Ethereum smart contract, dApp, or Web3 frontend development.
version: 1.0.0
---

# Ethereum Development Skill (viem-first)

End-to-end playbook for modern Ethereum development as of 2025. This skill provides guidance for building production-ready dApps and smart contracts.

## When to Use This Skill

- Building React/Next.js frontends that interact with Ethereum
- Writing Solidity smart contracts
- Testing contracts with Foundry or Hardhat
- Deploying to mainnet, testnets, or L2 networks
- Security review of smart contract code
- Integrating payment flows with ERC-20 tokens
- Implementing account abstraction (ERC-4337)
- Building upgradeable contracts with proxies
- Deploying to Layer 2 networks (Base, Optimism, Arbitrum)

## Core Stack Preferences

**Frontend:** Use viem 2.x for all new client/RPC/transaction code. Prefer viem over ethers.js for new projects due to better TypeScript support, smaller bundle size, and modern API design.

**React:** Pair viem with wagmi 2.x for React applications. Always use TanStack Query (comes with wagmi).

**Smart Contracts:** Default to Foundry for new projects. Use Hardhat when JavaScript/TypeScript tooling integration is critical or team prefers JS-based testing.

**Security:** Always use OpenZeppelin 5.0 contracts as base. Never roll your own access control or token implementations.

## Technology Layer Reference

| Layer | Default | Alternative | Specialized File |
|-------|---------|-------------|------------------|
| Client SDK | viem 2.x | ethers.js v6 | frontend-viem-wagmi.md |
| React Hooks | wagmi 2.x | - | frontend-viem-wagmi.md |
| Wallet UI | RainbowKit | ConnectKit, Web3Modal | frontend-viem-wagmi.md |
| Smart Contracts | Solidity 0.8.x | Vyper | smart-contracts-*.md |
| Dev Framework | Foundry | Hardhat | smart-contracts-foundry.md, smart-contracts-hardhat.md |
| Testing | Forge | Hardhat/Mocha | testing.md |
| Local Node | Anvil | Hardhat Network | smart-contracts-foundry.md |
| Security | OpenZeppelin 5.0 | - | security.md |
| Payments | ERC-20 (USDC) | Native ETH | payments.md |
| Account Abstraction | ERC-4337 | - | account-abstraction.md |
| Upgrades | UUPS Proxy | Transparent, Beacon | upgrades.md |
| L2 Deployment | Base, Optimism | Arbitrum, zkSync | layer2.md |

## Execution Framework

Follow this five-step approach for any Ethereum development task:

### 1. Classify
Identify the task layer:
- **Frontend** - UI, wallet connection, contract reads/writes
- **Contract** - Solidity code, storage, logic
- **Testing** - Unit tests, fuzz tests, invariants
- **Deployment** - Scripts, verification, upgrades
- **Security** - Audit, vulnerability checks

### 2. Select
Choose building blocks from the stack above. When user hasn't specified:
- Ask if they prefer Foundry or Hardhat for contracts
- Default to viem/wagmi for frontend (don't ask)
- Default to Foundry for testing (recommend but ask if unsure)

### 3. Implement
Load the relevant specialized file and follow its patterns:
- `frontend-viem-wagmi.md` - Client setup, hooks, transactions
- `smart-contracts-foundry.md` - Forge project, deployment
- `smart-contracts-hardhat.md` - Hardhat project, deployment
- `testing.md` - Test patterns, fuzzing, invariants
- `security.md` - Vulnerability checks, best practices
- `payments.md` - Token integration, payment flows
- `account-abstraction.md` - ERC-4337, smart accounts, gasless transactions
- `upgrades.md` - Proxy patterns, UUPS, storage layout
- `layer2.md` - L2 deployment, cross-chain messaging

### 4. Test
For smart contracts, always include:
- Unit tests for happy path
- Fuzz tests for numeric inputs
- Invariant tests for critical properties
- Fork tests for mainnet integrations

### 5. Review
Before deployment, check:
- [ ] All tests pass
- [ ] No compiler warnings
- [ ] Access control is correct
- [ ] Reentrancy protection where needed
- [ ] Events emitted for state changes
- [ ] No hardcoded addresses (use constructor/immutable)

## Common Patterns Quick Reference

### Read Contract Data (viem)
```typescript
const balance = await publicClient.readContract({
  address: contractAddress,
  abi: contractAbi,
  functionName: 'balanceOf',
  args: [userAddress],
})
```

### Write to Contract (wagmi)
```tsx
// Always simulate before writing
const { data: simulateData } = useSimulateContract({...})
const { writeContract } = useWriteContract()
// Then: writeContract(simulateData.request)
```

### Basic Solidity Contract
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MyContract is Ownable {
    constructor() Ownable(msg.sender) {}
}
```

### Forge Test
```solidity
import {Test} from "forge-std/Test.sol";

contract MyTest is Test {
    function setUp() public { }
    function test_Example() public { }
}
```

## Error Handling

### Common Errors and Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| `UNPREDICTABLE_GAS_LIMIT` | Transaction will revert | Check contract logic, use simulateContract |
| `INSUFFICIENT_FUNDS` | Not enough ETH for gas | Ensure wallet has ETH |
| `NONCE_TOO_LOW` | Pending transaction | Wait or speed up pending tx |
| `USER_REJECTED` | User cancelled in wallet | Handle gracefully in UI |

## Version Compatibility

This skill targets:
- **Solidity**: 0.8.20+
- **viem**: 2.x
- **wagmi**: 2.x
- **Foundry**: 1.0+
- **OpenZeppelin**: 5.0
- **Node.js**: 18+

## Resources

See `resources.md` for comprehensive documentation links.
