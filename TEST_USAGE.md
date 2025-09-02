# Test Usage Guide

This document explains how to run the EIP-7702 Arbitrum Inbox vulnerability tests.

## Test Files

### 1. ArbitrumInboxVulnerability.t.sol
Main test suite that demonstrates the vulnerability against the real Arbitrum Inbox contract on mainnet.

**Requirements:**
- Mainnet RPC URL (Alchemy, Infura, etc.)
- Set `MAINNET_RPC_URL` environment variable

### 2. ArbitrumInboxVulnerability.basic.t.sol
Basic test suite that verifies account setup and vulnerability detection without requiring mainnet access.

**Requirements:**
- None (runs locally)

## Setup

1. Copy environment variables:
```bash
cp .env.example .env
```

2. Edit `.env` and set your mainnet RPC URL:
```bash
MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY_HERE
```

## Running Tests

### Basic Tests (No RPC Required)
```bash
# Run basic account setup tests
forge test --match-contract ArbitrumInboxVulnerabilityBasicTest -v

# Run specific basic test
forge test --match-test test_AccountSetup -v
forge test --match-test test_VulnerabilityDetection -v
```

### Mainnet Fork Tests (RPC Required)
```bash
# Run all mainnet fork tests
forge test --match-contract ArbitrumInboxVulnerabilityTest --fork-url $MAINNET_RPC_URL -v

# Run specific mainnet tests
forge test --match-test test_RegularEOADeposit --fork-url $MAINNET_RPC_URL -v
forge test --match-test test_EIP7702AccountDepositVulnerability --fork-url $MAINNET_RPC_URL -v
```

### All Tests
```bash
# Run all tests (requires RPC for mainnet tests)
forge test -v
```

## Test Descriptions

### Basic Tests
- `test_AccountSetup()`: Verifies all account types are created correctly
- `test_VulnerabilityDetection()`: Shows how EIP-7702 accounts appear as contracts

### Mainnet Fork Tests
- `test_RegularEOADeposit()`: Tests EOA deposits (should not be aliased)
- `test_RegularContractDeposit()`: Tests contract deposits (should be aliased)
- `test_EIP7702AccountDepositVulnerability()`: Demonstrates the vulnerability
- `test_CompareAllAccountTypes()`: Side-by-side comparison of all account types

## Expected Results

### Basic Tests
Both tests should pass, demonstrating:
- EIP-7702 accounts appear to have code (23 bytes)
- This causes them to be incorrectly treated as contracts
- They get aliased when they shouldn't be

### Mainnet Fork Tests
Tests demonstrate against real Arbitrum contract:
- EOAs work correctly (no aliasing)
- Contracts work correctly (proper aliasing)
- EIP-7702 accounts are incorrectly aliased (vulnerability)

## Troubleshooting

### "RPC URL not set" Error
Make sure `MAINNET_RPC_URL` is set in your `.env` file.

### "Contract not found" Error
Verify the Arbitrum Inbox address is correct: `0x7C058ad1D0Ee415f7e7f30e62DB1BCf568470a10`

### Rate Limiting
Use a paid RPC provider (Alchemy, Infura) for better reliability.

## Understanding the Vulnerability

The vulnerability occurs because:

1. **EIP-7702 accounts have bytecode** (23 bytes: `0xef0100` + 20-byte delegate address)
2. **Arbitrum's contract detection** uses `extcodesize > 0` to identify contracts
3. **EIP-7702 accounts appear as contracts** to this basic check
4. **Address aliasing is applied incorrectly** causing funds to go to wrong L2 address
5. **Users lose access to their funds** because they don't control the aliased address

The tests prove this vulnerability exists in the real production Arbitrum Inbox contract.