// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {Script} from "forge-std/Script.sol";

import {LockManager} from "meridian/LockManager.sol";

/// @dev Upgrade the LockManager contract
contract Upgrade is Script {
    error DeployerInvalid();
    error LockManagerOwnerInvalid();

    /// @notice Upgrade contracts
    /// @param lockManagerProxy Address of the LockManager proxy
    function run(address lockManagerProxy) external {
        vm.startBroadcast();

        (, address deployer,) = vm.readCallers();

        LockManager lockManager = LockManager(lockManagerProxy);
        if (lockManager.owner() != deployer) revert DeployerInvalid();

        // Upgrade the LockManager
        address ownerBefore = lockManager.owner();

        lockManager.upgradeToAndCall(address(new LockManager()), "");

        // Validate upgrade
        if (lockManager.owner() != ownerBefore) revert LockManagerOwnerInvalid();

        vm.stopBroadcast();
    }

    // Exclude from coverage report
    function test() public {}
}
