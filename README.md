# EIP-7702 + Arbitrum Inbox

Shows how EIP-7702 accounts get aliased when using Arbitrum's Inbox.

## What it does

EOA with EIP-7702 code → gets treated like a smart contract → address gets aliased on Arbitrum L2.

## Setup

```bash
cp .env.example .env
# Add your mainnet RPC URL to .env
```

## Run

```bash
forge test -v
```

## The point

EIP-7702 delegation makes your EOA look like a contract to Arbitrum's Inbox, so your L2 deposit will be sent to an Aliased address.
