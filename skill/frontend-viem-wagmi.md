# Frontend Development with viem + wagmi

Patterns for building React/Next.js frontends that interact with Ethereum.

## viem Fundamentals

viem is a TypeScript-first Ethereum library. It uses "Clients" (not providers) to interact with the blockchain.

### Client Types

| Client | Purpose | Use Case |
|--------|---------|----------|
| Public Client | Read-only operations | Fetching data, listening to events |
| Wallet Client | Signing transactions | Sending transactions, signing messages |
| Test Client | Testing with Anvil | Fork testing, impersonation |

### Public Client Setup

```typescript
import { createPublicClient, http } from 'viem'
import { mainnet, sepolia } from 'viem/chains'

// Mainnet client
export const publicClient = createPublicClient({
  chain: mainnet,
  transport: http(), // Uses public RPC by default
})

// With custom RPC
export const publicClientWithRpc = createPublicClient({
  chain: mainnet,
  transport: http('https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY'),
})

// Multiple chains
export const sepoliaClient = createPublicClient({
  chain: sepolia,
  transport: http(),
})
```

### Wallet Client Setup

```typescript
import { createWalletClient, custom, http } from 'viem'
import { mainnet } from 'viem/chains'
import { privateKeyToAccount } from 'viem/accounts'

// Browser wallet (MetaMask, etc.)
export const walletClient = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum!),
})

// Server-side with private key
const account = privateKeyToAccount('0x...')
export const serverWalletClient = createWalletClient({
  account,
  chain: mainnet,
  transport: http('https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY'),
})
```

## Contract Interactions

### Reading Contract Data

```typescript
import { formatUnits } from 'viem'

// Single read
const balance = await publicClient.readContract({
  address: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', // USDC
  abi: erc20Abi,
  functionName: 'balanceOf',
  args: ['0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045'],
})

// Format result (USDC has 6 decimals)
const formatted = formatUnits(balance, 6) // "1234.56"
```

### Batching Reads with Multicall

```typescript
const results = await publicClient.multicall({
  contracts: [
    {
      address: usdcAddress,
      abi: erc20Abi,
      functionName: 'balanceOf',
      args: [userAddress],
    },
    {
      address: usdcAddress,
      abi: erc20Abi,
      functionName: 'allowance',
      args: [userAddress, spenderAddress],
    },
  ],
})

const [balance, allowance] = results.map(r => r.result)
```

### Writing to Contracts

```typescript
// Get account from wallet
const [account] = await walletClient.getAddresses()

// Simulate first (catches errors before wallet popup)
const { request } = await publicClient.simulateContract({
  account,
  address: contractAddress,
  abi: contractAbi,
  functionName: 'mint',
  args: [1n],
})

// Execute the transaction
const hash = await walletClient.writeContract(request)

// Wait for confirmation
const receipt = await publicClient.waitForTransactionReceipt({ hash })
console.log('Status:', receipt.status) // 'success' or 'reverted'
```

### Using getContract Helper

```typescript
import { getContract } from 'viem'

const contract = getContract({
  address: '0x...',
  abi: myAbi,
  client: { public: publicClient, wallet: walletClient },
})

// Reads
const value = await contract.read.getValue()
const balance = await contract.read.balanceOf([userAddress])

// Writes
const hash = await contract.write.setValue([123n])
const hash2 = await contract.write.transfer([recipient, amount])

// Events
const unwatch = contract.watchEvent.Transfer(
  { from: userAddress }, // Filter by indexed params
  { onLogs: (logs) => console.log(logs) }
)
```

## Event Handling

### Watch Events (Real-time)

```typescript
const unwatch = publicClient.watchEvent({
  address: contractAddress,
  event: parseAbiItem('event Transfer(address indexed from, address indexed to, uint256 value)'),
  args: { from: userAddress }, // Optional filter
  onLogs: (logs) => {
    logs.forEach(log => {
      console.log('Transfer:', log.args.from, '->', log.args.to, log.args.value)
    })
  },
})

// Stop watching
unwatch()
```

### Get Historical Events

```typescript
const logs = await publicClient.getLogs({
  address: contractAddress,
  event: parseAbiItem('event Transfer(address indexed from, address indexed to, uint256 value)'),
  fromBlock: 18000000n,
  toBlock: 'latest',
})
```

