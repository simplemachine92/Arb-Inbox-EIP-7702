// EIP-7702 Delegation Reset Script
import { createWalletClient, createPublicClient, http } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { sepolia } from 'viem/chains';
import { config } from 'dotenv';

// Load environment variables
config();

async function resetEIP7702Delegation() {
  // Validate environment variables
  if (!process.env.PRIVATE_KEY) {
    throw new Error('PRIVATE_KEY not found in environment variables');
  }
  if (!process.env.SEPOLIA_RPC_URL) {
    throw new Error('SEPOLIA_RPC_URL not found in environment variables');
  }

  const account = privateKeyToAccount(process.env.PRIVATE_KEY);

  // Create separate clients for reading and writing
  const publicClient = createPublicClient({
    chain: sepolia,
    transport: http(process.env.SEPOLIA_RPC_URL),
  });

  const walletClient = createWalletClient({
    account,
    chain: sepolia,
    transport: http(process.env.SEPOLIA_RPC_URL),
  });

  console.log('=== EIP-7702 Delegation Reset ===');
  console.log('Account Address:', account.address);
  console.log('Chain ID:', sepolia.id);

  // Check current delegation status
  console.log('\n=== Current Delegation Status ===');
  const currentCode = await publicClient.getCode({ address: account.address });
  if (currentCode && currentCode !== '0x') {
    console.log('✅ Account currently has delegated code');
    console.log('Current code length:', currentCode.length);
  } else {
    console.log('ℹ️  Account has no delegated code (already reset or never delegated)');
  }

  try {
    console.log('\n=== Step 1: Sign Reset Authorization ===');
    
    // Create authorization to reset delegation (contract address = zero address)
    const resetAuthorization = await walletClient.signAuthorization({
      contractAddress: '0x0000000000000000000000000000000000000000', // Zero address to reset
      executor: 'self', // Self-executing
    });

    console.log('✅ Reset authorization signed successfully');
    console.log('Reset Authorization:', {
      contractAddress: resetAuthorization.contractAddress,
      chainId: resetAuthorization.chainId,
      nonce: resetAuthorization.nonce,
    });

    console.log('\n=== Step 2: Execute Reset Transaction ===');

    // Send transaction with reset authorization
    const hash = await walletClient.sendTransaction({
      authorizationList: [resetAuthorization],
      to: account.address, // Send to self to trigger reset
      value: 0n,
      data: '0x', // Empty data
    });

    console.log('✅ Reset transaction sent successfully!');
    console.log('Transaction hash:', hash);
    console.log('View on Etherscan:', `https://sepolia.etherscan.io/tx/${hash}`);

    console.log('\n=== Step 3: Waiting for Transaction Confirmation ===');
    console.log('⏳ Waiting 10 seconds for transaction to be mined...');
    
    // Wait for transaction to be mined
    await new Promise(resolve => setTimeout(resolve, 10000));

    // Verify reset worked
    await verifyReset(publicClient, account.address);

  } catch (error) {
    console.error('❌ Reset transaction failed:', error.message);
    
    // Still try to verify current status
    console.log('\n=== Current Status Check ===');
    await verifyReset(publicClient, account.address);
  }
}

async function verifyReset(publicClient, accountAddress) {
  console.log('\n=== Step 4: Verify Reset ===');
  
  try {
    const codeAfterReset = await publicClient.getCode({ address: accountAddress });
    
    if (!codeAfterReset || codeAfterReset === '0x') {
      console.log('✅ SUCCESS: Delegation has been reset!');
      console.log('Account now has no code (back to normal EOA)');
    } else {
      console.log('⚠️  Delegation may not have been reset yet');
      console.log('Current code length:', codeAfterReset.length);
      console.log('ℹ️  Transaction may still be pending - try verification again in a few seconds');
    }

    // Additional info
    const balance = await publicClient.getBalance({ address: accountAddress });
    const nonce = await publicClient.getTransactionCount({ address: accountAddress });
    console.log('Current balance:', balance.toString(), 'wei');
    console.log('Current nonce:', nonce);

  } catch (error) {
    console.error('❌ Verification failed:', error.message);
  }
}

// Verification-only function for command line use
async function verifyResetOnly() {
  const account = privateKeyToAccount(process.env.PRIVATE_KEY);

  const publicClient = createPublicClient({
    chain: sepolia,
    transport: http(process.env.SEPOLIA_RPC_URL),
  });

  console.log('=== EIP-7702 Reset Verification ===');
  console.log('Account Address:', account.address);
  
  await verifyReset(publicClient, account.address);
}

// Run the function based on command line arguments
if (import.meta.url === `file://${process.argv[1]}`) {
  const args = process.argv.slice(2);
  
  if (args.includes('--verify-only') || args.includes('-v')) {
    verifyResetOnly().catch(console.error);
  } else {
    resetEIP7702Delegation().catch(console.error);
  }
}