// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../lib/nitro-contracts/src/bridge/IInbox.sol";

import {SimpleDelegateContract} from "../src/SimpleDelegateContract.sol";

/**
 * @title ArbitrumInboxAliasingWithAA
 * @notice Basic test suite to show how EIP-7702 Code setting for EOA's can be interpreted by Arbs Inbox
 * @dev Showcases that aliasing occurs for accounts that have "set their code" via 7702 with multiple tx types.
 */
contract ArbitrumInboxAliasingWithAA is Test {
    /// @dev event emitted when a inbox message is added to the Bridge's delayed accumulator
    event InboxMessageDelivered(uint256 indexed messageNum, bytes data);

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
     * @notice Sets up the test environment with mainnet fork and test accounts
     * @dev Creates a mainnet fork, initializes test accounts, deploys contracts, and sets up labels
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

    /**
     * @notice Tests that EOA with EIP-7702 code delegation gets aliased even with normal transactions
     * @dev Demonstrates how a user who has set their account code will be aliased, even with a normal EOA originating tx.
     *      Verifies that Alice's address is aliased when depositing ETH to Arbitrum Inbox after setting delegation code.
     */
    function test_InboxCallNormalTransferWithCodeSet() public {
        // We still want to include signing and attaching a delegation to show differences.
        // Alice signs and attaches the delegation in one step (eliminating the need for separate signing).
        vm.signAndAttachDelegation(address(implementation), ALICE_PK);

        // Verify that Alice's account now behaves as a smart contract.
        bytes memory code = address(ALICE_ADDRESS).code;
        require(code.length > 0, "no code written to Alice");

        // Setup to broadcast the delegated call
        vm.deal(ALICE_ADDRESS, 1 ether);

        // Apply aliasing to compare emitted event
        address expectedSender = applyL1ToL2Alias(address(ALICE_ADDRESS));

        // Our packed data here follows the depositEth() functions 'abi.encodePacked(dest, msg.value)'
        // Using this method since "sender" in MessageDelivered seems to always be aliased.
        // This gives us the emitted "destination" according to Inbox
        vm.expectEmit(false, false, false, true);
        emit InboxMessageDelivered(0, abi.encodePacked(expectedSender, uint256(1 ether)));

        // Second param ensures that tx.origin == msg.sender, which is the other check in Inbox besides code length
        vm.prank(ALICE_ADDRESS, ALICE_ADDRESS);
        arbitrumInbox.depositEth{value: 1 ether}();
    }

    /**
     * @notice Tests that EOA with EIP-7702 code delegation gets aliased when executing delegated calls
     * @dev Demonstrates how a user who has set their account code, and uses AA tx (code executing) will be aliased (expected).
     *      Verifies that Alice's address is aliased when making delegated calls to Arbitrum Inbox through the delegation contract.
     */
    function test_DelegatedInboxCallWithCodeSet() public {
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

        // Our packed data here follows the depositEth() functions 'abi.encodePacked(dest, msg.value)'
        // Using this method since "sender" in MessageDelivered seems to always be aliased.
        // This gives us the emitted "destination" according to Inbox
        vm.expectEmit(false, false, false, true);
        emit InboxMessageDelivered(0, abi.encodePacked(expectedSender, uint256(1 ether)));

        // Call the inbox via delegated call
        // 7702: "All code executing operations must load and execute the code pointed to by the delegation."
        SimpleDelegateContract(payable(ALICE_ADDRESS)).execute(calls);
    }

    function test_InboxCallNormalTransferWithoutCodeSet() public {
        // Shows normal inbox functionality, acting as our "control"

        // Setup to broadcast the delegated call
        vm.deal(ALICE_ADDRESS, 1 ether);

        // Our packed data here follows the depositEth() functions 'abi.encodePacked(dest, msg.value)'
        // Using this method since "sender" in MessageDelivered seems to always be aliased.
        vm.expectEmit(false, false, false, true);
        emit InboxMessageDelivered(0, abi.encodePacked(ALICE_ADDRESS, uint256(1 ether)));

        // Non-delegated call but with 7702 code set
        // Second param ensures that tx.origin == msg.sender, which is the other check in Inbox besides code length
        vm.prank(ALICE_ADDRESS, ALICE_ADDRESS);
        arbitrumInbox.depositEth{value: 1 ether}();
    }

    function test_InboxCallNormalTransferWithoutCodeSetButSigned() public {
        // Signs the delegation but doesn't attach it- Another control.
        // Shows the distinction between how forge handles creating a delegation, and creates another tx under the hood to fully delegate.
        vm.signDelegation(address(implementation), ALICE_PK);

        // Setup to broadcast the delegated call
        vm.deal(ALICE_ADDRESS, 1 ether);

        // Our packed data here follows the depositEth() functions 'abi.encodePacked(dest, msg.value)'
        // Using this method since "sender" in MessageDelivered seems to always be aliased.
        // This gives us the emitted "destination" according to Inbox
        vm.expectEmit(false, false, false, true);
        emit InboxMessageDelivered(0, abi.encodePacked(ALICE_ADDRESS, uint256(1 ether)));

        // Non-delegated call but with 7702 code set
        // Second param ensures that tx.origin == msg.sender, which is the other check in Inbox besides code length
        vm.prank(ALICE_ADDRESS, ALICE_ADDRESS);
        arbitrumInbox.depositEth{value: 1 ether}();
    }

    function test_InboxCallSubsequent7702Calls() public {
        // Attach our signed delegation via their under the hood tx to do so. (attach)
        vm.signAndAttachDelegation(address(implementation), ALICE_PK);

        // Apply aliasing to compare emitted event
        address expectedSender = applyL1ToL2Alias(address(ALICE_ADDRESS));

        // Setup to broadcast the delegated call
        vm.deal(ALICE_ADDRESS, 1 ether);

        // Our packed data here follows the depositEth() functions 'abi.encodePacked(dest, msg.value)'
        // Using this method since "sender" in MessageDelivered seems to always be aliased.
        // This gives us the emitted "destination" according to Inbox
        vm.expectEmit(false, false, false, true);
        emit InboxMessageDelivered(0, abi.encodePacked(expectedSender, uint256(1 ether)));

        // Non-delegated call but with 7702 code set
        // Second param ensures that tx.origin == msg.sender, which is the other check in Inbox besides code length
        vm.prank(ALICE_ADDRESS, ALICE_ADDRESS);
        arbitrumInbox.depositEth{value: 1 ether}();

        // === Second Transaction ===
        vm.deal(ALICE_ADDRESS, 1 ether);

        // Our packed data here follows the depositEth() functions 'abi.encodePacked(dest, msg.value)'
        // Using this method since "sender" in MessageDelivered seems to always be aliased.
        vm.expectEmit(false, false, false, true);
        emit InboxMessageDelivered(0, abi.encodePacked(expectedSender, uint256(1 ether)));

        // Non-delegated call but with 7702 code set
        // Second param ensures that tx.origin == msg.sender, which is the other check in Inbox besides code length
        vm.prank(ALICE_ADDRESS, ALICE_ADDRESS);
        arbitrumInbox.depositEth{value: 1 ether}();
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
