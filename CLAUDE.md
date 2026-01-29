# CLAUDE.md

Guidance for working with the Mutex protocol.

## Protocol Overview

Mutex provides a shared lock registry for coordinating exclusive access to user funds via Permit2. It solves the race condition problem where multiple World App miniapps might attempt to pull funds from the same user simultaneously.

### Core Principle

One user, one lock, one holder at a time. The lock holder has exclusive rights to execute Permit2 transfers from that user until the lock is released or expires.

### System Context

You are an advanced assistant specialized in Ethereum smart contract development using Foundry. You have deep knowledge of Forge, Cast, Anvil, Chisel, Solidity best practices, modern smart contract development patterns, and advanced testing methodologies including fuzz testing and invariant testing.

## Architecture

### LockManager Contract

Single contract with three responsibilities:

1. **Lock Registry** - tracks who holds the lock for each user
2. **Partner Authorization** - allowlist of protocols that can acquire locks
3. **Permit Execution** - executes Permit2 transfers when lock is valid

### Key Functions

| Function | Caller | Purpose |
|----------|--------|---------|
| `lock(user, expiration)` | Authorized partner | Acquire exclusive access |
| `release(user)` | Current holder | Return lock to protocol |
| `execute(permit, transferDetails, user, signature)` | Current holder | Pull funds via Permit2 |
| `isLocked(user)` | Anyone | Check lock status |

### Design Decisions

| Choice | Why |
|--------|-----|
| No intermediate contracts | Direct transfers to holder-specified destination |
| Lazy expiration | No cleanup needed, just check timestamp |
| Holder specifies destination | `transferDetails.to` gives flexibility to consuming protocol |
| Single registry | All partners share one source of truth |

## Permit2 Integration

LockManager wraps Permit2's `permitTransferFrom`:

1. Miniapp generates permit with **LockManager as spender**
2. Miniapp stores permit data (off-chain or in their protocol contract)
3. When ready, protocol calls `execute()` with permit + signature
4. LockManager validates lock ownership, then calls Permit2
5. Tokens transfer directly to `transferDetails.to`

## Testing Approach

### Test Structure

```
test/
├── LockManager.t.sol      # Main test file
│   ├── LOCK section       # lock() tests
│   ├── RELEASE section    # release() tests
│   ├── EXECUTE section    # execute() + Permit2 tests
│   └── ACCESS CONTROL     # authorization tests
└── BaseTest.sol           # Shared setup + permit helpers
```

### What to Test

**Lock mechanics:**
- Acquiring lock for unlocked user
- Rejecting lock when user already locked (by different holder)
- Lock expiration behavior
- Re-locking after expiration

**Release mechanics:**
- Only holder can release
- State cleared after release

**Execute mechanics:**
- Valid permit + valid lock succeeds
- Expired lock reverts
- Wrong holder reverts
- Permit signature validation

**Access control:**
- Only authorized partners can call `lock()`
- Partner revocation behavior (graceful vs immediate)

### Invariants

