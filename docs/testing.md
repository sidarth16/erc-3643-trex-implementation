# Testing

## Structure

```
test/
  unit/         one contract at a time
  integration/  full flows: onboard -> mint -> transfer -> freeze -> revoke
  fuzz/         boundary conditions on each compliance module
  invariant/    properties that must hold under ANY reachable sequence
  security/     the specific failure modes covered in docs/claims.md and
                 docs/compliance-modules.md, written as tests rather than prose
```

## Why invariant tests matter more than the count of unit tests

A unit test proves one specific sequence of calls behaves correctly. An
invariant test proves a property holds no matter *what* sequence a fuzzer can
construct -- mint, transfer, burn, freeze, in any order, any amount, any
actor. For a compliance boundary specifically, this is the test category
most likely to catch a bypass a manual review would miss, because it isn't
limited to the sequences a human thought to write by hand.

This repo's core invariant, in `test/invariant/ComplianceInvariant.t.sol`:

```solidity
function invariant_UnverifiedNeverHoldsBalance() public view {
    for (uint256 i = 0; i < unverified.length; i++) {
        assertEq(token.balanceOf(unverified[i]), 0);
    }
}
```

Alongside two supporting invariants: frozen accounting never exceeds actual
balance, and total supply always matches ghost-tracked mint/burn totals.

## Running everything

```bash
forge test                                  # full suite
forge test --match-path "test/unit/**"      # unit only
forge test --match-contract Invariant -vvv  # invariant suite, verbose
FOUNDRY_INVARIANT_RUNS=1000 forge test --match-contract ComplianceInvariantTest
```

Increase `FOUNDRY_INVARIANT_RUNS` well above the `foundry.toml` default before
trusting an invariant suite as a real signal -- a low run count can pass by
not having explored enough of the state space, not because the property
actually holds.

## What the security/ tests are actually for

Unlike unit tests, which mostly prove the happy path works, everything under
`test/security/` is written to fail *closed*: wrong signer, mismatched
encoding, missing claim topic, revoked claim, a malicious module trying to
override another module's rejection, and privileged functions called by
non-privileged callers. Each one asserts the system rejects the bad case
rather than silently accepting it -- the difference between "the demo works"
and "an auditor can't find a bypass."
