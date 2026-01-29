// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {ISignatureTransfer} from "../../lib/permit2/src/interfaces/ISignatureTransfer.sol";

interface ILockManager {
    struct Lock {
        address holder;
        uint40 expiresAt;
    }

    event LockCreated(address indexed user, address indexed holder, uint40 expiresAt);
    event LockReleased(address indexed user, address indexed holder);
    event PermitExecuted(address indexed user, address indexed holder, address token, uint256 amount, address recipient);
    event PartnerAdded(address indexed partner);
    event PartnerRemoved(address indexed partner);

    error NotAuthorized();
    error NotHolder();
    error LockActive();
    error NoActiveLock();
    error InvalidExpiration();
    error InvalidAddress();

    function lock(address user, uint40 expiration) external;
    function release(address user) external;
    function execute(
        ISignatureTransfer.PermitTransferFrom calldata permit,
        ISignatureTransfer.SignatureTransferDetails calldata transferDetails,
        address user,
        bytes calldata signature
    ) external;

    function getLock(address user) external view returns (Lock memory);
    function isLocked(address user) external view returns (bool);
    function isPartner(address account) external view returns (bool);
}