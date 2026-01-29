// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import { ILockManager } from "./interfaces/ILockManager.sol";
import { ISignatureTransfer } from "../lib/permit2/src/interfaces/ISignatureTransfer.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

/// @title LockManager
/// @notice Shared lock registry for Permit2 coordination
contract LockManager is ILockManager, Ownable {
    ISignatureTransfer public immutable PERMIT2;

    mapping(address user => Lock) internal _locks;
    mapping(address partner => bool) internal _partners;

    constructor(
        address initialOwner,
        address permit2
    ) Ownable(initialOwner) {
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

    function setPartnerStatus(address partner, bool status) external onlyOwner {
        _partners[partner] = status;
        emit PartnerUpdated(partner, status);
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