## wagmi React Integration

wagmi provides React hooks built on top of viem. It handles wallet connection, caching, and React state management.

### Configuration

```typescript
// config.ts
import { http, createConfig } from 'wagmi'
import { mainnet, sepolia } from 'wagmi/chains'
import { injected, walletConnect } from 'wagmi/connectors'

export const config = createConfig({
  chains: [mainnet, sepolia],
  connectors: [
    injected(),
    walletConnect({ projectId: 'YOUR_PROJECT_ID' }),
  ],
  transports: {
    [mainnet.id]: http(),
    [sepolia.id]: http(),
  },
})
```

### Provider Setup

```tsx
// app.tsx
import { WagmiProvider } from 'wagmi'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { config } from './config'

const queryClient = new QueryClient()

export function App({ children }: { children: React.ReactNode }) {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        {children}
      </QueryClientProvider>
    </WagmiProvider>
  )
}
```

### Wallet Connection

```tsx
import { useAccount, useConnect, useDisconnect } from 'wagmi'

function ConnectButton() {
  const { address, isConnected, chain } = useAccount()
  const { connectors, connect, isPending } = useConnect()
  const { disconnect } = useDisconnect()

  if (isConnected) {
    return (
      <div>
        <p>Connected: {address}</p>
        <p>Chain: {chain?.name}</p>
        <button onClick={() => disconnect()}>Disconnect</button>
      </div>
    )
  }

  return (
    <div>
      {connectors.map((connector) => (
        <button
          key={connector.uid}
          onClick={() => connect({ connector })}
          disabled={isPending}
        >
          {connector.name}
        </button>
      ))}
    </div>
  )
}
```

### Reading Contract Data

```tsx
import { useReadContract, useReadContracts } from 'wagmi'

function TokenBalance({ address }: { address: `0x${string}` }) {
  const { data: balance, isLoading, error } = useReadContract({
    address: USDC_ADDRESS,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: [address],
  })

  if (isLoading) return <div>Loading...</div>
  if (error) return <div>Error: {error.message}</div>

  return <div>Balance: {formatUnits(balance ?? 0n, 6)} USDC</div>
}

// Multiple reads
function TokenInfo({ address }: { address: `0x${string}` }) {
  const { data } = useReadContracts({
    contracts: [
      { address: USDC_ADDRESS, abi: erc20Abi, functionName: 'balanceOf', args: [address] },
      { address: USDC_ADDRESS, abi: erc20Abi, functionName: 'symbol' },
      { address: USDC_ADDRESS, abi: erc20Abi, functionName: 'decimals' },
    ],
  })

  const [balance, symbol, decimals] = data ?? []
  // ...
}
```

### Writing to Contracts (The Right Way)

Always simulate before writing to catch errors before the wallet popup:

```tsx
import {
  useSimulateContract,
  useWriteContract,
  useWaitForTransactionReceipt,
  type BaseError,
} from 'wagmi'
import { parseUnits } from 'viem'

function TransferButton({ to, amount }: { to: `0x${string}`; amount: string }) {
  // Step 1: Simulate the transaction
  const { data: simulateData, error: simulateError } = useSimulateContract({
    address: USDC_ADDRESS,
    abi: erc20Abi,
    functionName: 'transfer',
    args: [to, parseUnits(amount, 6)],
  })

  // Step 2: Write hook
  const {
    data: hash,
    error: writeError,
    isPending,
    writeContract,
  } = useWriteContract()

  // Step 3: Wait for confirmation
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  })

  const error = simulateError || writeError

  return (
    <div>
      <button
        disabled={!simulateData?.request || isPending || isConfirming}
        onClick={() => writeContract(simulateData!.request)}
      >
        {isPending ? 'Confirming...' : isConfirming ? 'Processing...' : 'Transfer'}
      </button>

      {hash && <p>Transaction: {hash}</p>}
      {isSuccess && <p>Transfer successful!</p>}
      {error && <p>Error: {(error as BaseError).shortMessage || error.message}</p>}
    </div>
  )
}
```

### Sending ETH

