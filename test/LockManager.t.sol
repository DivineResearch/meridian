// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {BaseTest} from "./BaseTest.sol";
import {ILockManager} from "src/interfaces/ILockManager.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

/// @title LockManagerTest
/// @notice Tests for LockManager
contract LockManagerTest is BaseTest {
    // ============ OWNABLE ============

    function test_constructor_setsOwner_succeeds() public view {
        assertEq(lockManager.owner(), owner);
    }

    function test_constructor_setsPermit2_succeeds() public view {
        assertEq(address(lockManager.PERMIT2()), address(permit2));
    }

    // ============ SET PARTNER STATUS ============

    function test_setPartnerStatus_asOwner_succeeds() public {
        vm.prank(owner);
        lockManager.setPartnerStatus(partner, true);

        assertTrue(lockManager.isPartner(partner));
    }

    function test_setPartnerStatus_asOwner_emitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit ILockManager.PartnerUpdated(partner, true);

        vm.prank(owner);
        lockManager.setPartnerStatus(partner, true);
    }

    function test_setPartnerStatus_removePartner_succeeds() public {
        vm.startPrank(owner);
        lockManager.setPartnerStatus(partner, true);
        lockManager.setPartnerStatus(partner, false);
        vm.stopPrank();

        assertFalse(lockManager.isPartner(partner));
    }

    function test_setPartnerStatus_removePartner_emitsEvent() public {
        vm.prank(owner);
        lockManager.setPartnerStatus(partner, true);

        vm.expectEmit(true, false, false, true);
        emit ILockManager.PartnerUpdated(partner, false);

        vm.prank(owner);
        lockManager.setPartnerStatus(partner, false);
    }

    function test_setPartnerStatus_notOwner_reverts() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        lockManager.setPartnerStatus(partner, true);
    }
}
