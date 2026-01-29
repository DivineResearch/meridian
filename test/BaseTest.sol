// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";

/// @title BaseTest
/// @notice Shared test setup and helpers for Mutex protocol tests
abstract contract BaseTest is Test {
    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    address internal constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address internal constant USDC = 0x79A02482A880bCE3F13e09Da970dC34db4CD24d1;
    address internal constant WLD = 0x2cFc85d8E48F8EAB294be644d9E25C3030863003;

    /*//////////////////////////////////////////////////////////////
                              TEST ACTORS
    //////////////////////////////////////////////////////////////*/

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal partner = makeAddr("partner");
    address internal owner = makeAddr("owner");

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        vm.label(PERMIT2, "Permit2");
        vm.label(USDC, "USDC");
        vm.label(WLD, "WLD");
    }
}
