// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "./EIP7702Utils.sol";

/**
 * @title EIP7702UtilsTest
 * @notice Comprehensive tests for EIP-7702 account simulation utilities
 * @dev Tests all helper functions and verifies correct EIP-7702 bytecode patterns
 */
contract EIP7702UtilsTest is EIP7702Utils {
    
    address constant DELEGATE_ADDRESS = 0x1234567890123456789012345678901234567890;
    address constant ANOTHER_DELEGATE = 0x9876543210987654321098765432109876543210;
    
    function setUp() public {
        // Test setup - no special initialization needed
    }
    
    /**
     * @notice Test EIP-7702 bytecode creation
     * Requirements: 2.1 - Create EIP-7702 bytecode pattern (0xef0100 + 20 bytes)
     */
    function test_CreateEIP7702Bytecode() public {
        bytes memory bytecode = createEIP7702Bytecode(DELEGATE_ADDRESS);
        
        // Verify total length is 23 bytes
        assertEq(bytecode.length, EIP7702_BYTECODE_SIZE, "Bytecode should be 23 bytes");
        
        // Verify magic bytes (first 3 bytes)
        assertEq(bytes3(bytecode), EIP7702_MAGIC, "Should start with EIP-7702 magic bytes");
        
        // Verify delegate address (bytes 3-22)
        bytes memory delegateBytes = new bytes(20);
        for (uint i = 0; i < 20; i++) {
            delegateBytes[i] = bytecode[3 + i];
        }
        address extractedDelegate = address(bytes20(delegateBytes));
        assertEq(extractedDelegate, DELEGATE_ADDRESS, "Should contain correct delegate address");
    }
    
    /**
     * @notice Test setting up EIP-7702 account using vm.etch()
     * Requirements: 2.1, 2.2 - Use vm.etch() to set bytecode on test accounts
     */
    function test_SetupEIP7702Account() public {
        address testAccount = makeAddr("testEIP7702");
        
        // Initially should be EOA (no code)
        assertEq(getCodeSize(testAccount), 0, "Should start as EOA");
        
        // Set up as EIP-7702 account
        setupEIP7702Account(testAccount, DELEGATE_ADDRESS);
        
        // Verify bytecode was set correctly
        assertEq(getCodeSize(testAccount), EIP7702_BYTECODE_SIZE, "Should have 23 bytes of code");
        assertTrue(verifyEIP7702Account(testAccount), "Should be valid EIP-7702 account");
    }
    
    /**
     * @notice Test creating new EIP-7702 account with generated address
     * Requirements: 2.1, 2.2 - Create accounts with EIP-7702 bytecode pattern
     */
    function test_CreateEIP7702Account() public {
        address eip7702Account = createEIP7702Account("newEIP7702", DELEGATE_ADDRESS);
        
        // Verify account was created correctly
        assertEq(getCodeSize(eip7702Account), EIP7702_BYTECODE_SIZE, "Should have 23 bytes of code");
        assertTrue(verifyEIP7702Account(eip7702Account), "Should be valid EIP-7702 account");
        assertEq(getEIP7702Delegate(eip7702Account), DELEGATE_ADDRESS, "Should have correct delegate");
    }
    
    /**
     * @notice Test EIP-7702 account verification
     * Requirements: 2.2, 2.3 - Verify accounts have correct 23-byte size and magic bytes
     */
    function test_VerifyEIP7702Account() public {
        address validAccount = createEIP7702Account("valid", DELEGATE_ADDRESS);
        address invalidAccount = makeAddr("invalid");
        
        // Valid EIP-7702 account should pass verification
        assertTrue(verifyEIP7702Account(validAccount), "Valid account should pass verification");
        
        // EOA should fail verification
        assertFalse(verifyEIP7702Account(invalidAccount), "EOA should fail verification");
        
        // Account with wrong bytecode size should fail (use regular contract bytecode)
        bytes memory contractCode = hex"608060405234801561001057600080fd5b50"; // Regular contract
        vm.etch(invalidAccount, contractCode);
        assertFalse(verifyEIP7702Account(invalidAccount), "Wrong size should fail verification");
        
        // Account with wrong magic bytes should fail
        bytes memory wrongMagic = createEIP7702Bytecode(DELEGATE_ADDRESS);
        wrongMagic[1] = 0x02; // Change magic bytes
        vm.etch(invalidAccount, wrongMagic);
        assertFalse(verifyEIP7702Account(invalidAccount), "Wrong magic should fail verification");
    }
    
    /**
     * @notice Test extracting delegate address from EIP-7702 account
     * Requirements: 2.1, 2.3 - Verify correct bytecode pattern and delegate extraction
     */
    function test_GetEIP7702Delegate() public {
        address eip7702Account = createEIP7702Account("delegateTest", DELEGATE_ADDRESS);
        
        // Should extract correct delegate address
        address extractedDelegate = getEIP7702Delegate(eip7702Account);
        assertEq(extractedDelegate, DELEGATE_ADDRESS, "Should extract correct delegate address");
        
        // Test with different delegate
        address anotherAccount = createEIP7702Account("anotherDelegate", ANOTHER_DELEGATE);
        assertEq(getEIP7702Delegate(anotherAccount), ANOTHER_DELEGATE, "Should extract different delegate");
    }
    
    /**
     * @notice Test that getEIP7702Delegate reverts for invalid accounts
     * Requirements: 2.3 - Proper error handling for invalid accounts
     */
    function test_GetEIP7702DelegateRevert() public {
        address eoaAccount = makeAddr("eoa");
        
        // This should revert - we'll test it by catching the revert
        try this.getEIP7702Delegate(eoaAccount) {
            fail("Should have reverted for EOA account");
        } catch Error(string memory reason) {
            assertEq(reason, "Account is not a valid EIP-7702 account", "Should revert with correct message");
        }
    }
    
    /**
     * @notice Test account type detection
     * Requirements: 2.5 - Test different account types with real contract
     */
    function test_GetAccountType() public {
        // Test EOA (no code)
        address eoaAccount = makeAddr("eoa");
        assertEq(getAccountType(eoaAccount), 0, "EOA should return type 0");
        
        // Test EIP-7702 account
        address eip7702Account = createEIP7702Account("eip7702", DELEGATE_ADDRESS);
        assertEq(getAccountType(eip7702Account), 1, "EIP-7702 should return type 1");
        
        // Test regular contract
        address contractAccount = makeAddr("contract");
        vm.etch(contractAccount, hex"608060405234801561001057600080fd5b50"); // Some contract bytecode
        assertEq(getAccountType(contractAccount), 2, "Contract should return type 2");
    }
    
    /**
     * @notice Test bytecode size checking
     * Requirements: 2.2 - Verify accounts have correct 23-byte size
     */
    function test_GetCodeSize() public {
        address eoaAccount = makeAddr("eoa");
        address eip7702Account = createEIP7702Account("eip7702", DELEGATE_ADDRESS);
        address contractAccount = makeAddr("contract");
        vm.etch(contractAccount, hex"608060405234801561001057600080fd5b50");
        
        assertEq(getCodeSize(eoaAccount), 0, "EOA should have 0 bytes");
        assertEq(getCodeSize(eip7702Account), 23, "EIP-7702 should have 23 bytes");
        assertTrue(getCodeSize(contractAccount) > 0, "Contract should have > 0 bytes");
        assertTrue(getCodeSize(contractAccount) != 23, "Contract should not have exactly 23 bytes");
    }
    
    /**
     * @notice Test hasCode functionality
     * Requirements: 2.2, 2.3 - Verify code detection works correctly
     */
    function test_HasCode() public {
        address eoaAccount = makeAddr("eoa");
        address eip7702Account = createEIP7702Account("eip7702", DELEGATE_ADDRESS);
        address contractAccount = makeAddr("contract");
        vm.etch(contractAccount, hex"608060405234801561001057600080fd5b50");
        
        assertFalse(hasCode(eoaAccount), "EOA should not have code");
        assertTrue(hasCode(eip7702Account), "EIP-7702 should have code");
        assertTrue(hasCode(contractAccount), "Contract should have code");
    }
    
    /**
     * @notice Test edge cases and error conditions
     * Requirements: 2.1, 2.2, 2.3 - Handle edge cases properly
     */
    function test_EdgeCases() public {
        // Test with zero address as delegate
        address zeroDelegate = createEIP7702Account("zeroDelegate", address(0));
        assertTrue(verifyEIP7702Account(zeroDelegate), "Should work with zero address delegate");
        assertEq(getEIP7702Delegate(zeroDelegate), address(0), "Should extract zero address");
        
        // Test with max address as delegate
        address maxDelegate = createEIP7702Account("maxDelegate", address(type(uint160).max));
        assertTrue(verifyEIP7702Account(maxDelegate), "Should work with max address delegate");
        assertEq(getEIP7702Delegate(maxDelegate), address(type(uint160).max), "Should extract max address");
        
        // Test multiple accounts with same delegate
        address account1 = createEIP7702Account("account1", DELEGATE_ADDRESS);
        address account2 = createEIP7702Account("account2", DELEGATE_ADDRESS);
        assertEq(getEIP7702Delegate(account1), DELEGATE_ADDRESS, "Account1 should have correct delegate");
        assertEq(getEIP7702Delegate(account2), DELEGATE_ADDRESS, "Account2 should have correct delegate");
        assertTrue(account1 != account2, "Accounts should have different addresses");
    }
    
    /**
     * @notice Test constants and magic values
     * Requirements: 2.1, 2.3 - Verify magic bytes and size constants
     */
    function test_Constants() public {
        assertEq(uint24(EIP7702_MAGIC), 0xef0100, "Magic bytes should be 0xef0100");
        assertEq(EIP7702_BYTECODE_SIZE, 23, "Bytecode size should be 23");
        
        // Verify magic bytes in created bytecode
        bytes memory bytecode = createEIP7702Bytecode(DELEGATE_ADDRESS);
        bytes3 extractedMagic;
        assembly {
            extractedMagic := mload(add(bytecode, 0x20))
        }
        assertEq(extractedMagic, EIP7702_MAGIC, "Created bytecode should have correct magic");
    }
}