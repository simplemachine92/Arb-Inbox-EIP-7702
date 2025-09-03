// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {SimpleSafeDelegateContract} from "../src/SimpleSafeDelegateContract.sol";

/**
 * @title DeployDelegateScript
 * @notice Deploys a SimpleSafeDelegateContract for use with EIP-7702 delegation
 * @dev This script deploys the implementation contract that an EOA can delegate to via EIP-7702.
 *      After deployment, use the JavaScript delegation script to perform the actual EIP-7702 delegation.
 *
 * Usage:
 *   1. Set PRIVATE_KEY and SEPOLIA_RPC_URL in .env
 *   2. Run: forge script script/DeployDelegate.s.sol:DeployDelegateScript --rpc-url sepolia --broadcast
 *   3. Copy the deployed contract address to IMPLEMENTATION_ADDRESS in .env
 *   4. Run: node delegation/delegate.js to perform EIP-7702 delegation
 */
contract DeployDelegateScript is Script {
    /// @notice The implementation contract that EOAs will delegate execution to
    SimpleSafeDelegateContract public implementation;

    /// @notice EOA address derived from the private key in environment variables
    address public userAddress;

    /// @notice Private key loaded from PRIVATE_KEY environment variable
    uint256 public userPrivateKey;

    /**
     * @notice Sets up the script by loading environment variables and displaying account info
     * @dev Loads PRIVATE_KEY from .env and derives the corresponding address
     */
    function setUp() public {
        // Load private key from environment (.env file)
        userPrivateKey = vm.envUint("PRIVATE_KEY");
        userAddress = vm.addr(userPrivateKey);

        console.log("=== EIP-7702 Implementation Deployment ===");
        console.log("Deployer Address:", userAddress);
        console.log("Deployer Balance:", userAddress.balance, "wei");
    }

    /**
     * @notice Deploys the SimpleSafeDelegateContract implementation
     * @dev This contract will be used as the implementation for EIP-7702 delegation.
     *      The deployed address should be added to .env as IMPLEMENTATION_ADDRESS.
     */
    function run() public {
        // Start broadcasting transactions using the loaded private key
        vm.startBroadcast(userPrivateKey);

        // Deploy the implementation contract for EIP-7702 delegation
        implementation = new SimpleSafeDelegateContract();

        console.log("SimpleSafeDelegateContract deployed successfully!");
        console.log("Implementation Address:", address(implementation));
        console.log("");
        console.log("Next steps:");
        console.log("1. Add this address to .env as IMPLEMENTATION_ADDRESS");
        console.log("2. Run: node delegation/delegate.js");

        vm.stopBroadcast();
    }
}
