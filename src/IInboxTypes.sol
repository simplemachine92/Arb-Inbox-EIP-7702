// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IInboxTypes
 * @notice Shared types, interfaces, events, and errors for inbox contracts
 * @dev Contains common definitions used by both VulnerableInbox and FixedInbox
 */

/**
 * @notice Enumeration of different account types for proper aliasing logic
 * @dev Used by FixedInbox to determine correct L1→L2 address mapping
 */
enum AccountType {
    EOA,           // Externally Owned Account (no code)
    DelegatedEOA,  // EIP-7702 delegated account (23 bytes, 0xef0100 prefix)
    Contract       // Regular smart contract (any other code)
}

/**
 * @title IInboxBase
 * @notice Base interface for all inbox contract implementations
 */
interface IInboxBase {
    /**
     * @notice Processes a deposit from L1 to L2
     * @return l2Recipient The calculated L2 address where funds will be sent
     */
    function deposit() external payable returns (address l2Recipient);
    
    /**
     * @notice Calculates the L2 address for a given L1 address
     * @param l1Address The L1 address to calculate L2 mapping for
     * @return The corresponding L2 address (aliased or direct)
     */
    function calculateL2Address(address l1Address) external pure returns (address);
}

/**
 * @title IVulnerableInbox
 * @notice Interface for the vulnerable inbox implementation
 * @dev Represents current Arbitrum behavior with EIP-7702 vulnerability
 */
interface IVulnerableInbox is IInboxBase {
    /**
     * @notice Checks if an address is a contract using basic extcodesize
     * @param account The address to check
     * @return True if account has code (vulnerable to EIP-7702 false positive)
     */
    function isContract(address account) external view returns (bool);
}

/**
 * @title IFixedInbox
 * @notice Interface for the fixed inbox implementation with EIP-7702 detection
 * @dev Provides enhanced account type detection to prevent aliasing vulnerability
 */
interface IFixedInbox is IInboxBase {
    /**
     * @notice Determines the account type with proper EIP-7702 detection
     * @param account The address to analyze
     * @return The detected account type (EOA, DelegatedEOA, or Contract)
     */
    function getAccountType(address account) external view returns (AccountType);
    
    /**
     * @notice Checks if an address is an EIP-7702 delegated account
     * @param account The address to check
     * @return True if account has EIP-7702 bytecode pattern (0xef0100 + 23 bytes)
     */
    function isEIP7702(address account) external view returns (bool);
}

/**
 * @title InboxEvents
 * @notice Common events emitted by inbox contracts
 */
interface InboxEvents {
    /**
     * @notice Emitted when a deposit is initiated from L1 to L2
     * @param l1Sender The address that initiated the deposit on L1
     * @param l2Recipient The calculated L2 address where funds will be sent
     * @param amount The amount of ETH deposited
     * @param senderType The detected account type of the sender (for FixedInbox)
     */
    event DepositInitiated(
        address indexed l1Sender,
        address indexed l2Recipient,
        uint256 amount,
        AccountType senderType
    );
    
    /**
     * @notice Emitted when a deposit is initiated (vulnerable version without type)
     * @param l1Sender The address that initiated the deposit on L1
     * @param l2Recipient The calculated L2 address where funds will be sent
     * @param amount The amount of ETH deposited
     */
    event DepositInitiatedLegacy(
        address indexed l1Sender,
        address indexed l2Recipient,
        uint256 amount
    );
}

/**
 * @title InboxErrors
 * @notice Common errors thrown by inbox contracts
 */
interface InboxErrors {
    /**
     * @notice Thrown when account type detection fails or produces unexpected results
     * @param account The address that failed detection
     * @param detected The account type that was detected
     * @param expected The account type that was expected
     */
    error InvalidAccountType(address account, AccountType detected, AccountType expected);
    
    /**
     * @notice Thrown when insufficient balance for deposit operation
     * @param required The amount required for the operation
     * @param available The amount actually available
     */
    error InsufficientBalance(uint256 required, uint256 available);
    
    /**
     * @notice Thrown when EIP-7702 detection fails due to invalid bytecode
     * @param account The address that failed EIP-7702 detection
     * @param actualCode The actual bytecode found (first 3 bytes)
     */
    error EIP7702DetectionFailed(address account, bytes3 actualCode);
    
    /**
     * @notice Thrown when deposit amount is zero
     */
    error ZeroDepositAmount();
}