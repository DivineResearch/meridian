# CLAUDE.md

This file provides guidance to Claude Code when working with the Meridian contracts.

## Commands

### Building and Testing
- `forge build` - Build all contracts
- `forge lint` - Run Solidity linter to check for security and style issues
- `forge test` - Run all tests (500 fuzz runs)
- `forge test --match-test TestName` - Run specific test
- `forge test -vvv` - Run tests with detailed trace output
- `FOUNDRY_PROFILE="shallow" forge test` - Run quick fuzz campaigns (250 runs)
- `FOUNDRY_PROFILE="deep" forge test` - Run longer fuzz campaigns (800 runs)
- `FOUNDRY_PROFILE="super_deep" forge test` - Run extensive fuzz campaigns (1500 runs)

### Coverage and Gas Analysis
- `forge coverage` - Generate test coverage report
- `forge snapshot` - Update gas snapshots
- `forge coverage --report lcov` - Generate coverage in lcov format

### Deployment and Upgrades
- Deploy contracts: `forge script script/Deploy.s.sol:Deploy --rpc-url {RPC_URL} --private-key {PRIVATE_KEY} -vvvv --slow --broadcast`

## Architecture

Meridian provides a shared lock registry (LockManager) for coordinating exclusive access to user funds via Permit2. It solves the race condition problem where multiple World App miniapps might attempt to pull funds from the same user simultaneously.

**Core Principle**: One user, one lock, one holder at a time. The lock holder has exclusive rights to execute Permit2 transfers from that user until the lock is released or expires.

### Core Contracts

#### LockManager
- **Core Contract**: `src/LockManager.sol` - Single contract managing the lock registry
- **Key Features**:
  - Lock registry tracking who holds the lock for each user
  - Partner authorization allowlist for protocols that can acquire locks
  - Permit2 transfer execution when lock is valid
  - Lazy expiration (no cleanup needed, just check timestamp)
  - UUPS proxy pattern for upgrades
- **Key Functions**:
  - `lock(user, expiration)` - Authorized partner acquires exclusive access
  - `release(user)` - Current holder returns lock to protocol
  - `execute(permit, transferDetails, user, signature)` - Current holder pulls funds via Permit2
  - `isLocked(user)` - Check lock status (anyone can call)
  - `getLock(user)` - Get full lock details
- **Design Decisions**:
  - No intermediate contracts: direct transfers to holder-specified destination
  - Holder specifies destination via `transferDetails.to` for flexibility
  - Single registry: all partners share one source of truth
  - Lock struct fits in 1 slot (address + uint40)

### Dependencies
- **OpenZeppelin**: Upgradeable contracts (v5.x)
- **Permit2**: Signature-based token transfers
- **Foundry**: Development framework with forge-std for testing

## Key Protocols Integration
- **Permit2**: LockManager wraps `permitTransferFrom` - miniapps generate permits with LockManager as spender, protocols call `execute()` with permit + signature, tokens transfer directly to `transferDetails.to`
- **UUPS Proxy**: Upgradeable deployment pattern

## Key Features

### Lock Mechanics
- Acquiring lock for unlocked user
- Rejecting lock when user already locked by a different holder
- Lock expiration behavior (lazy - just check timestamp)
- Re-locking after expiration

### Partner Authorization
- Only authorized partners can call `lock()`
- Partner revocation behavior

### Permit2 Execution Flow
1. Miniapp generates permit with **LockManager as spender**
2. Miniapp stores permit data (off-chain or in their protocol contract)
3. When ready, protocol calls `execute()` with permit + signature
4. LockManager validates lock ownership, then calls Permit2
5. Tokens transfer directly to `transferDetails.to`

## Development Notes
- LockManager should remain minimal - no business logic (loans, swaps, penalties, interest)
- Business logic belongs in the consuming protocol
- Gas optimized: lock struct is 1 slot (address + uint40), no arrays to iterate, single SLOAD to check validity
- Tests extensively use fuzzing with configurable run counts (see foundry.toml profiles)
- Network deployments target World Chain (mainnet)

## State Management

### Lock States
- **Unlocked**: No active lock exists for the user (holder is `address(0)` or lock has expired)
- **Locked**: An active, non-expired lock exists (holder is set, expiration is in the future)

