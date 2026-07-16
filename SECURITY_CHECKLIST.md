# Security Checklist

Use this before any T-REX deployment built from or inspired by this repo
goes anywhere near real capital. Grouped roughly by how much damage a miss
does, most damaging first.

## Deployment
- [ ] Deployed through the factory (or an equivalent single, ordered flow),
      not hand-assembled across separate transactions
- [ ] Claim topics and initial compliance modules set BEFORE any minting
- [ ] `identityRegistryStorage.bindIdentityRegistry` and
      `compliance.bindToken` both confirmed on-chain post-deploy, not just
      assumed from the script succeeding

## Security
- [ ] Claim issuer signing keys held behind HSM/multisig, not a single EOA
- [ ] Trusted Issuers Registry ownership is NOT the same hot key as
      day-to-day agent operations (minting, freezing)
- [ ] `forcedTransfer` / `freezePartialTokens` / `pause` gated by a multisig
      or timelock, not a single agent key
- [ ] Static analysis (Slither or equivalent) run, findings triaged rather
      than default-suppressed

## Testing
- [ ] `forge coverage` shows meaningful coverage on every compliance module,
      not just the token contract
- [ ] Invariant tests run 1000+ iterations with no failures
      (`FOUNDRY_INVARIANT_RUNS=1000`+)
- [ ] Every `onlyOwner` / `onlyAgent` function has an explicit test asserting
      non-privileged callers revert
- [ ] Claim security tests cover: wrong signer, encoding mismatch, missing
      claim topic, revoked claim, malformed/reverting issuer contract

## Gas
- [ ] Modules ordered cheapest-first in the compliance contract
- [ ] No module loops over all holders -- everything stateful uses
      per-investor mappings
- [ ] `forge snapshot` committed so a future module addition that spikes gas
      shows up in code review

## Upgradeability (if deploying behind a proxy)
- [ ] `forge inspect <Contract> storage-layout` saved and diffed before
      every upgrade
- [ ] New storage variables only ever appended, never inserted or reordered
- [ ] `_authorizeUpgrade` (or equivalent) gated by the same access control
      standard as every other privileged function

## Monitoring
- [ ] Claim revocations and trusted-issuer removals are alerted on, not just
      logged -- a silent revocation that nobody notices defeats the point of
      having instant, registry-wide propagation
- [ ] Frozen-balance and forced-transfer events surfaced to compliance ops
      in something more actionable than a block explorer
