// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import { ILockManager } from "./interfaces/ILockManager.sol";
import { ISignatureTransfer } from "../lib/permit2/src/interfaces/ISignatureTransfer.sol";

/// @title LockManager
/// @notice Shared lock registry for Permit2 coordination
contract LockManager is ILockManager {
    ISignatureTransfer public immutable PERMIT2;

    mapping(address user => Lock) internal _locks;
    mapping(address partner => bool) internal _partners;

    constructor(address permit2) {
        PERMIT2 = ISignatureTransfer(permit2);
    }

    function lock(address user, uint40 expiration) external {
        revert NotAuthorized();
    }

    function release(address user) external {
        revert NotHolder();
    }

    function execute(
        ISignatureTransfer.PermitTransferFrom calldata permit,
        ISignatureTransfer.SignatureTransferDetails calldata transferDetails,
        address user,
        bytes calldata signature
    ) external {
        revert NotHolder();
    }

    function getLock(address user) external view returns (Lock memory) {
        return _locks[user];
    }

    function isLocked(address user) external view returns (bool) {
        Lock memory userLock = _locks[user];
        return userLock.holder != address(0) && userLock.expiresAt > block.timestamp;
    }

    function isPartner(address account) external view returns (bool) {
        return _partners[account];
    }
}
