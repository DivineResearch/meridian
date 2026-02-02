// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ISignatureTransfer} from "permit2/interfaces/ISignatureTransfer.sol";

import {LockManager} from "src/LockManager.sol";

abstract contract BaseTest is Test {
    using SafeERC20 for IERC20;

    LockManager internal lockManager;
    ISignatureTransfer internal permit2 = ISignatureTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    IERC20 internal usdc = IERC20(0x79A02482A880bCE3F13e09Da970dC34db4CD24d1);

    // EIP712 type hashes
    bytes32 internal constant TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");
    bytes32 internal constant PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );

    // Users addresses and private keys
    uint256 internal ownerPrivateKey = 0x1111;
    uint256 internal alicePrivateKey = 0x2222;
    uint256 internal bobPrivateKey = 0x3333;
    uint256 internal partnerPrivateKey = 0x4444;

    address internal owner = vm.addr(ownerPrivateKey);
    address internal alice = vm.addr(alicePrivateKey);
    address internal bob = vm.addr(bobPrivateKey);
    address internal partner = vm.addr(partnerPrivateKey);

    // Mapping to store private keys for addresses
    mapping(address => uint256) internal addressToPrivateKey;

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("CONTRACTS_RPC_URL"), 16642178);

        vm.label(address(permit2), "Permit2");
        vm.label(address(usdc), "USDC");
        vm.label(owner, "Owner");
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(partner, "Partner");

        lockManager = LockManager(
            address(
                new ERC1967Proxy(
                    address(new LockManager()), abi.encodeCall(LockManager.initialize, (owner, address(permit2)))
                )
            )
        );

        // Initialize address to private key mapping
        addressToPrivateKey[owner] = ownerPrivateKey;
        addressToPrivateKey[alice] = alicePrivateKey;
        addressToPrivateKey[bob] = bobPrivateKey;
        addressToPrivateKey[partner] = partnerPrivateKey;

        // Mock permit2 for all tests
        MockPermit2 mockPermit2 = new MockPermit2();
        vm.etch(address(permit2), address(mockPermit2).code);
    }

    function _getPermitSignature(address user, ISignatureTransfer.PermitTransferFrom memory permit)
        internal
        view
        returns (bytes memory sig)
    {
        bytes32 tokenPermissionsHash =
            keccak256(abi.encode(TOKEN_PERMISSIONS_TYPEHASH, permit.permitted.token, permit.permitted.amount));

        bytes32 permitStructHash = keccak256(
            abi.encode(
                PERMIT_TRANSFER_FROM_TYPEHASH, tokenPermissionsHash, address(lockManager), permit.nonce, permit.deadline
            )
        );

        bytes32 permitHash = keccak256(abi.encodePacked("\x19\x01", permit2.DOMAIN_SEPARATOR(), permitStructHash));

        // Get the private key for the user
        uint256 privateKey = addressToPrivateKey[user];
        require(privateKey != 0, "Private key not found for user");

        // Sign the permit hash
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, permitHash);
        return abi.encodePacked(r, s, v);
    }
}

/// @title MockPermit2
/// @notice Mock Permit2 contract for testing
contract MockPermit2 {
    using SafeERC20 for IERC20;

    bytes32 public constant DOMAIN_SEPARATOR = 0x7bbefd3f28aeae3614be24b551808c46797d48ce4b30bf73580ba9383c1edcf7;

    function permitTransferFrom(
        ISignatureTransfer.PermitTransferFrom calldata permit,
        ISignatureTransfer.SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata /* signature */
    ) external {
        // Mock implementation - just perform the transfer
        IERC20(permit.permitted.token).safeTransferFrom(owner, transferDetails.to, transferDetails.requestedAmount);
    }
}
