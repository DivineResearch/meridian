// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

import {ISignatureTransfer} from "permit2/interfaces/ISignatureTransfer.sol";

import {ILockManager} from "./interfaces/ILockManager.sol";

/// @title LockManager
/// @author Divine Research
/// @notice Shared lock registry for coordinating exclusive access to user funds via Permit2
contract LockManager is ILockManager, Ownable {
    /*//////////////////////////////////////////////////////////////
                             STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Permit2 contract for signature-based transfers
    ISignatureTransfer public immutable PERMIT2;

    /// @notice Lock information for each user
    mapping(address user => Lock) internal _locks;

    /// @notice Authorization status for each partner
    mapping(address partner => bool) internal _partners;

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Ensure only authorized partners can call
    modifier onlyPartner() {
        if (!_partners[msg.sender]) revert NotAuthorized();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize the LockManager contract
    /// @param initialOwner Address of the contract owner
    /// @param permit2 Address of the Permit2 contract
    constructor(address initialOwner, address permit2) Ownable(initialOwner) {
        PERMIT2 = ISignatureTransfer(permit2);
    }

    /*//////////////////////////////////////////////////////////////
                             CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ILockManager
    function lock(address user, uint40 expiration) external onlyPartner {
        if (isLocked(user)) revert LockActive();

        _locks[user] = Lock(msg.sender, expiration);

        emit LockCreated(user, msg.sender, expiration);
    }

    /// @inheritdoc ILockManager
    function release(address user) external {
        revert NotHolder();
    }

    /// @inheritdoc ILockManager
    function execute(
        ISignatureTransfer.PermitTransferFrom calldata permit,
        ISignatureTransfer.SignatureTransferDetails calldata transferDetails,
        address user,
        bytes calldata signature
    ) external {
        revert NotHolder();
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Set the authorization status of a partner
    /// @param partner Address of the partner
    /// @param status New authorization status
    function setPartnerStatus(address partner, bool status) external onlyOwner {
        _partners[partner] = status;

        emit PartnerUpdated(partner, status);
    }

    /*//////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ILockManager
    function getLock(address user) external view returns (Lock memory) {
        return _locks[user];
    }

    /// @inheritdoc ILockManager
    function isLocked(address user) public view returns (bool) {
        Lock memory userLock = _locks[user];
        return userLock.holder != address(0) && userLock.expiresAt > block.timestamp;
    }

    /// @inheritdoc ILockManager
    function isPartner(address account) external view returns (bool) {
        return _partners[account];
    }
}
