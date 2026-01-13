# Ethereum Development Skill for Claude Code

A comprehensive Claude Code skill for modern Ethereum development with viem, wagmi, Foundry, and Solidity.

## What is this?

This skill enhances Claude Code with specialized knowledge for Ethereum development. When installed, Claude can provide contextual guidance for:

- Building React/Next.js frontends with viem and wagmi
- Writing Solidity smart contracts
- Testing with Foundry (Forge)
- Security best practices
- Payment integration with ERC-20 tokens

## Installation

### Option 1: Personal Installation (Recommended)

Install globally for all your projects:

```bash
git clone git@github.com:ethereum/ethereum-dev-skill.git
cd ethereum-dev-skill
./install.sh
```

Or manually:

```bash
mkdir -p ~/.claude/skills/ethereum-dev
cp -r skill/* ~/.claude/skills/ethereum-dev/
```

### Option 2: Project-Level Installation

Install for a specific project:

```bash
git clone git@github.com:ethereum/ethereum-dev-skill.git
cd ethereum-dev-skill
./install.sh --project
```

Or manually:

```bash
mkdir -p .claude/skills/ethereum-dev
cp -r skill/* .claude/skills/ethereum-dev/
```

## Usage

After installation, simply ask Claude Code about Ethereum development:

- "How do I set up viem to read from a contract?"
- "Write a Solidity contract with reentrancy protection"
- "Create a fuzz test for my deposit function"
- "How do I accept USDC payments?"

Claude will automatically use the skill's specialized files to provide accurate, up-to-date guidance.

## Technology Stack

| Layer | Default | Alternative |
|-------|---------|-------------|
| Client SDK | viem 2.x | ethers.js v6 |
| React Hooks | wagmi 2.x | - |
| Wallet UI | RainbowKit | ConnectKit, Web3Modal |
| Smart Contracts | Solidity 0.8.x | Vyper |
| Dev Framework | Foundry | Hardhat |
| Testing | Forge | Hardhat/Mocha |
| Security | OpenZeppelin 5.0 | - |

## Skill Structure

```
skill/
├── SKILL.md                    # Core entry point
├── frontend-viem-wagmi.md      # viem + wagmi patterns
├── smart-contracts-foundry.md  # Foundry development
├── smart-contracts-hardhat.md  # Hardhat development
├── testing.md                  # Forge testing patterns
├── security.md                 # Security best practices
├── payments.md                 # ERC-20 payment integration
└── resources.md                # Documentation links
```

## Updating

To update to the latest version:

```bash
cd ethereum-dev-skill
git pull
./install.sh  # or --project for project-level
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

### Guidelines

- Keep files under 600 lines for token efficiency
- Include practical code examples
- Follow the progressive disclosure pattern
- Test examples before committing

## License

MIT License - see [LICENSE](LICENSE)

## Credits

Inspired by the [Solana Dev Skill](https://github.com/GuiBibeau/solana-dev-skill).