- A user can have at most one active lock
- Only the holder can execute or release
- Lock expiration is monotonic (can't extend)

## Development Notes

### Keep It Minimal

Resist adding business logic. LockManager should NOT know about:
- Loans or debt
- Token swaps
- Penalties or interest
- Specific token types

These belong in the consuming protocol.

### Gas Considerations

- Lock struct is small (address + uint40 = 1 slot)
- No arrays or mappings to iterate
- Single SLOAD to check lock validity

### Open Questions

1. **Partner revocation policy**: Immediate termination vs graceful deprecation?
2. **Lock extension**: Should holders be able to extend expiration?
3. **Batch operations**: Support `executeBatch()` for multiple permits?

## File Structure

```
mutex/
├── src/
│   ├── LockManager.sol
│   └── interfaces/
│       └── ILockManager.sol
├── test/
│   ├── LockManager.t.sol
│   └── BaseTest.sol
├── script/
│   └── Deploy.s.sol
├── CLAUDE.md
└── README.md
```

---

## World Chain Context

### Network Details

- **Chain ID**: 480 (World Chain Mainnet)
- **RPC**: Use `WORLD_CHAIN_RPC_URL` env var
- **Block Explorer**: worldscan.org

### Key Addresses (World Chain)

```solidity
// Permit2 (same on all chains)
address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

// Tokens
address constant USDC = 0x79A02482A880bCE3F13e09Da970dC34db4CD24d1;
address constant WLD = 0x2cFc85d8E48F8EAB294be644d9E25C3030863003;
```

### Fork Testing Setup

Tests should fork World Chain for realistic Permit2 behavior:

```solidity
function setUp() public {
    vm.createSelectFork(vm.envString("WORLD_CHAIN_RPC_URL"));

    // Label addresses for cleaner traces
    vm.label(PERMIT2, "Permit2");
    vm.label(USDC, "USDC");
    vm.label(WLD, "WLD");
}
```

For unit tests, use MockPermit2 (etch over real address) to isolate logic from Permit2 internals.

---

## Development Standards

### Naming Conventions

**Contracts & Files:**
- Contracts: PascalCase (`LockManager.sol`)
- Interfaces: `I` prefix (`ILockManager.sol`)
- Tests: `.t.sol` suffix (`LockManager.t.sol`)
- Scripts: `.s.sol` suffix (`Deploy.s.sol`)

**Functions & Variables:**
- Functions: mixedCase (`lock()`, `isLocked()`, `getLock()`)
- Variables: mixedCase (`locks`, `authorizedPartners`)
- Constants: SCREAMING_SNAKE_CASE (`PERMIT2`, `MAX_LOCK_DURATION`)
- Immutables: SCREAMING_SNAKE_CASE (`PERMIT2`)
- Structs/Enums: PascalCase (`Lock`, `PartnerStatus`)

**Test Naming:**
- Success: `test_functionName_succeeds`
- Revert: `test_functionName_condition_reverts`
- Fuzz: `testFuzz_functionName`
- Invariant: `invariant_propertyName`

### Testing Patterns

**Unit Tests:**
- Use `test_` prefix for standard tests
- Test both success and revert paths
- Use `vm.expectRevert(CustomError.selector)` for failures
- Include descriptive assertion messages
- Never put assertions in `setUp()`

**Fuzz Tests:**
- Use smaller types to avoid overflows (e.g., `uint40` for expiration)
- Use `bound()` to constrain inputs to valid ranges
- Use `vm.assume()` sparingly for invalid input exclusion
- Test properties, not specific values

**Invariant Tests:**
- Use handler contracts to bound actions
- Track state with ghost variables
- Test protocol-wide properties that must always hold
- Configure appropriate depth and runs in foundry.toml

### Permit2 & EIP-712 Testing

**Type Hashes (constants for BaseTest):**
```solidity
bytes32 constant TOKEN_PERMISSIONS_TYPEHASH =
    keccak256("TokenPermissions(address token,uint256 amount)");

bytes32 constant PERMIT_TRANSFER_FROM_TYPEHASH =
    keccak256("PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)");
```

**Signature Generation Pattern:**
1. Build `TokenPermissions` hash from token + amount
2. Build `PermitTransferFrom` hash with spender = LockManager
3. Combine with domain separator using EIP-712 format
4. Sign with `vm.sign(privateKey, digest)`
5. Pack as `abi.encodePacked(r, s, v)`

**MockPermit2 for Unit Tests:**
- Skip signature verification
- Just execute the transfer directly
- Track nonces to catch replay issues
- Use real Permit2 in fork tests for full validation

### Security Checklist

**Access Control:**
- Only authorized partners can call `lock()`
- Only current holder can call `release()` and `execute()`
- Use custom errors, not require strings
- Validate all inputs (non-zero addresses, valid expirations)

**CEI Pattern (Checks-Effects-Interactions):**
1. **Checks**: Validate caller, lock state, expiration
2. **Effects**: Update storage (lock registry)
3. **Interactions**: External call to Permit2

**Custom Errors:**
```solidity
error NotAuthorized();      // Caller not in partner allowlist
error NotHolder();          // Caller doesn't hold the lock
error LockActive();         // User already locked by another holder
error LockExpired();        // Lock has expired
error InvalidExpiration();  // Expiration in the past or too far
```

**What NOT to Worry About:**
- Reentrancy: State changes before external call, and Permit2 is trusted
- Overflow: Solidity 0.8+ handles this
- Front-running: Lock holder is msg.sender, can't be changed mid-tx
