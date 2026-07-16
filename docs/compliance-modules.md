# Compliance Modules

## The interface

Every module implements the same small surface:

```solidity
interface IModule {
    function moduleCheck(address from, address to, uint256 value, address compliance)
        external view returns (bool);
    function moduleTransferAction(address from, address to, uint256 value) external;
    function moduleMintAction(address to, uint256 value) external;
    function moduleBurnAction(address from, uint256 value) external;
    function canComplianceBind(address compliance) external view returns (bool);
    function isPlugAndPlay() external pure returns (bool);
}
```

## The lifecycle, and why it's split into check vs. record

```
moduleCheck()          <- read-only, runs BEFORE the transfer
      |
      v
Transfer executes       <- balances mutate
      |
      v
moduleTransferAction()  <- writes state, runs AFTER success
```

`moduleCheck` stays `view` on purpose. Any state a module needs to remember
gets written in the action hooks, which only fire once a transfer is already
guaranteed to succeed. Writing state inside `moduleCheck` would mean a
transfer that passed this module's check but was then rejected by a
*different* bound module could still have consumed state that never actually
moved -- corrupting an investor's limit for no real reason. This repo's four
example modules cover every shape this interface needs to support:

## The four patterns

**Stateless read** (`CountryRestrictModule`) -- reads the receiver's country
from the Identity Registry at check time and compares it against a
restriction mapping. Nothing to record after the fact, so every action hook
stays empty.

**Delegated state** (`MaxBalanceModule`) -- reads `token.balanceOf()`
directly instead of keeping its own counter. Not everything that sounds
stateful needs its own storage; the token's balance is already the ground
truth, and duplicating it just creates a second copy that can drift out of
sync with the first.

**Genuine state tracking** (`TransferVolumeModule`) -- a rolling 30-day
per-investor volume cap. There's no existing ground truth for "how much has
this investor moved in the last 30 days," so the module has to maintain its
own window, written only in the action hooks.

**Time-based rule** (`LockupModule`) -- blocks outbound transfers until a
per-investor unlock timestamp. `block.timestamp` is already the ground truth,
so like the stateless module, all three action hooks stay empty.

## The namespacing rule every module in this repo follows

Every mapping is keyed by `compliance` address first:
`mapping(address => mapping(address => uint256))`. That's what lets a single
module contract be deployed once and reused across many different tokens'
compliance instances without one issuer's rules leaking into another's
holders -- see `test/security/ModuleStorageIsolation.t.sol` for a test that
proves this directly.

## Ordering and short-circuiting

`ModularCompliance.canTransfer` loops through bound modules and returns
`false` on the first rejection. Modules are ANDed together, never ORed --
if you need either/or logic, it has to live inside a single custom module
rather than across two bound modules. For gas efficiency, bind cheap,
likely-to-reject checks (a plain storage read) before expensive ones (checks
requiring multiple external calls), so the common rejection path stays cheap.
