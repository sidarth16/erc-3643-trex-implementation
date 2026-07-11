# ERC-3643 (T-REX) -- From-Scratch Educational Implementation

A simplified, independently-written implementation of ERC-3643 (T-REX),
built to demonstrate every architectural concept in the accompanying
two-part article series without cloning Tokeny's reference implementation.
Favor readability over gas-optimality throughout -- this is meant to be read
and understood, then adapted, not deployed verbatim.

- **Part 1:** [ERC-3643 (T-REX) Explained](https://medium.com/@sidarths/erc-3643-t-rex-explained-the-standard-behind-rwa-regulated-asset-tokenization-515daa156dd3)
- **Part 2:** ERC-3643 (T-REX) Part 2: Building, Testing & Auditing Compliant Token Contracts

## Quick start

```bash
git clone <this-repo>
cd erc3643-trex-implementation

forge install foundry-rs/forge-std --no-commit
forge install OpenZeppelin/openzeppelin-contracts --no-commit

forge build
forge test
```

Copy `.env.example` to `.env` and fill in `RPC_URL` / `PRIVATE_KEY` before
running the deployment script against anything other than a local node.

## Directory structure

```
erc3643-trex-implementation/
  contracts/
    interfaces/        every interface: IToken, IIdentityRegistry,
                        ITrustedIssuersRegistry, IModularCompliance, IModule...
    identity/           Identity.sol (ONCHAINID), ClaimIssuer.sol
    registry/           IdentityRegistry + its three supporting registries
    compliance/
      modules/          CountryRestrictModule, MaxBalanceModule,
                        TransferVolumeModule, LockupModule
    factory/            TREXFactory.sol
    Token.sol
  script/
    DeployTREXSuite.s.sol
  test/
    unit/               one contract at a time
    integration/        full onboarding -> mint -> transfer -> freeze flows
    fuzz/               boundary conditions per module
    invariant/           properties that must hold under any call sequence
    security/           wrong signer, encoding mismatch, access control, etc.
    utils/              ClaimSigner + shared test base
  docs/
    architecture.md
    claims.md
    compliance-modules.md
    deployment.md
    testing.md
  SECURITY_CHECKLIST.md
```

## What's in here

- A full, independent implementation of the Token / Identity Registry /
  Modular Compliance / Trusted Issuers Registry / Claim Topics Registry
  architecture, with NatSpec explaining *why* each design decision exists,
  not just what the code does.
- A minimal ONCHAINID (`Identity.sol` + `ClaimIssuer.sol`) implementing the
  ERC-734/735 pieces actually needed for claim issuance and verification.
- Four compliance modules, each demonstrating a distinct implementation
  pattern (stateless read, delegated state, genuine state tracking,
  time-based rule) -- see `docs/compliance-modules.md`.
- A factory (`TREXFactory.sol`) that wires and hands off ownership of a full
  suite in one transaction.
- Unit, integration, fuzz, invariant, and security-focused tests -- see
  `docs/testing.md` for what each category is actually for.

## A note on verification

This repo was written and reasoned through carefully, but the sandbox it was
authored in didn't have network access to install the Foundry toolchain
itself, so `forge build` / `forge test` have not been executed against this
exact code before being handed off. Run the full suite locally before relying
on it -- if anything doesn't compile cleanly, it's most likely a remapping
mismatch (`remappings.txt`) or an OpenZeppelin version difference, both
usually a one-line fix.

## License

MIT
# erc-3643-trex-implementation
