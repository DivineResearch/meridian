// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {BaseTest} from "test/BaseTest.sol";
import {LockManager} from "src/LockManager.sol";
import {ILockManager} from "src/interfaces/ILockManager.sol";
import {ISignatureTransfer} from "permit2/interfaces/ISignatureTransfer.sol";
import {OwnableUpgradeable} from "openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts/proxy/utils/UUPSUpgradeable.sol";

/// @title LockManagerTest
/// @notice Tests for LockManager
contract LockManagerTest is BaseTest {
    /*//////////////////////////////////////////////////////////////
                                OWNABLE
    //////////////////////////////////////////////////////////////*/

    function test_initialize_setsOwner_succeeds() public view {
        assertEq(lockManager.owner(), owner);
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
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
        lockManager.setPartnerStatus(partner, true);
    }

    // ============ ONLY PARTNER MODIFIER ============

    function test_lock_asPartner_succeeds() public {
        vm.prank(owner);
        lockManager.setPartnerStatus(partner, true);

        vm.prank(partner);
        lockManager.lock(alice, uint40(block.timestamp + 1 hours));
    }

    function test_lock_notPartner_reverts() public {
        vm.prank(alice);
        vm.expectRevert(ILockManager.NotAuthorized.selector);
        lockManager.lock(bob, uint40(block.timestamp + 1 hours));
    }

    function test_lock_revokedPartner_reverts() public {
        vm.startPrank(owner);
        lockManager.setPartnerStatus(partner, true);
        lockManager.setPartnerStatus(partner, false);
        vm.stopPrank();

        vm.prank(partner);
        vm.expectRevert(ILockManager.NotAuthorized.selector);
        lockManager.lock(alice, uint40(block.timestamp + 1 hours));
    }

    /*//////////////////////////////////////////////////////////////
                             LOCK MECHANICS
    //////////////////////////////////////////////////////////////*/

    function test_lock_setsHolderAndExpiration_succeeds() public {
        vm.prank(owner);
        lockManager.setPartnerStatus(partner, true);

        uint40 expiration = uint40(block.timestamp + 1 hours);

        vm.prank(partner);
        lockManager.lock(alice, expiration);

        ILockManager.Lock memory userLock = lockManager.getLock(alice);
        assertEq(userLock.holder, partner);
        assertEq(userLock.expiresAt, expiration);
    }

    function test_lock_emitsLockCreated_succeeds() public {
        vm.prank(owner);
        lockManager.setPartnerStatus(partner, true);

        uint40 expiration = uint40(block.timestamp + 1 hours);

        vm.expectEmit(true, true, false, true);
        emit ILockManager.LockCreated(alice, partner, expiration);

        vm.prank(partner);
        lockManager.lock(alice, expiration);
    }

    function test_lock_alreadyLocked_reverts() public {
        vm.prank(owner);
        lockManager.setPartnerStatus(partner, true);

        vm.prank(partner);
        lockManager.lock(alice, uint40(block.timestamp + 1 hours));

        vm.prank(partner);
        vm.expectRevert(ILockManager.LockActive.selector);
        lockManager.lock(alice, uint40(block.timestamp + 2 hours));
    }

    function test_lock_afterExpiration_succeeds() public {
        vm.prank(owner);
        lockManager.setPartnerStatus(partner, true);

        vm.prank(partner);
        lockManager.lock(alice, uint40(block.timestamp + 1 hours));

        vm.warp(block.timestamp + 2 hours);

        vm.prank(partner);
        lockManager.lock(alice, uint40(block.timestamp + 1 hours));
    }

    function test_lock_exceedsMaxDuration_reverts() public {
        vm.prank(owner);
        lockManager.setPartnerStatus(partner, true);

        uint40 tooLongExpiration = uint40(block.timestamp + lockManager.MAX_LOCK_DURATION() + 1);

        vm.prank(partner);
        vm.expectRevert(ILockManager.InvalidExpiration.selector);
        lockManager.lock(alice, tooLongExpiration);
    }

    /*//////////////////////////////////////////////////////////////
                                 LOCKED
    //////////////////////////////////////////////////////////////*/

    function test_isLocked_activeLock_returnsTrue() public {
        vm.prank(owner);
        lockManager.setPartnerStatus(partner, true);

        vm.prank(partner);
        lockManager.lock(alice, uint40(block.timestamp + 1 hours));

        assertTrue(lockManager.isLocked(alice));
    }

    function test_isLocked_noLock_returnsFalse() public view {
        assertFalse(lockManager.isLocked(alice));
    }

    function test_isLocked_expiredLock_returnsFalse() public {
        vm.prank(owner);
        lockManager.setPartnerStatus(partner, true);

        vm.prank(partner);
        lockManager.lock(alice, uint40(block.timestamp + 1 hours));

        vm.warp(block.timestamp + 2 hours);

        assertFalse(lockManager.isLocked(alice));
    }

    function test_isLocked_revokedHolder_returnsFalse() public {
        vm.prank(owner);
        lockManager.setPartnerStatus(partner, true);

        vm.prank(partner);
        lockManager.lock(alice, uint40(block.timestamp + 1 hours));

        assertTrue(lockManager.isLocked(alice));

        vm.prank(owner);
        lockManager.setPartnerStatus(partner, false);

        assertFalse(lockManager.isLocked(alice));
    }

    /*//////////////////////////////////////////////////////////////
                                 RELEASE
    //////////////////////////////////////////////////////////////*/

    function test_release_asHolder_succeeds() public {
        vm.prank(owner);
        lockManager.setPartnerStatus(partner, true);

        vm.prank(partner);
        lockManager.lock(alice, uint40(block.timestamp + 1 hours));

        vm.prank(partner);
        lockManager.release(alice);

        assertFalse(lockManager.isLocked(alice));
    }

    function test_release_clearsLock_succeeds() public {
        vm.prank(owner);
        lockManager.setPartnerStatus(partner, true);

        vm.prank(partner);
        lockManager.lock(alice, uint40(block.timestamp + 1 hours));

        vm.prank(partner);
        lockManager.release(alice);

        ILockManager.Lock memory userLock = lockManager.getLock(alice);
        assertEq(userLock.holder, address(0));
        assertEq(userLock.expiresAt, 0);
    }

    function test_release_emitsLockReleased_succeeds() public {
        vm.prank(owner);
        lockManager.setPartnerStatus(partner, true);

        vm.prank(partner);
        lockManager.lock(alice, uint40(block.timestamp + 1 hours));

        vm.expectEmit(true, true, false, true);
        emit ILockManager.LockReleased(alice, partner);

        vm.prank(partner);
        lockManager.release(alice);
    }

    function test_release_afterExpiration_succeeds() public {
        vm.prank(owner);
        lockManager.setPartnerStatus(partner, true);

        vm.prank(partner);
        lockManager.lock(alice, uint40(block.timestamp + 1 hours));

        vm.warp(block.timestamp + 2 hours);

        vm.prank(partner);
        lockManager.release(alice);

        ILockManager.Lock memory userLock = lockManager.getLock(alice);
        assertEq(userLock.holder, address(0));
    }

    function test_release_notPartner_reverts() public {
        vm.prank(owner);
        lockManager.setPartnerStatus(partner, true);

        vm.prank(partner);
        lockManager.lock(alice, uint40(block.timestamp + 1 hours));

        vm.prank(alice);
        vm.expectRevert(ILockManager.NotAuthorized.selector);
        lockManager.release(alice);
    }

    function test_release_notHolder_reverts() public {
        vm.startPrank(owner);
        lockManager.setPartnerStatus(partner, true);
        lockManager.setPartnerStatus(bob, true);
        vm.stopPrank();

        vm.prank(partner);
        lockManager.lock(alice, uint40(block.timestamp + 1 hours));

        vm.prank(bob);
        vm.expectRevert(ILockManager.NotHolder.selector);
        lockManager.release(alice);
    }

    function test_release_noLock_reverts() public {
        vm.prank(owner);
        lockManager.setPartnerStatus(partner, true);

        vm.prank(partner);
        vm.expectRevert(ILockManager.NoActiveLock.selector);
        lockManager.release(alice);
    }

    /*//////////////////////////////////////////////////////////////
                                 EXECUTE
    //////////////////////////////////////////////////////////////*/

    function test_execute_succeeds() public {
        vm.prank(owner);
        lockManager.setPartnerStatus(partner, true);

        vm.prank(partner);
        lockManager.lock(alice, uint40(block.timestamp + 1 hours));

        uint256 amount = 100e6;
        deal(address(usdc), alice, amount);

        vm.prank(alice);
        usdc.approve(address(permit2), type(uint256).max);

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(usdc), amount: amount}),
            nonce: 0,
            deadline: block.timestamp + 1 hours
        });

        ISignatureTransfer.SignatureTransferDetails memory transferDetails =
            ISignatureTransfer.SignatureTransferDetails({to: partner, requestedAmount: amount});

        bytes memory signature = _getPermitSignature(alice, permit);

        vm.prank(partner);
        lockManager.execute(permit, transferDetails, alice, signature);

        assertEq(usdc.balanceOf(partner), amount);
        assertEq(usdc.balanceOf(alice), 0);
    }

    function test_execute_noActiveLock_reverts() public {
        vm.prank(owner);
        lockManager.setPartnerStatus(partner, true);

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(usdc), amount: 100e6}),
            nonce: 0,
            deadline: block.timestamp + 1 hours
        });

        ISignatureTransfer.SignatureTransferDetails memory transferDetails =
            ISignatureTransfer.SignatureTransferDetails({to: partner, requestedAmount: 100e6});

        bytes memory signature = _getPermitSignature(alice, permit);

        vm.prank(partner);
        vm.expectRevert(ILockManager.NoActiveLock.selector);
        lockManager.execute(permit, transferDetails, alice, signature);
    }

    function test_execute_expiredLock_reverts() public {
        vm.prank(owner);
        lockManager.setPartnerStatus(partner, true);

        vm.prank(partner);
        lockManager.lock(alice, uint40(block.timestamp + 1 hours));

        vm.warp(block.timestamp + 2 hours);

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(usdc), amount: 100e6}),
            nonce: 0,
            deadline: block.timestamp + 1 hours
        });

        ISignatureTransfer.SignatureTransferDetails memory transferDetails =
            ISignatureTransfer.SignatureTransferDetails({to: partner, requestedAmount: 100e6});

        bytes memory signature = _getPermitSignature(alice, permit);

        vm.prank(partner);
        vm.expectRevert(ILockManager.NoActiveLock.selector);
        lockManager.execute(permit, transferDetails, alice, signature);
    }

    function test_execute_notHolder_reverts() public {
        vm.startPrank(owner);
        lockManager.setPartnerStatus(partner, true);
        lockManager.setPartnerStatus(bob, true);
        vm.stopPrank();

        vm.prank(partner);
        lockManager.lock(alice, uint40(block.timestamp + 1 hours));

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(usdc), amount: 100e6}),
            nonce: 0,
            deadline: block.timestamp + 1 hours
        });

        ISignatureTransfer.SignatureTransferDetails memory transferDetails =
            ISignatureTransfer.SignatureTransferDetails({to: bob, requestedAmount: 100e6});

        bytes memory signature = _getPermitSignature(alice, permit);

        vm.prank(bob);
        vm.expectRevert(ILockManager.NotHolder.selector);
        lockManager.execute(permit, transferDetails, alice, signature);
    }

    // ============ UPGRADE ============

    function test_upgrade_succeeds() public {
        address newImplementation = address(new LockManager());

        vm.prank(owner);
        UUPSUpgradeable(address(lockManager)).upgradeToAndCall(newImplementation, bytes(""));
    }
}
