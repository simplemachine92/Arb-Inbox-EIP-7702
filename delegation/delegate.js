// EIP-7702 Delegation Transaction Script following Viem guide
import { createWalletClient, createPublicClient, http } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { sepolia } from 'viem/chains';
import { config } from 'dotenv';

// Load environment variables
config();

async function sendEIP7702Transaction() {
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

  console.log('=== EIP-7702 Delegation Setup ===');
  console.log('Account Address:', account.address);
  console.log('Chain ID:', sepolia.id);

  const implementationAddress = process.env.IMPLEMENTATION_ADDRESS;

  if (!implementationAddress) {
    console.log('⚠️  IMPLEMENTATION_ADDRESS not found in environment variables');
    console.log('   Run the Foundry deploy script first to get the implementation address');
    return;
  }

  console.log('Implementation Address:', implementationAddress);

  // Get account balance
  const balance = await publicClient.getBalance({ address: account.address });
  console.log('Account Balance:', balance.toString(), 'wei');

  try {
    console.log('\n=== Step 1: Sign Authorization ===');

    // Step 3 from Viem guide: Authorize Contract Designation
    // Since we're self-executing (same account signing and executing), use executor: 'self'
    const authorization = await walletClient.signAuthorization({
      contractAddress: implementationAddress,
      executor: 'self', // Important: we're self-executing
    });

    console.log('✅ Authorization signed successfully');
    console.log('Authorization:', {
      contractAddress: authorization.contractAddress,
      chainId: authorization.chainId,
      nonce: authorization.nonce,
    });

    console.log('\n=== Step 2: Execute EIP-7702 Delegation Transaction ===');

    // Step 4 from Viem guide: Execute EIP-7702 transaction
    // Send a simple transaction with the authorization list to trigger delegation
    const hash = await walletClient.sendTransaction({
      authorizationList: [authorization],
      to: account.address, // Send to self to trigger delegation
      value: 0n,
      data: '0x', // Empty data - just trigger the delegation
    });

    console.log('✅ EIP-7702 delegation successful!');
    console.log('Transaction hash:', hash);
    console.log('View on Etherscan:', `https://sepolia.etherscan.io/tx/${hash}`);

    // Verify delegation worked
    console.log('\n=== Step 3: Verify Delegation ===');
    const codeAfter = await publicClient.getCode({ address: account.address });
    if (codeAfter && codeAfter !== '0x') {
      console.log('✅ Account now has delegated code!');
      console.log('Code length:', codeAfter.length);
    } else {
      console.log('⚠️  No code found - delegation may not have worked');
      console.log('ℹ️  Try running verification again in a few seconds: node delegation/delegate.js --verify-only');
    }

  } catch (error) {
    console.error('❌ EIP-7702 transaction failed:', error.message);

    // Fallback: try simple contract interaction
    console.log('\n=== Fallback: Direct Contract Interaction ===');
    try {
      const hash = await walletClient.sendTransaction({
        to: implementationAddress,
        value: 0n,
        data: '0x',
      });
      console.log('✅ Direct contract interaction successful');
      console.log('Transaction hash:', hash);
    } catch (fallbackError) {
      console.error('❌ Fallback also failed:', fallbackError.message);
      console.log('\nNote: EIP-7702 may not be supported by this RPC provider yet');
    }
  }
}

// Verification-only function
async function verifyDelegationOnly() {
  const account = privateKeyToAccount(process.env.PRIVATE_KEY);
  const implementationAddress = process.env.IMPLEMENTATION_ADDRESS;

  const publicClient = createPublicClient({
    chain: sepolia,
    transport: http(process.env.SEPOLIA_RPC_URL),
  });

  console.log('=== EIP-7702 Delegation Verification ===');
  console.log('Account Address:', account.address);
  console.log('Implementation Address:', implementationAddress);

  try {
    const codeAfter = await publicClient.getCode({ address: account.address });
    if (codeAfter && codeAfter !== '0x') {
      console.log('✅ SUCCESS: Account has delegated code!');
      console.log('Code length:', codeAfter.length);
      console.log('Code preview:', codeAfter.slice(0, 42) + '...');
    } else {
      console.log('❌ FAILED: No code found at account address');
      console.log('The delegation may not have worked or the transaction may still be pending');
    }

    // Additional info
    const balance = await publicClient.getBalance({ address: account.address });
    const nonce = await publicClient.getTransactionCount({ address: account.address });
    console.log('Current balance:', balance.toString(), 'wei');
    console.log('Current nonce:', nonce);

  } catch (error) {
    console.error('❌ Verification failed:', error.message);
  }
}

// Run the function if this script is executed directly
if (import.meta.url === `file://${process.argv[1]}`) {
  const args = process.argv.slice(2);

  if (args.includes('--verify-only') || args.includes('-v')) {
    verifyDelegationOnly().catch(console.error);
  } else {
    sendEIP7702Transaction().catch(console.error);
  }
}