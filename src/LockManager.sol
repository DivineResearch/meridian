// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Initializable} from "openzeppelin-contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts/proxy/utils/UUPSUpgradeable.sol";

import {Ownable2StepUpgradeable} from "openzeppelin-upgradeable/access/Ownable2StepUpgradeable.sol";

import {ISignatureTransfer} from "permit2/interfaces/ISignatureTransfer.sol";

import {ILockManager} from "./interfaces/ILockManager.sol";

/// @title LockManager
/// @author Divine Research
/// @notice Shared lock registry for coordinating exclusive access to user funds via Permit2
contract LockManager is ILockManager, Initializable, UUPSUpgradeable, Ownable2StepUpgradeable {
    /*//////////////////////////////////////////////////////////////
                             STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Lock information for each user
    mapping(address user => Lock) internal _locks;

    /// @notice Authorization status for each partner
    mapping(address partner => bool) internal _partners;

    /// @dev Gap for backwards compatibility to avoid storage collisions with previous contract versions
    uint256[50] private __gap;

    /// @notice Permit2 contract for signature-based transfers
    ISignatureTransfer internal permit2;

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

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the LockManager contract
    /// @param initialOwner Address of the contract owner
    /// @param _permit2 Address of the Permit2 contract
    function initialize(address initialOwner, address _permit2) external initializer {
        __Ownable_init(initialOwner);
        permit2 = ISignatureTransfer(_permit2);
    }

    /*//////////////////////////////////////////////////////////////
                             CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ILockManager
    function lock(address user, uint40 expiration) external onlyPartner {
        if (user == address(0)) revert InvalidUser();
        if (expiration <= block.timestamp) revert InvalidExpiration();
        if (isLocked(user)) revert LockActive();

        _locks[user] = Lock(msg.sender, expiration);

        emit LockCreated(user, msg.sender, expiration);
    }

    /// @inheritdoc ILockManager
    function release(address user) external onlyPartner {
        if (!isLocked(user)) revert NoActiveLock();
        if (_locks[user].holder != msg.sender) revert NotHolder();

        delete _locks[user];

        emit LockReleased(user, msg.sender);
    }

    /// @inheritdoc ILockManager
    function execute(
        ISignatureTransfer.PermitTransferFrom calldata permit,
        ISignatureTransfer.SignatureTransferDetails calldata transferDetails,
        address user,
        bytes calldata signature
    ) external onlyPartner {
        if (!isLocked(user)) revert NoActiveLock();
        if (_locks[user].holder != msg.sender) revert NotHolder();

        permit2.permitTransferFrom(permit, transferDetails, user, signature);

        emit PermitExecuted(user, msg.sender, permit.permitted.token, transferDetails.requestedAmount, transferDetails.to);
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

    /// @notice Authorize an upgrade to a new implementation
    /// @param newImplementation Address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /*//////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ILockManager
    function getLock(address user) external view returns (Lock memory) {
        if (!isLocked(user)) return Lock(address(0), 0);
        return _locks[user];
    }

    /// @inheritdoc ILockManager
    function isLocked(address user) public view returns (bool) {
        Lock memory userLock = _locks[user];

        // No lock exists for this user
        if (userLock.holder == address(0)) return false;
        // Lock has expired
        if (userLock.expiresAt <= block.timestamp) return false;
        // Holder is an authorized partner
        if (!_partners[userLock.holder]) return false;

        return true;
    }

    /// @inheritdoc ILockManager
    function isPartner(address account) external view returns (bool) {
        return _partners[account];
    }
}
