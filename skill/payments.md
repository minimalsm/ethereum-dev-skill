# Payment Integration with ERC-20 Tokens

Patterns for accepting and processing payments with USDC, USDT, and other ERC-20 tokens.

## Token Addresses

### Mainnet

| Token | Address | Decimals |
|-------|---------|----------|
| USDC | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` | 6 |
| USDT | `0xdAC17F958D2ee523a2206206994597C13D831ec7` | 6 |
| DAI | `0x6B175474E89094C44Da98b954EescdeCB5BE3d7` | 18 |
| WETH | `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` | 18 |

### Sepolia Testnet

| Token | Address | Decimals |
|-------|---------|----------|
| USDC | `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238` | 6 |

### Base

| Token | Address | Decimals |
|-------|---------|----------|
| USDC | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` | 6 |

## Smart Contract: Payment Receiver

### Basic Payment Receiver

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract PaymentReceiver is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable paymentToken;
    address public treasury;

    event PaymentReceived(
        address indexed from,
        uint256 amount,
        bytes32 indexed orderId
    );
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);

    error InvalidAmount();
    error InvalidAddress();

    constructor(address _paymentToken, address _treasury) Ownable(msg.sender) {
        if (_paymentToken == address(0)) revert InvalidAddress();
        if (_treasury == address(0)) revert InvalidAddress();

        paymentToken = IERC20(_paymentToken);
        treasury = _treasury;
    }

    /// @notice Accept payment for an order
    /// @param amount The payment amount (in token's smallest unit)
    /// @param orderId Unique identifier for the order
    function pay(uint256 amount, bytes32 orderId) external {
        if (amount == 0) revert InvalidAmount();

        paymentToken.safeTransferFrom(msg.sender, treasury, amount);

        emit PaymentReceived(msg.sender, amount, orderId);
    }

    /// @notice Update treasury address
    function setTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert InvalidAddress();

        address oldTreasury = treasury;
        treasury = _treasury;

        emit TreasuryUpdated(oldTreasury, _treasury);
    }
}
```

### Payment with Multiple Tokens

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MultiTokenPayment is Ownable {
    using SafeERC20 for IERC20;

    mapping(address => bool) public acceptedTokens;
    address public treasury;

    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);
    event PaymentReceived(
        address indexed from,
        address indexed token,
        uint256 amount,
        bytes32 indexed orderId
    );

    error TokenNotAccepted();
    error InvalidAmount();

    constructor(address _treasury) Ownable(msg.sender) {
        treasury = _treasury;
    }

    function addToken(address token) external onlyOwner {
        acceptedTokens[token] = true;
        emit TokenAdded(token);
    }

    function removeToken(address token) external onlyOwner {
        acceptedTokens[token] = false;
        emit TokenRemoved(token);
    }

    function pay(
        address token,
        uint256 amount,
        bytes32 orderId
    ) external {
        if (!acceptedTokens[token]) revert TokenNotAccepted();
        if (amount == 0) revert InvalidAmount();

        IERC20(token).safeTransferFrom(msg.sender, treasury, amount);

        emit PaymentReceived(msg.sender, token, amount, orderId);
    }
}
```

### Subscription/Recurring Payments

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Subscription {
    using SafeERC20 for IERC20;

    struct Plan {
        uint256 price;        // Price per period
        uint256 period;       // Period in seconds
        bool active;
    }

    struct UserSubscription {
        uint256 planId;
        uint256 nextPaymentDue;
        bool active;
    }

    IERC20 public immutable paymentToken;
    address public treasury;

    mapping(uint256 => Plan) public plans;
    mapping(address => UserSubscription) public subscriptions;

    uint256 public nextPlanId;

    event Subscribed(address indexed user, uint256 indexed planId);
    event PaymentProcessed(address indexed user, uint256 amount);
    event Cancelled(address indexed user);

    constructor(address _paymentToken, address _treasury) {
        paymentToken = IERC20(_paymentToken);
        treasury = _treasury;
    }

    function createPlan(uint256 price, uint256 period) external returns (uint256) {
        uint256 planId = nextPlanId++;
        plans[planId] = Plan({
            price: price,
            period: period,
            active: true
        });
        return planId;
    }

    function subscribe(uint256 planId) external {
        Plan memory plan = plans[planId];
        require(plan.active, "Plan not active");

        // Take first payment
        paymentToken.safeTransferFrom(msg.sender, treasury, plan.price);

        subscriptions[msg.sender] = UserSubscription({
            planId: planId,
            nextPaymentDue: block.timestamp + plan.period,
            active: true
        });

        emit Subscribed(msg.sender, planId);
        emit PaymentProcessed(msg.sender, plan.price);
    }

    function processPayment(address user) external {
        UserSubscription storage sub = subscriptions[user];
        require(sub.active, "No active subscription");
        require(block.timestamp >= sub.nextPaymentDue, "Payment not due");

        Plan memory plan = plans[sub.planId];

        paymentToken.safeTransferFrom(user, treasury, plan.price);
        sub.nextPaymentDue += plan.period;

        emit PaymentProcessed(user, plan.price);
    }

    function cancel() external {
        subscriptions[msg.sender].active = false;
        emit Cancelled(msg.sender);
    }
}
```

## Frontend: Reading Balances

### With viem

```typescript
import { createPublicClient, http, formatUnits, erc20Abi } from 'viem'
import { mainnet } from 'viem/chains'

