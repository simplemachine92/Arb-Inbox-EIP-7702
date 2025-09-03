# EIP-7702 + Arbitrum Inbox

Shows how EIP-7702 code-delegated accounts get aliased when interacting with Arbitrum's Inbox.
Also serves as an example usage of [forge EIP-7702 cheatcodes](https://getfoundry.sh/reference/cheatcodes/sign-delegation#description).

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
