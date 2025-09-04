# EIP-7702 + Arbitrum Inbox

Shows how EIP-7702 code-delegated accounts get aliased when interacting with Arbitrum's Inbox.
Also serves as an example usage of [forge EIP-7702 cheatcodes](https://getfoundry.sh/reference/cheatcodes/sign-delegation#description) and [viem's EIP-7702 methods](https://viem.sh/docs/eip7702).

## What it does

EOA with EIP-7702 code → gets treated like a smart contract → address gets aliased on Arbitrum L2.

## Setup

```bash
cp .env.example .env
# Fill in your RPC URLs and testnet private key
npm install
```

## Run Tests

```bash
forge test -v
```

## EIP-7702 Delegation (Live Testnet)

Deploy implementation contract:
```bash
source .env && forge script --chain sepolia script/DeployDelegate.s.sol:DeployDelegateScript --rpc-url sepolia --broadcast
```

Add the deployed address to `.env` as `IMPLEMENTATION_ADDRESS`, then delegate:
```bash
source .env && node delegation/delegate.js
```

Verify delegation:
```bash
source .env && node delegation/delegate.js --verify-only
```

Reset delegation:
```bash
source .env && node delegation/reset-delegation.js
```

Verify reset:
```bash
source .env && node delegation/reset-delegation.js --verify-only
```

## The point

EIP-7702 delegation makes your EOA look like a contract to Arbitrum's Inbox, so your L2 deposit will be sent to an Aliased address.
