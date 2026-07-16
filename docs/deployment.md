# Deployment

## Order matters more than the code

```
Identity Registry
      |
Modular Compliance
      |
    Token
      |
   Factory (wires everything above in one call)
      |
   Deploy (onboard investors, THEN mint)
```

Deploying out of order is the most common reason a first deployment doesn't
work:

1. **Identity Registry Storage, Trusted Issuers Registry, Claim Topics
   Registry** first -- the Identity Registry depends on all three at
   construction time.
2. **Identity Registry**, then bind it to the storage contract via
   `irs.bindIdentityRegistry(address(identityRegistry))`. Skip this and every
   `registerIdentity` call reverts, since the storage contract only accepts
   writes from a registry it has explicitly bound.
3. **Modular Compliance**, deployed before the token since the token's
   constructor needs its address.
4. **Token**, then immediately `compliance.bindToken(address(token))`. Skip
   this and every `compliance.transferred()` call from the token reverts with
   `MC: caller is not the bound token`, because the compliance contract
   doesn't yet recognize the token as its authorized caller.
5. **Claim topics and trusted issuers**, configured before any investor
   onboarding -- `ctr.addClaimTopic(...)` and `tir.addTrustedIssuer(...)`.
6. **Onboard investors** -- deploy or reuse an ONCHAINID, get a claim signed
   and added, then `identityRegistry.registerIdentity(...)`.
7. **Mint.** If this happens before step 6 for the intended recipient, the
   mint reverts on `isVerified` with no more specific error message --
   almost every "why does my mint just fail" question traces back here.

## Using the factory

`TREXFactory.deployTREXSuite` performs steps 1-4 in a single transaction and
transfers ownership of every deployed contract to the address you specify,
rather than leaving the factory itself holding ownership. See
`contracts/factory/TREXFactory.sol` for the full wiring, and
`script/DeployTREXSuite.s.sol` for a runnable end-to-end script that also
covers steps 5-7 (claim topics, trusted issuer setup, investor onboarding,
mint, and a demo transfer) against a local Anvil node or a real network.

## Running the demo script

```bash
# local
anvil
forge script script/DeployTREXSuite.s.sol --rpc-url http://127.0.0.1:8545 --broadcast -vvvv

# real network -- fill in .env first (see .env.example)
forge script script/DeployTREXSuite.s.sol --rpc-url $RPC_URL --broadcast --verify -vvvv
```
