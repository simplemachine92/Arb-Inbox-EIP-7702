#!/bin/bash

# Script to deploy contract and run delegation transaction
set -e

echo "=== Deploying Contract with Foundry ==="
forge script script/DeployDelegate.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify

echo ""
echo "=== Running JavaScript Delegation Script ==="
echo "Note: You'll need to update the implementation address and signature values"
echo "from the Foundry script output in your delegate.js file"

node delegation/delegate.js