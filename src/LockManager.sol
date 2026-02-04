// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {Initializable} from "openzeppelin-contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts/proxy/utils/UUPSUpgradeable.sol";

import {Ownable2StepUpgradeable} from "openzeppelin-upgradeable/access/Ownable2StepUpgradeable.sol";

import {ISignatureTransfer} from "permit2/interfaces/ISignatureTransfer.sol";

import {ILockManager} from "meridian/interfaces/ILockManager.sol";

/// @title LockManager
/// @author Divine Research
/// @notice Shared lock registry for coordinating exclusive access to user funds via Permit2
contract LockManager is ILockManager, Initializable, UUPSUpgradeable, Ownable2StepUpgradeable {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum duration a lock can be held (1 year)
    uint40 public constant MAX_LOCK_DURATION = 365 days;

    /*//////////////////////////////////////////////////////////////
                             STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Permit2 contract
    ISignatureTransfer internal permit2;

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

    /// @notice Prevent the implementation contract from being initialized
    /// @dev Proxy contract state will still be able to call this function
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                               INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize the contract
    /// @param owner_ Address of the owner
    /// @param permit2_ Address of the Permit2 contract
    function initialize(address owner_, address permit2_) external initializer {
        __Ownable_init(owner_);

        if (permit2_ == address(0)) revert Permit2Invalid();

        permit2 = ISignatureTransfer(permit2_);
    }

    /*//////////////////////////////////////////////////////////////
                             CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ILockManager
    function lock(address user, uint40 expiration) external onlyPartner {
        if (user == address(0)) revert InvalidUser();
        if (expiration <= block.timestamp) revert InvalidExpiration();
        if (expiration > block.timestamp + MAX_LOCK_DURATION) revert InvalidExpiration();
        if (isLocked(user)) revert LockActive();

        _locks[user] = Lock(msg.sender, expiration);

        emit LockCreated(user, msg.sender, expiration);
    }

    /// @inheritdoc ILockManager
    function release(address user) external onlyPartner {
        if (_locks[user].holder == address(0)) revert NoActiveLock();
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

        emit PermitExecuted(user, msg.sender, permit, transferDetails, signature);
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

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Upgrade the implementation of the proxy to a new address
    /// @dev Only the owner can upgrade the implementation
    function _authorizeUpgrade(address) internal override onlyOwner {}
}
