// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {ISignatureTransfer} from "permit2/interfaces/ISignatureTransfer.sol";

/// @title ILockManager
/// @author Divine Research
/// @notice Interface for the LockManager contract
interface ILockManager {
    /*//////////////////////////////////////////////////////////////
                                 TYPES
    //////////////////////////////////////////////////////////////*/

    /// @notice Lock information structure
    /// @param holder Address that holds the lock
    /// @param expiresAt Timestamp when the lock expires
    struct Lock {
        address holder;
        uint40 expiresAt;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when caller is not an authorized partner
    error NotAuthorized();

    /// @notice Thrown when caller is not the lock holder
    error NotHolder();

    /// @notice Thrown when user already has an active lock
    error LockActive();

    /// @notice Thrown when user has no active lock
    error NoActiveLock();

    /// @notice Thrown when expiration is not in the future
    error InvalidExpiration();

    /// @notice Thrown when user address is zero
    error InvalidUser();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a lock is created
    /// @param user Address of the user whose funds are locked
    /// @param holder Address that holds the lock
    /// @param expiresAt Timestamp when the lock expires
    event LockCreated(address indexed user, address indexed holder, uint40 expiresAt);

    /// @notice Emitted when a lock is released
    /// @param user Address of the user whose lock was released
    /// @param holder Address that held the lock
    event LockReleased(address indexed user, address indexed holder);

    /// @notice Emitted when a permit is executed
    /// @param user Address of the user whose funds were transferred
    /// @param holder Address that executed the permit
    /// @param token Address of the token transferred
    /// @param amount Amount of tokens transferred
    /// @param recipient Address that received the tokens
    event PermitExecuted(address indexed user, address indexed holder, address token, uint256 amount, address recipient);

    /// @notice Emitted when partner status is updated
    /// @param partner Address of the partner
    /// @param status New status of the partner
    event PartnerUpdated(address indexed partner, bool status);

    /*//////////////////////////////////////////////////////////////
                             CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Acquire exclusive lock on a user's funds
    /// @param user Address of the user to lock
    /// @param expiration Timestamp when the lock expires
    function lock(address user, uint40 expiration) external;

    /// @notice Release lock on a user's funds
    /// @param user Address of the user to release
    function release(address user) external;

    /// @notice Execute a Permit2 transfer while holding the lock
    /// @param permit Permit2 permit data
    /// @param transferDetails Transfer details including recipient and amount
    /// @param user Address of the user whose funds are being transferred
    /// @param signature User's signature for the permit
    function execute(
        ISignatureTransfer.PermitTransferFrom calldata permit,
        ISignatureTransfer.SignatureTransferDetails calldata transferDetails,
        address user,
        bytes calldata signature
    ) external;

    /*//////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get lock information for a user
    /// @param user Address of the user
    /// @return Lock information
    function getLock(address user) external view returns (Lock memory);

    /// @notice Check if a user has an active lock
    /// @param user Address of the user
    /// @return True if the user has an active lock
    function isLocked(address user) external view returns (bool);

    /// @notice Check if an address is an authorized partner
    /// @param account Address to check
    /// @return True if the address is an authorized partner
    function isPartner(address account) external view returns (bool);
}