const publicClient = createPublicClient({
  chain: mainnet,
  transport: http(),
})

const USDC_ADDRESS = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48'

async function getUsdcBalance(userAddress: `0x${string}`): Promise<string> {
  const balance = await publicClient.readContract({
    address: USDC_ADDRESS,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: [userAddress],
  })

  // USDC has 6 decimals
  return formatUnits(balance, 6)
}

// Check allowance
async function getAllowance(
  owner: `0x${string}`,
  spender: `0x${string}`
): Promise<bigint> {
  return publicClient.readContract({
    address: USDC_ADDRESS,
    abi: erc20Abi,
    functionName: 'allowance',
    args: [owner, spender],
  })
}
```

### With wagmi

```tsx
import { useReadContract, useReadContracts } from 'wagmi'
import { erc20Abi, formatUnits } from 'viem'

const USDC_ADDRESS = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48'

function TokenBalance({ address }: { address: `0x${string}` }) {
  const { data: balance, isLoading } = useReadContract({
    address: USDC_ADDRESS,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: [address],
  })

  if (isLoading) return <span>Loading...</span>

  return <span>{formatUnits(balance ?? 0n, 6)} USDC</span>
}

// Multiple reads in one call
function TokenInfo({ address }: { address: `0x${string}` }) {
  const { data } = useReadContracts({
    contracts: [
      {
        address: USDC_ADDRESS,
        abi: erc20Abi,
        functionName: 'balanceOf',
        args: [address],
      },
      {
        address: USDC_ADDRESS,
        abi: erc20Abi,
        functionName: 'allowance',
        args: [address, PAYMENT_CONTRACT_ADDRESS],
      },
    ],
  })

  const balance = data?.[0].result ?? 0n
  const allowance = data?.[1].result ?? 0n

  return (
    <div>
      <p>Balance: {formatUnits(balance, 6)} USDC</p>
      <p>Allowance: {formatUnits(allowance, 6)} USDC</p>
    </div>
  )
}
```

## Frontend: Approval Flow

Before transferring tokens to a contract, users must approve the contract to spend their tokens.

### Approval + Payment Component

```tsx
import {
  useSimulateContract,
  useWriteContract,
  useWaitForTransactionReceipt,
  useReadContract,
  useAccount,
} from 'wagmi'
import { erc20Abi, parseUnits, maxUint256 } from 'viem'

const USDC_ADDRESS = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48'
const PAYMENT_CONTRACT = '0x...'

