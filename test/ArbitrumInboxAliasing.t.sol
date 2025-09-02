// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../lib/nitro-contracts/src/bridge/IInbox.sol";

import {SimpleDelegateContract} from "../src/SimpleDelegateContract.sol";

/**
 * @title ArbitrumInboxAliasingWithAA
 * @notice Basic test suite to verify account setup without requiring mainnet fork
 * @dev This test verifies that our account setup works correctly before testing against real contract
 */
contract ArbitrumInboxAliasingWithAA is Test {
    // IBridge mimic event
    event MessageDelivered(
        uint256 indexed messageIndex,
        bytes32 indexed beforeInboxAcc,
        address inbox,
        uint8 kind,
        address sender,
        bytes32 messageDataHash,
        uint256 baseFeeL1,
        uint64 timestamp
    );

    // the identifiers of the forks
    uint256 mainnetFork;

    /// @notice Real Arbitrum Inbox contract address on Ethereum mainnet
    address public constant ARBITRUM_INBOX_ADDRESS = 0x4Dbd4fc535Ac27206064B68FfCf827b0A60BAB3f;

    /// @notice Interface to the real Arbitrum Inbox contract
    IInbox public arbitrumInbox;

    // Alice's address and private key (EOA with no initial contract code).
    address ALICE_ADDRESS;
    uint256 ALICE_PK;

    // The contract that Alice will delegate execution to.
    SimpleDelegateContract public implementation;

    /**
     * @notice Set up test environment with test accounts (no fork needed)
     */
    function setUp() public {
        // Fork setup
        string memory MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
        mainnetFork = vm.createSelectFork(MAINNET_RPC_URL);

        // Ensure we are on mainnet fork
        assertEq(vm.activeFork(), mainnetFork);

        (ALICE_ADDRESS, ALICE_PK) = makeAddrAndKey("alicewallice321908");

        // Deploy the delegation contract (Alice will delegate calls to this contract).
        implementation = new SimpleDelegateContract();

        // Connect to the real Arbitrum Inbox contract
        arbitrumInbox = IInbox(ARBITRUM_INBOX_ADDRESS);

        // Check if we're connected to the correct contract
        if (address(arbitrumInbox).code.length > 0) {
            console.log("=== Mainnet Fork Active ===");
            console.log("Arbitrum Inbox Address:", ARBITRUM_INBOX_ADDRESS);
        } else {
            console.log("=== Warning: Arbitrum Inbox contract not found on fork ===");
        }

        // Labels for brevity
        vm.label(address(implementation), "DEL CONTRACT");
        vm.label(ALICE_ADDRESS, "ALICE EOA");
        vm.label(address(arbitrumInbox), "ARB INBOX");
    }

    function test_DelegatedInboxCall() public {
        // Alice signs and attaches the delegation in one step (eliminating the need for separate signing).
        vm.signAndAttachDelegation(address(implementation), ALICE_PK);

        // Verify that Alice's account now behaves as a smart contract.
        bytes memory code = address(ALICE_ADDRESS).code;
        require(code.length > 0, "no code written to Alice");

        // Setup to broadcast the delegated call
        vm.deal(ALICE_ADDRESS, 1 ether);
        vm.broadcast(ALICE_ADDRESS);

        // "Delegated" call to inbox (this would sometimes come from other authorized EOS etc)
        // in this case just executing Alice's own code by Alice
        SimpleDelegateContract.Call[] memory calls = new SimpleDelegateContract.Call[](1);
        calls[0] = SimpleDelegateContract.Call({
            to: payable(address(arbitrumInbox)),
            data: abi.encodeWithSelector(arbitrumInbox.depositEth.selector),
            value: 1 ether // Amount of ETH to send
        });

        // Apply aliasing to compare emitted event
        address expectedSender = applyL1ToL2Alias(address(ALICE_ADDRESS));

        // Record all logs
        vm.recordLogs();

        // Call the inbox via delegated call
        // 7702: "All code executing operations must load and execute the code pointed to by the delegation."
        SimpleDelegateContract(payable(ALICE_ADDRESS)).execute(calls);

        // Get the logs and check manually
        Vm.Log[] memory logs = vm.getRecordedLogs();

        bool found = false;
        for (uint256 i = 0; i < logs.length; i++) {
            // Check if this is the MessageDelivered event
            if (
                logs[i].topics[0]
                    == keccak256("MessageDelivered(uint256,bytes32,address,uint8,address,bytes32,uint256,uint64)")
            ) {
                // Decode the data to get the sender
                (,, address sender,,,) = abi.decode(logs[i].data, (address, uint8, address, bytes32, uint256, uint64));

                // Check only the sender
                if (sender == expectedSender) {
                    found = true;
                    console.log("Found event with correct sender:", sender);
                    break;
                }
            }
        }

        // Assert we found the log or throw
        assertTrue(found, "Event with expected sender not found");

        // Alice technically has "code" at her address during this flow, so her address on L2 was aliased.
        assertNotEq(ALICE_ADDRESS, expectedSender);
    }

    /**
     * @notice Apply L1 to L2 address aliasing (Arbitrum's formula)
     */
    function applyL1ToL2Alias(address l1Address) public pure returns (address) {
        uint160 offset = uint160(0x1111000000000000000000000000000000001111);
        unchecked {
            return address(uint160(l1Address) + offset);
        }
    }

    /**
     * @notice Helper to check if string is empty
     */
    function _isEmptyString(string memory str) internal pure returns (bool) {
        return bytes(str).length == 0;
    }
}
