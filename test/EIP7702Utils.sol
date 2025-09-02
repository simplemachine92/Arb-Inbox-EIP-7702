// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

/**
 * @title EIP7702Utils
 * @notice Utility functions for creating and managing EIP-7702 account simulations in tests
 * @dev This contract provides helper functions to simulate EIP-7702 delegated accounts
 *      using Forge's vm.etch() functionality for testing purposes.
 */
contract EIP7702Utils is Test {
    
    /// @notice EIP-7702 magic bytes prefix (0xef0100)
    bytes3 public constant EIP7702_MAGIC = 0xef0100;
    
    /// @notice Expected bytecode size for EIP-7702 accounts (23 bytes total)
    uint256 public constant EIP7702_BYTECODE_SIZE = 23;
    
    /**
     * @notice Creates EIP-7702 bytecode pattern
     * @param delegateAddress The 20-byte address to delegate to
     * @return bytecode The complete 23-byte EIP-7702 bytecode
     * @dev Format: 0xef0100 (3 bytes) + delegateAddress (20 bytes) = 23 bytes total
     */
    function createEIP7702Bytecode(address delegateAddress) public pure returns (bytes memory) {
        bytes memory bytecode = new bytes(23);
        // Set magic bytes
        bytecode[0] = 0xef;
        bytecode[1] = 0x01;
        bytecode[2] = 0x00;
        // Set delegate address (20 bytes starting at position 3)
        bytes20 addrBytes = bytes20(delegateAddress);
        for (uint i = 0; i < 20; i++) {
            bytecode[3 + i] = addrBytes[i];
        }
        return bytecode;
    }
    
    /**
     * @notice Sets up an account as an EIP-7702 delegated account
     * @param account The account address to convert to EIP-7702
     * @param delegateAddress The address this account delegates to
     * @dev Uses vm.etch() to set the EIP-7702 bytecode pattern on the account
     */
    function setupEIP7702Account(address account, address delegateAddress) public {
        bytes memory eip7702Code = createEIP7702Bytecode(delegateAddress);
        vm.etch(account, eip7702Code);
    }
    
    /**
     * @notice Creates a new EIP-7702 account with a generated address
     * @param label Label for the generated address (used with makeAddr)
     * @param delegateAddress The address this account delegates to
     * @return account The address of the created EIP-7702 account
     */
    function createEIP7702Account(string memory label, address delegateAddress) public returns (address) {
        address account = makeAddr(label);
        setupEIP7702Account(account, delegateAddress);
        return account;
    }
    
    /**
     * @notice Verifies that an account has valid EIP-7702 bytecode
     * @param account The account to verify
     * @return isValid True if the account has valid EIP-7702 bytecode
     */
    function verifyEIP7702Account(address account) public view returns (bool) {
        // Check bytecode size is exactly 23 bytes
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        
        if (size != EIP7702_BYTECODE_SIZE) {
            return false;
        }
        
        // Check magic bytes (first 3 bytes should be 0xef0100)
        bytes memory code = new bytes(3);
        assembly {
            extcodecopy(account, add(code, 0x20), 0, 3)
        }
        
        return code[0] == 0xef && code[1] == 0x01 && code[2] == 0x00;
    }
    
    /**
     * @notice Extracts the delegate address from an EIP-7702 account
     * @param account The EIP-7702 account to extract from
     * @return delegateAddress The address this account delegates to
     * @dev Reverts if the account is not a valid EIP-7702 account
     */
    function getEIP7702Delegate(address account) public view returns (address) {
        require(verifyEIP7702Account(account), "Account is not a valid EIP-7702 account");
        
        // Get the full bytecode
        bytes memory code = new bytes(23);
        assembly {
            extcodecopy(account, add(code, 0x20), 0, 23)
        }
        
        // Extract the 20-byte delegate address (bytes 3-22)
        bytes memory delegateBytes = new bytes(20);
        for (uint i = 0; i < 20; i++) {
            delegateBytes[i] = code[3 + i];
        }
        
        return address(bytes20(delegateBytes));
    }
    
    /**
     * @notice Checks if an address appears to be a contract (has code)
     * @param account The account to check
     * @return hasCode True if the account has bytecode
     */
    function hasCode(address account) public view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
    
    /**
     * @notice Gets the bytecode size of an account
     * @param account The account to check
     * @return size The size of the account's bytecode in bytes
     */
    function getCodeSize(address account) public view returns (uint256) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size;
    }
    
    /**
     * @notice Determines the account type based on bytecode analysis
     * @param account The account to analyze
     * @return accountType 0=EOA, 1=EIP7702, 2=Contract
     */
    function getAccountType(address account) public view returns (uint8) {
        uint256 size = getCodeSize(account);
        
        // No code = EOA
        if (size == 0) {
            return 0; // EOA
        }
        
        // EIP-7702 = exactly 23 bytes with correct magic
        if (size == EIP7702_BYTECODE_SIZE && verifyEIP7702Account(account)) {
            return 1; // EIP7702
        }
        
        // Everything else = Contract
        return 2; // Contract
    }
}