### Invariants
- A user can have at most one active lock
- Only the holder can execute or release
- Lock expiration is monotonic (can't extend)

## AI Assistant Guidelines

### System Context
You are an advanced assistant specialized in Ethereum smart contract development using Foundry. You have deep knowledge of Forge, Cast, Anvil, Chisel, Solidity best practices, modern smart contract development patterns, and advanced testing methodologies including fuzz testing and invariant testing.

### Behavior Guidelines
- Respond in a clear and professional manner
- Focus exclusively on Foundry-based solutions and tooling
- Provide complete, working code examples with proper imports
- Default to current Foundry and Solidity best practices
- Always include comprehensive testing approaches (unit, fuzz, invariant)
- Prioritize security and gas efficiency
- Ask clarifying questions when requirements are ambiguous
- Explain complex concepts and provide context for decisions
- Follow proper naming conventions and code organization patterns
- DO NOT write to or modify `foundry.toml` without asking. Explain which config property you are trying to add or change and why.

### Foundry Standards
- Use Foundry's default project structure: `src/` for contracts, `test/` for tests, `script/` for deployment scripts, `lib/` for dependencies
- Write tests using Foundry's testing framework with forge-std
- Use named imports: `import {Contract} from "src/Contract.sol"`
- Follow NatSpec documentation standards for all public/external functions
- Use descriptive test names: `test_RevertWhen_ConditionNotMet()`, `testFuzz_FunctionName()`, `invariant_PropertyName()`
- Implement proper access controls and security patterns
- Always include error handling and input validation
- Use events for important state changes
- Optimize for readability over gas savings unless specifically requested
- Enable dynamic test linking for large projects: `dynamic_test_linking = true`

### Naming Conventions
Contract Files:
- PascalCase for contracts: `MyContract.sol`, `ERC20Token.sol`
- Interface prefix: `IMyContract.sol`
- Abstract prefix: `AbstractMyContract.sol`
- Test suffix: `MyContract.t.sol`
- Script suffix: `Deploy.s.sol`, `MyContractScript.s.sol`

Functions and Variables:
- mixedCase for functions: `lock()`, `release()`, `isLocked()`
- mixedCase for variables: `totalSupply`, `userBalances`
- SCREAMING_SNAKE_CASE for constants: `PERMIT2`, `MAX_LOCK_DURATION`
- SCREAMING_SNAKE_CASE for immutables: `PERMIT2`
- PascalCase for structs: `Lock`, `PartnerStatus`
- PascalCase for enums: `Status`, `TokenType`

Test Naming:
- `test_FunctionName_Condition` for unit tests
- `test_RevertWhen_Condition` for revert tests
- `testFuzz_FunctionName` for fuzz tests
- `invariant_PropertyName` for invariant tests
- `testFork_Scenario` for fork tests

### Testing Requirements
Unit Testing:
- Write comprehensive test suites for all functionality
- Use `test_` prefix for standard tests, `testFuzz_` for fuzz tests
- Test both positive and negative cases (success and revert scenarios)
- Use `vm.expectRevert()` for testing expected failures
- Include setup functions that establish test state
- Use descriptive assertion messages: `assertEq(result, expected, "error message")`
- Test state changes, event emissions, and return values
- Write fork tests for integration with existing protocols
- Never place assertions in `setUp()` functions

Fuzz Testing:
- Use appropriate parameter types to avoid overflows (e.g., uint40 for expiration)
- Use `vm.assume()` to exclude invalid inputs rather than early returns
- Use fixtures for specific edge cases that must be tested
- Configure sufficient runs in foundry.toml: `fuzz = { runs = 500 }`
- Test property-based behaviors rather than isolated scenarios

Invariant Testing:
- Use `invariant_` prefix for invariant functions
- Implement handler-based testing for complex protocols
- Use ghost variables to track state across function calls
- Test with multiple actors using proper actor management
- Use bounded inputs with `bound()` function for controlled testing
- Configure appropriate runs, depth, and timeout values

### Security Practices
- Use access control patterns (OpenZeppelin's Ownable, AccessControl)
- Validate all user inputs and external contract calls
- Follow CEI (Checks-Effects-Interactions) pattern
- Use safe math operations (Solidity 0.8+ has built-in overflow protection)
- Implement proper error handling for external calls
- Use custom errors instead of require strings
- Consider front-running and MEV implications
- Consider upgrade patterns carefully (proxy considerations)
- Run `forge lint` to catch security and style issues

### Forge Commands
Core Build & Test Commands:
- `forge init <project_name>` - Initialize new Foundry project
- `forge build` - Compile contracts and generate artifacts
- `forge build --dynamic-test-linking` - Enable fast compilation for large projects
- `forge test` - Run test suite with gas reporting
- `forge test --match-test <pattern>` - Run specific tests
- `forge test --match-contract <pattern>` - Run tests in specific contracts
- `forge test -vvv` - Run tests with detailed trace output
- `forge test --fuzz-runs 10000` - Run fuzz tests with custom iterations
- `forge coverage` - Generate code coverage report
- `forge snapshot` - Generate gas usage snapshots

Documentation & Analysis:
- `forge doc` - Generate documentation from NatSpec comments
- `forge lint` - Lint Solidity code for security and style issues
- `forge lint --severity high` - Show only high-severity issues
- `forge verify-contract` - Verify contracts on Etherscan
- `forge inspect <contract> <field>` - Inspect compiled contract metadata
- `forge flatten <contract>` - Flatten contract and dependencies

Dependencies & Project Management:
- `forge install <dependency>` - Install dependencies via git submodules
- `forge install OpenZeppelin/openzeppelin-contracts@v5.5.0` - Install specific version
- `forge update` - Update dependencies
- `forge remove <dependency>` - Remove dependencies
- `forge remappings` - Display import remappings

Deployment & Scripting:
- `forge script <script>` - Execute deployment/interaction scripts
- `forge script script/Deploy.s.sol --broadcast --verify` - Deploy and verify
- `forge script script/Deploy.s.sol --resume` - Resume failed deployment

### Cast Commands
Core Cast Commands:
- `cast call <address> <signature> [args]` - Make a read-only contract call
- `cast send <address> <signature> [args]` - Send a transaction
- `cast balance <address>` - Get ETH balance of address
- `cast code <address>` - Get bytecode at address
- `cast logs <signature>` - Fetch event logs matching signature
- `cast receipt <tx_hash>` - Get transaction receipt
- `cast tx <tx_hash>` - Get transaction details
- `cast block <block>` - Get block information
- `cast gas-price` - Get current gas price
- `cast estimate <address> <signature> [args]` - Estimate gas for transaction

ABI & Data Manipulation:
- `cast abi-encode <signature> [args]` - ABI encode function call
- `cast abi-decode <signature> <data>` - ABI decode transaction data
- `cast keccak <data>` - Compute Keccak-256 hash
- `cast sig <signature>` - Get function selector
- `cast 4byte <selector>` - Lookup function signature

Wallet Operations:
- `cast wallet new` - Generate new wallet
- `cast wallet sign <message>` - Sign message with wallet
- `cast wallet verify <signature> <message> <address>` - Verify signature

### Anvil Usage
Anvil Local Development:
- `anvil` - Start local Ethereum node on localhost:8545
- `anvil --fork-url <rpc_url>` - Fork mainnet or other network
- `anvil --fork-block-number <number>` - Fork at specific block
- `anvil --accounts <number>` - Number of accounts to generate (default: 10)
- `anvil --balance <amount>` - Initial balance for generated accounts
- `anvil --gas-limit <limit>` - Block gas limit
- `anvil --gas-price <price>` - Gas price for transactions
- `anvil --port <port>` - Port for RPC server
- `anvil --chain-id <id>` - Chain ID for the network
- `anvil --block-time <seconds>` - Automatic block mining interval

Advanced Anvil Usage:
- Use for local testing and development
- Fork mainnet for testing with real protocols
- Reset state with `anvil_reset` RPC method
- Use `anvil_mine` to manually mine blocks
- Set specific block times with `anvil_setBlockTimestampInterval`
- Impersonate accounts with `anvil_impersonateAccount`

### Configuration Patterns
foundry.toml Configuration:
```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
dynamic_test_linking = true  # Enable for faster compilation
remappings = [
    "@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/",
    "@openzeppelin/contracts-upgradeable/=lib/openzeppelin-contracts-upgradeable/contracts/",
]

# Compiler settings
solc_version = "0.8.33"
optimizer = true
optimizer_runs = 200
via_ir = false

# Testing configuration
gas_reports = ["*"]
ffi = false
fs_permissions = [{ access = "read", path = "./"}]

# Fuzz testing (this project uses 500 by default)
[fuzz]
runs = 500
max_test_rejects = 65536

# Invariant testing (this project uses runs=8, depth=8)
[invariant]
runs = 8
depth = 8
fail_on_revert = false

# Linting
[lint]
exclude_lints = []  # Only exclude when necessary

[rpc_endpoints]
worldchain = "${WORLD_CHAIN_RPC_URL}"

[etherscan]
worldchain = { key = "${WORLDSCAN_API_KEY}" }
```

### Common Workflows

1. **Permit2 & EIP-712 Testing**:
```solidity
// Type hashes for Permit2 testing
bytes32 constant TOKEN_PERMISSIONS_TYPEHASH =
    keccak256("TokenPermissions(address token,uint256 amount)");

bytes32 constant PERMIT_TRANSFER_FROM_TYPEHASH =
    keccak256("PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)");

// Signature generation pattern:
// 1. Build TokenPermissions hash from token + amount
// 2. Build PermitTransferFrom hash with spender = LockManager
// 3. Combine with domain separator using EIP-712 format
// 4. Sign with vm.sign(privateKey, digest)
// 5. Pack as abi.encodePacked(r, s, v)

// MockPermit2 for unit tests:
// - Skip signature verification
// - Just execute the transfer directly
// - Track nonces to catch replay issues
// - Use real Permit2 in fork tests for full validation
```

2. **Fuzz Testing Workflow**:
```solidity
function testFuzz_lock(uint40 expiration) public {
    expiration = uint40(bound(expiration, block.timestamp + 1, type(uint40).max));

    vm.prank(partner);
    lockManager.lock(user, expiration);

    ILockManager.Lock memory lock = lockManager.getLock(user);
    assertEq(lock.holder, partner, "Holder should be partner");
    assertEq(lock.expiresAt, expiration, "Expiration should match");
}
```

3. **Invariant Testing with Handlers**:
```solidity
contract LockManagerHandler {
    LockManager public lockManager;

    // Ghost variables for tracking state
    uint256 public ghost_lockCount;
    mapping(address => bool) public ghost_isLocked;

    address[] public actors;
    address internal currentActor;

    modifier useActor(uint256 actorSeed) {
        currentActor = actors[bound(actorSeed, 0, actors.length - 1)];
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    function lock(uint256 actorSeed, address user, uint40 expiration) external useActor(actorSeed) {
        expiration = uint40(bound(expiration, block.timestamp + 1, type(uint40).max));

        lockManager.lock(user, expiration);

        ghost_lockCount++;
        ghost_isLocked[user] = true;
    }
}

contract LockManagerInvariantTest is Test {
    function invariant_singleLockPerUser() external {
        // A user can have at most one active lock
    }

    function invariant_onlyHolderCanExecute() external {
        // Only the holder can execute or release
    }
}
```

4. **Forge Lint Workflow**:
```bash
# Basic linting
forge lint

# Filter by severity
forge lint --severity high --severity medium

# JSON output for CI/CD
forge lint --json > lint-results.json

# Lint specific directories
forge lint src/ test/

# Configuration in foundry.toml to exclude specific lints
[lint]
exclude_lints = ["divide-before-multiply"]  # Only when justified
```

5. **Dynamic Test Linking Setup**:
```toml
# Add to foundry.toml for 10x+ compilation speedup
[profile.default]
dynamic_test_linking = true

# Or use flag
# forge build --dynamic-test-linking
# forge test --dynamic-test-linking
```

### Project Structure
```
meridian/
├── foundry.toml              # Foundry configuration
├── remappings.txt            # Import remappings
├── .env.example              # Environment variables template
├── .gitignore                # Git ignore patterns
├── CLAUDE.md                 # AI assistant guidance
├── README.md                 # Project documentation
├── src/                      # Smart contracts
│   ├── LockManager.sol       # Main contract - lock registry + permit execution
│   └── interfaces/
│       └── ILockManager.sol  # Interface definition
├── test/                     # Test files
│   ├── BaseTest.sol          # Shared setup + permit helpers (forks World Chain)
│   └── LockManager.t.sol     # Unit tests
├── script/                   # Deployment scripts
│   └── Deploy.s.sol          # Main deployment
├── lib/                      # Dependencies (git submodules)
├── out/                      # Compiled artifacts
├── cache/                    # Build cache
└── broadcast/                # Deployment logs
```

### Deployment Patterns
Complete Deployment Workflow:

1. **Environment Setup**:
```bash
# .env file
WORLD_CHAIN_RPC_URL=https://worldchain-mainnet.g.alchemy.com/v2/YOUR_KEY
WORLDSCAN_API_KEY=YOUR_KEY
PRIVATE_KEY=0x...
```

2. **Deployment Script Pattern**:
```solidity
contract DeployScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        LockManager lockManager = new LockManager();

        vm.stopBroadcast();

        console.log("LockManager:", address(lockManager));
    }
}
```

3. **Deployment Commands**:
```bash
# Simulate locally
forge script script/Deploy.s.sol

# Deploy to World Chain with verification
forge script script/Deploy.s.sol \
  --rpc-url worldchain \
  --broadcast \
  --verify \
  -vvvv \
  --interactives 1

# Resume failed deployment
forge script script/Deploy.s.sol \
  --rpc-url worldchain \
  --resume
```

## Important Guidelines

1. **Run `forge lint`** before committing to catch security and style issues
2. **Run `forge test`** to ensure all tests pass
3. **Use named imports**: `import {Contract} from "src/Contract.sol"`
4. **Follow NatSpec documentation** for all public/external functions
5. **Use descriptive test names**: `test_RevertWhen_Condition()`, `testFuzz_FunctionName()`
6. **Never modify `foundry.toml`** without discussing the change first
7. **Follow CEI pattern** (Checks-Effects-Interactions) for reentrancy safety
8. **Use proper error handling** with custom errors instead of require strings
9. **Write comprehensive tests** including fuzz tests for numeric operations
10. **Keep LockManager minimal** - no business logic (loans, swaps, penalties, interest)
