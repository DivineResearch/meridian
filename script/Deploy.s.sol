// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {Script} from "forge-std/Script.sol";

import {ERC1967Proxy} from "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {LockManager} from "meridian/LockManager.sol";

/// @dev Deploy the LockManager contract
contract Deploy is Script {
    address internal constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    /// @notice Deploy contracts
    function run() external {
        vm.startBroadcast();

        (, address deployer,) = vm.readCallers();

        // Deploy the LockManager as proxy
        new ERC1967Proxy(
            address(new LockManager()), abi.encodeWithSignature("initialize(address,address)", deployer, PERMIT2)
        );

        vm.stopBroadcast();
    }

    // Exclude from coverage report
    function test() public {}
}
