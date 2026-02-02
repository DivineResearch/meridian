// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {BaseForkTest} from "test/fork/BaseForkTest.sol";
import {ILockManager} from "src/interfaces/ILockManager.sol";
import {ISignatureTransfer} from "permit2/interfaces/ISignatureTransfer.sol";

/// @title LockManagerForkTest
/// @notice Fork tests for LockManager against World Chain
contract LockManagerForkTest is BaseForkTest {
    function test_fork_lockAndExecute_usdc_succeeds() public {
        // Authorize partner
        vm.prank(owner);
        lockManager.setPartnerStatus(partner, true);

        // Partner acquires lock on alice
        uint40 expiration = uint40(block.timestamp + 1 hours);
        vm.prank(partner);
        lockManager.lock(alice, expiration);

        // Verify lock is active
        assertTrue(lockManager.isLocked(alice));
        ILockManager.Lock memory userLock = lockManager.getLock(alice);
        assertEq(userLock.holder, partner);

        // Fund alice with USDC
        uint256 amount = 100e6; // 100 USDC
        deal(address(usdc), alice, amount);
        assertEq(usdc.balanceOf(alice), amount);

        // Alice approves Permit2 to spend USDC
        vm.prank(alice);
        usdc.approve(address(permit2), type(uint256).max);

        // Build permit
        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(usdc), amount: amount}),
            nonce: 0,
            deadline: block.timestamp + 1 hours
        });

        ISignatureTransfer.SignatureTransferDetails memory transferDetails =
            ISignatureTransfer.SignatureTransferDetails({to: partner, requestedAmount: amount});

        // Generate signature using inherited helper
        bytes memory signature = _getPermitSignature(alice, permit);

        // Partner executes permit through LockManager
        vm.prank(partner);
        lockManager.execute(permit, transferDetails, alice, signature);

        // Verify transfer succeeded
        assertEq(usdc.balanceOf(alice), 0);
        assertEq(usdc.balanceOf(partner), amount);
    }
}
