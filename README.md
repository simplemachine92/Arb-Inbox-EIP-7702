## EIP-7702 Arbitrum Inbox Aliasing Demo

This project demonstrates how EIP-7702 (Account Abstraction via Code Delegation) interacts with Arbitrum's Inbox contract, specifically showcasing the address aliasing behavior for EOAs with delegated code.

## Overview

EIP-7702 allows Externally Owned Accounts (EOAs) to temporarily delegate their execution to smart contract code. When such accounts interact with Arbitrum's Inbox contract, they are treated as smart contracts due to having bytecode, which triggers Arbitrum's address aliasing mechanism.

## Key Components

- **SimpleDelegateContract**: A simple contract that can execute arbitrary calls on behalf of delegating EOAs
- **ArbitrumInboxAliasingWithAA**: Test suite demonstrating the aliasing behavior when EIP-7702 accounts interact with the real Arbitrum Inbox

## How It Works

1. An EOA (Alice) delegates execution to `SimpleDelegateContract` using EIP-7702
2. The EOA now has bytecode (`0xef0100` + delegate address) making it appear as a smart contract
3. When depositing ETH to Arbitrum via the Inbox, the account is aliased using Arbitrum's L1→L2 address transformation
4. The aliased address receives the funds on L2, demonstrating how EIP-7702 accounts are treated differently than regular EOAs

## Setup

1. Copy the environment file:
```bash
cp .env.example .env
```

2. Set your mainnet RPC URL in `.env`:
```bash
MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY_HERE
```

## Usage

### Build
```bash
forge build
```

### Run Tests
```bash
# Run the main aliasing test (requires mainnet RPC)
forge test --match-contract ArbitrumInboxAliasingWithAA -v

# Run specific test
forge test --match-test test_DelegatedInboxCall -v
```

### Key Test: `test_DelegatedInboxCall()`

This test demonstrates:
1. Setting up an EOA with EIP-7702 delegation
2. Verifying the EOA now has contract code
3. Making a deposit to Arbitrum Inbox via delegated execution
4. Confirming that address aliasing occurs (EOA is treated as a contract)

The test proves that `ALICE_ADDRESS ≠ expectedAliasedAddress`, showing the aliasing transformation.

## Address Aliasing Formula

Arbitrum applies this transformation to contract addresses:
```solidity
function applyL1ToL2Alias(address l1Address) public pure returns (address) {
    uint160 offset = uint160(0x1111000000000000000000000000000000001111);
    return address(uint160(l1Address) + offset);
}
```

## Technical Details

- **Arbitrum Inbox**: `0x4Dbd4fc535Ac27206064B68FfCf827b0A60BAB3f` (Ethereum mainnet)
- **EIP-7702 Bytecode**: `0xef0100` + 20-byte delegate address (23 bytes total)
- **Contract Detection**: Arbitrum uses `extcodesize > 0` to identify contracts
- **Aliasing Trigger**: Any account with bytecode gets aliased when interacting with the Inbox

## Requirements

- Foundry toolkit
- Mainnet RPC access (Alchemy, Infura, etc.)
- EIP-7702 support in test environment (provided by Foundry's `vm.signAndAttachDelegation`)
