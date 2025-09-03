// EIP-7702 Delegation Verification Script
import { createPublicClient, http } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { sepolia } from 'viem/chains';
import { config } from 'dotenv';

// Load environment variables
config();

async function verifyDelegation() {
  // Validate environment variables
  if (!process.env.PRIVATE_KEY) {
    throw new Error('PRIVATE_KEY not found in environment variables');
  }
  if (!process.env.SEPOLIA_RPC_URL) {
    throw new Error('SEPOLIA_RPC_URL not found in environment variables');
  }

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
    // Check if the account has code (delegated)
    const accountCode = await publicClient.getBytecode({ address: account.address });
    
    if (accountCode && accountCode !== '0x') {
      console.log('✅ SUCCESS: Account has delegated code!');
      console.log('Code length:', accountCode.length);
      console.log('Code preview:', accountCode.slice(0, 42) + '...');
      
      // Compare with implementation contract code
      if (implementationAddress) {
        const implementationCode = await publicClient.getBytecode({ address: implementationAddress });
        console.log('\n=== Code Comparison ===');
        console.log('Implementation code length:', implementationCode?.length || 0);
        
        if (accountCode === implementationCode) {
          console.log('✅ Account code matches implementation exactly');
        } else {
          console.log('ℹ️  Account code differs from implementation (this is expected for EIP-7702)');
        }
      }
    } else {
      console.log('❌ FAILED: No code found at account address');
      console.log('The delegation may not have worked or the transaction may still be pending');
      
      // Check account balance to see if it exists
      const balance = await publicClient.getBalance({ address: account.address });
      console.log('Account balance:', balance.toString(), 'wei');
      
      if (balance > 0n) {
        console.log('ℹ️  Account exists but has no code - delegation not active');
      }
    }

    // Additional checks
    console.log('\n=== Additional Information ===');
    const balance = await publicClient.getBalance({ address: account.address });
    const nonce = await publicClient.getTransactionCount({ address: account.address });
    
    console.log('Current balance:', balance.toString(), 'wei');
    console.log('Current nonce:', nonce);

  } catch (error) {
    console.error('❌ Verification failed:', error.message);
  }
}

// Run the verification
verifyDelegation().catch(console.error);