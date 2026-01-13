# Ethereum Development Resources

Essential documentation, tools, and references for Ethereum development.

## Official Documentation

### Core Libraries

| Resource | URL | Description |
|----------|-----|-------------|
| viem | https://viem.sh | TypeScript Ethereum library |
| wagmi | https://wagmi.sh | React hooks for Ethereum |
| Solidity | https://docs.soliditylang.org | Smart contract language |
| Foundry | https://book.getfoundry.sh | Rust-based dev toolkit |
| Hardhat | https://hardhat.org/docs | JS-based dev environment |
| OpenZeppelin | https://docs.openzeppelin.com/contracts/5.x/ | Security-audited contracts |

### Wallet Connection

| Resource | URL | Description |
|----------|-----|-------------|
| RainbowKit | https://www.rainbowkit.com/docs | React wallet connection |
| ConnectKit | https://docs.family.co/connectkit | Alternative wallet UI |
| Web3Modal | https://docs.walletconnect.com/web3modal | WalletConnect's modal |

### Standards

| EIP | URL | Description |
|-----|-----|-------------|
| ERC-20 | https://eips.ethereum.org/EIPS/eip-20 | Fungible tokens |
| ERC-721 | https://eips.ethereum.org/EIPS/eip-721 | NFTs |
| ERC-1155 | https://eips.ethereum.org/EIPS/eip-1155 | Multi-token |
| ERC-4626 | https://eips.ethereum.org/EIPS/eip-4626 | Tokenized vaults |
| EIP-712 | https://eips.ethereum.org/EIPS/eip-712 | Typed data signing |
| EIP-2612 | https://eips.ethereum.org/EIPS/eip-2612 | Permit (gasless approvals) |

## GitHub Repositories

### Libraries

- **viem**: https://github.com/wevm/viem
- **wagmi**: https://github.com/wevm/wagmi
- **Foundry**: https://github.com/foundry-rs/foundry
- **OpenZeppelin Contracts**: https://github.com/OpenZeppelin/openzeppelin-contracts
- **Solmate**: https://github.com/transmissions11/solmate
- **Solady**: https://github.com/Vectorized/solady

### Templates

- **Foundry Template**: https://github.com/PaulRBerg/foundry-template
- **Hardhat Template**: https://github.com/paulrberg/hardhat-template
- **Create wagmi**: https://github.com/wevm/create-wagmi

## Security Resources

### Guides

| Resource | URL |
|----------|-----|
| Solidity Security | https://docs.soliditylang.org/en/latest/security-considerations.html |
| ConsenSys Best Practices | https://consensys.github.io/smart-contract-best-practices/ |
| Trail of Bits | https://github.com/crytic/building-secure-contracts |
| SWC Registry | https://swcregistry.io/ |

### Tools

| Tool | URL | Purpose |
|------|-----|---------|
| Slither | https://github.com/crytic/slither | Static analysis |
| Mythril | https://github.com/Consensys/mythril | Security analysis |
| Echidna | https://github.com/crytic/echidna | Fuzzing |
| Certora | https://www.certora.com/ | Formal verification |

### Audit Firms

- Trail of Bits
- OpenZeppelin
- Consensys Diligence
- Spearbit
- Code4rena (competitive audits)

## Block Explorers

| Network | Explorer |
|---------|----------|
| Ethereum Mainnet | https://etherscan.io |
| Sepolia Testnet | https://sepolia.etherscan.io |
| Base | https://basescan.org |
| Arbitrum | https://arbiscan.io |
| Optimism | https://optimistic.etherscan.io |

## RPC Providers

| Provider | URL | Free Tier |
|----------|-----|-----------|
| Alchemy | https://www.alchemy.com | Yes |
| Infura | https://www.infura.io | Yes |
| QuickNode | https://www.quicknode.com | Yes |
| Chainstack | https://chainstack.com | Yes |
| Ankr | https://www.ankr.com | Yes |

## Testing & Debugging

| Resource | URL | Purpose |
|----------|-----|---------|
| Tenderly | https://tenderly.co | Transaction simulation |
| Foundry Debugger | Built into forge | Step-through debugging |
| Hardhat Console | Built into hardhat | Interactive REPL |

## Learning Resources

### Tutorials

- **CryptoZombies**: https://cryptozombies.io - Solidity basics
- **Speedrun Ethereum**: https://speedrunethereum.com - Build projects
- **Solidity by Example**: https://solidity-by-example.org - Code examples
- **useWeb3**: https://www.useweb3.xyz - Curated resources

### Courses

- **Cyfrin Updraft**: https://updraft.cyfrin.io - Free Solidity course
- **Alchemy University**: https://university.alchemy.com - Web3 development

### YouTube Channels

- **Patrick Collins** - Comprehensive Solidity tutorials
- **Smart Contract Programmer** - Short, focused videos
- **Chainlink** - Oracle and DeFi patterns

## Community

| Platform | URL |
|----------|-----|
| Ethereum Stack Exchange | https://ethereum.stackexchange.com |
| Foundry Telegram | https://t.me/foundry_support |
| OpenZeppelin Forum | https://forum.openzeppelin.com |
| Ethereum Research | https://ethresear.ch |

## Token Lists

| List | URL |
|------|-----|
| Uniswap | https://tokenlists.org |
| 1inch | https://tokenlists.org/token-list?url=tokens.1inch.eth |
| CoinGecko | https://tokenlists.org/token-list?url=https://tokens.coingecko.com/uniswap/all.json |

## Gas & Fees

| Resource | URL | Purpose |
|----------|-----|---------|
| ETH Gas Station | https://ethgasstation.info | Gas price tracker |
| Blocknative | https://www.blocknative.com/gas-estimator | Gas estimation |
| ultrasound.money | https://ultrasound.money | Fee burn tracker |

## Mainnet Contract Addresses

### Common Tokens

```
USDC:   0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
USDT:   0xdAC17F958D2ee523a2206206994597C13D831ec7
DAI:    0x6B175474E89094C44Da98b954EescdeCB5BE3d7
WETH:   0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
WBTC:   0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599
```

### DeFi Protocols

```
Uniswap V3 Router:     0xE592427A0AEce92De3Edee1F18E0157C05861564
Aave V3 Pool:          0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2
Compound V3 (cUSDC):   0xc3d688B66703497DAA19211EEdff47f25384cdc3
```

### Infrastructure

```
Chainlink ETH/USD:     0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
ENS Registry:          0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e
Permit2:               0x000000000022D473030F116dDEE9F6B43aC78BA3
```