// Payment contract ABI (just the pay function)
const paymentAbi = [
  {
    name: 'pay',
    type: 'function',
    inputs: [
      { name: 'amount', type: 'uint256' },
      { name: 'orderId', type: 'bytes32' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
] as const

interface PaymentButtonProps {
  amount: string // Amount in USDC (e.g., "10.00")
  orderId: string
}

function PaymentButton({ amount, orderId }: PaymentButtonProps) {
  const { address } = useAccount()

  // Parse amount to smallest unit (6 decimals for USDC)
  const amountInWei = parseUnits(amount, 6)

  // Check current allowance
  const { data: allowance } = useReadContract({
    address: USDC_ADDRESS,
    abi: erc20Abi,
    functionName: 'allowance',
    args: [address!, PAYMENT_CONTRACT],
    query: { enabled: !!address },
  })

  const needsApproval = (allowance ?? 0n) < amountInWei

  // Approval simulation
  const { data: approveSimulate } = useSimulateContract({
    address: USDC_ADDRESS,
    abi: erc20Abi,
    functionName: 'approve',
    args: [PAYMENT_CONTRACT, maxUint256], // Infinite approval
    query: { enabled: needsApproval },
  })

  // Payment simulation
  const { data: paySimulate } = useSimulateContract({
    address: PAYMENT_CONTRACT,
    abi: paymentAbi,
    functionName: 'pay',
    args: [amountInWei, orderId as `0x${string}`],
    query: { enabled: !needsApproval },
  })

  // Write hooks
  const {
    data: approveHash,
    writeContract: approve,
    isPending: isApproving,
  } = useWriteContract()

  const {
    data: payHash,
    writeContract: pay,
    isPending: isPaying,
  } = useWriteContract()

  // Wait for confirmations
  const { isLoading: isApproveConfirming, isSuccess: isApproved } =
    useWaitForTransactionReceipt({ hash: approveHash })

  const { isLoading: isPayConfirming, isSuccess: isPaid } =
    useWaitForTransactionReceipt({ hash: payHash })

  // Handle button click
  const handleClick = () => {
    if (needsApproval && approveSimulate?.request) {
      approve(approveSimulate.request)
    } else if (paySimulate?.request) {
      pay(paySimulate.request)
    }
  }

  // Button state
  const isLoading = isApproving || isApproveConfirming || isPaying || isPayConfirming
  const buttonText = needsApproval
    ? isApproving || isApproveConfirming
      ? 'Approving...'
      : 'Approve USDC'
    : isPaying || isPayConfirming
      ? 'Processing...'
      : `Pay ${amount} USDC`

  if (isPaid) {
    return <div>Payment successful!</div>
  }

  return (
    <button onClick={handleClick} disabled={isLoading}>
      {buttonText}
    </button>
  )
}
```

### Permit2 for Better UX

Permit2 allows gasless approvals using signatures. Users sign once, and the protocol handles approvals.

```typescript
// Using Permit2 (requires additional setup)
import { PERMIT2_ADDRESS, AllowanceTransfer } from '@uniswap/permit2-sdk'

// Check if user has approved Permit2
const hasPermit2Approval = await checkPermit2Approval(userAddress, tokenAddress)

if (!hasPermit2Approval) {
  // One-time approval to Permit2 (not your contract)
  await approvePermit2(tokenAddress)
}

// Now use signature-based transfers
const signature = await signPermit2(...)
await yourContract.payWithPermit2(amount, signature)
```

## Decimal Handling

**Critical:** Different tokens have different decimals. Always check!

```typescript
import { formatUnits, parseUnits } from 'viem'

// USDC/USDT: 6 decimals
const usdcAmount = parseUnits('100', 6)  // 100_000_000n
const usdcDisplay = formatUnits(100_000_000n, 6)  // "100"

// DAI/WETH: 18 decimals
const daiAmount = parseUnits('100', 18)  // 100_000_000_000_000_000_000n
const daiDisplay = formatUnits(100_000_000_000_000_000_000n, 18)  // "100"

// Helper function
function formatTokenAmount(amount: bigint, decimals: number): string {
  return formatUnits(amount, decimals)
}

function parseTokenAmount(amount: string, decimals: number): bigint {
  return parseUnits(amount, decimals)
}
```

## Testing Payments

### Foundry Fork Test

```solidity
contract PaymentTest is Test {
    PaymentReceiver receiver;
    IERC20 usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address usdcWhale = 0x55FE002aefF02F77364de339a1292923A15844B8;
    address treasury = makeAddr("treasury");

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));
        receiver = new PaymentReceiver(address(usdc), treasury);
    }

    function test_Payment() public {
        uint256 amount = 1000e6; // 1000 USDC

        vm.startPrank(usdcWhale);
        usdc.approve(address(receiver), amount);
        receiver.pay(amount, bytes32("order123"));
        vm.stopPrank();

        assertEq(usdc.balanceOf(treasury), amount);
    }
}
```

## Security Considerations

1. **Always use SafeERC20** - USDT doesn't return bool on transfer
2. **Validate amounts** - Check for zero amounts
3. **Emit events** - For off-chain tracking
4. **Handle decimals correctly** - 6 vs 18 decimals
5. **Check allowance before transfer** - Show user if approval needed
6. **Consider permit** - For better UX (EIP-2612)
