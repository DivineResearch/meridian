// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {BaseTest} from "../BaseTest.sol";

/// @title BaseForkTest
/// @notice Base contract for fork tests against World Chain
abstract contract BaseForkTest is BaseTest {
    uint256 internal constant FORK_BLOCK = 16_642_178;

    function setUp() public virtual override {
        vm.createSelectFork(vm.envString("CONTRACTS_RPC_URL"), FORK_BLOCK);
        _setupLabels();
        _setupPrivateKeys();
        _deployLockManager();
        // No _setupMocks() — use real Permit2 and tokens
    }
}