```tsx
import { useSendTransaction, useWaitForTransactionReceipt } from 'wagmi'
import { parseEther } from 'viem'

function SendEthButton({ to, amount }: { to: `0x${string}`; amount: string }) {
  const { data: hash, sendTransaction, isPending } = useSendTransaction()
  const { isLoading, isSuccess } = useWaitForTransactionReceipt({ hash })

  return (
    <button
      disabled={isPending || isLoading}
      onClick={() => sendTransaction({ to, value: parseEther(amount) })}
    >
      {isPending ? 'Confirming...' : isLoading ? 'Sending...' : `Send ${amount} ETH`}
    </button>
  )
}
```

### Watching Events

```tsx
import { useWatchContractEvent } from 'wagmi'

function TransferWatcher() {
  useWatchContractEvent({
    address: USDC_ADDRESS,
    abi: erc20Abi,
    eventName: 'Transfer',
    onLogs: (logs) => {
      logs.forEach((log) => {
        console.log('Transfer:', log.args.from, '->', log.args.to)
      })
    },
  })

  return <div>Watching for transfers...</div>
}
```

## Wallet Connection UIs

### RainbowKit (Recommended)

```bash
npm install @rainbow-me/rainbowkit wagmi viem @tanstack/react-query
```

```tsx
import '@rainbow-me/rainbowkit/styles.css'
import { getDefaultConfig, RainbowKitProvider, ConnectButton } from '@rainbow-me/rainbowkit'
import { WagmiProvider } from 'wagmi'
import { mainnet, sepolia } from 'wagmi/chains'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'

const config = getDefaultConfig({
  appName: 'My App',
  projectId: 'YOUR_WALLETCONNECT_PROJECT_ID',
  chains: [mainnet, sepolia],
})

const queryClient = new QueryClient()

function App() {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider>
          <ConnectButton />
          {/* Your app */}
        </RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  )
}
```

## Type Safety with ABIs

### Generate Types from ABI

```typescript
// abi.ts - Import ABI JSON and get type inference
export const myContractAbi = [
  {
    type: 'function',
    name: 'balanceOf',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
  },
  // ...
] as const // <-- Important: use 'as const' for type inference
```

### Using wagmi CLI for Type Generation

```bash
npm install -D @wagmi/cli
```

```typescript
// wagmi.config.ts
import { defineConfig } from '@wagmi/cli'
import { foundry } from '@wagmi/cli/plugins'

export default defineConfig({
  out: 'src/generated.ts',
  plugins: [
    foundry({
      project: '../contracts', // Path to Foundry project
    }),
  ],
})
```

```bash
npx wagmi generate
```

## Common Patterns

### Handle Chain Switching

```tsx
import { useSwitchChain } from 'wagmi'

function ChainSwitcher() {
  const { chains, switchChain, isPending } = useSwitchChain()

  return (
    <div>
      {chains.map((chain) => (
        <button
          key={chain.id}
          onClick={() => switchChain({ chainId: chain.id })}
          disabled={isPending}
        >
          {chain.name}
        </button>
      ))}
    </div>
  )
}
```

### Handle Account Changes

```tsx
import { useAccount } from 'wagmi'
import { useEffect } from 'react'

function AccountWatcher() {
  const { address, isConnected } = useAccount()

  useEffect(() => {
    if (address) {
      // Refetch user data, update state, etc.
      console.log('Account changed:', address)
    }
  }, [address])

  // ...
}
```

### Optimistic Updates

```tsx
import { useQueryClient } from '@tanstack/react-query'

function OptimisticMint() {
  const queryClient = useQueryClient()

  const { writeContract } = useWriteContract({
    mutation: {
      onSuccess: () => {
        // Invalidate and refetch balance after successful mint
        queryClient.invalidateQueries({ queryKey: ['readContract'] })
      },
    },
  })

  // ...
}
```

## Error Handling Best Practices

```tsx
import type { BaseError } from 'wagmi'

function ErrorDisplay({ error }: { error: Error | null }) {
  if (!error) return null

  // wagmi errors have shortMessage for user-friendly display
  const message = (error as BaseError).shortMessage || error.message

  // Common error types
  if (message.includes('User rejected')) {
    return <p>Transaction cancelled</p>
  }
  if (message.includes('insufficient funds')) {
    return <p>Not enough ETH for gas</p>
  }

  return <p>Error: {message}</p>
}
```
