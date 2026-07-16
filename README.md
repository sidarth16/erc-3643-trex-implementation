# ERC-3643 (T-REX) — A From-Scratch Reference Implementation

[![Solidity](https://img.shields.io/badge/solidity-%5E0.8.24-363636?logo=solidity)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/built%20with-Foundry-black?logo=ethereum)](https://getfoundry.sh/)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)
[![Standard](https://img.shields.io/badge/standard-ERC--3643%20(T--REX)-6f42c1)](https://eips.ethereum.org/EIPS/eip-3643)

An independently written, from-scratch implementation of **ERC-3643 (T-REX)**
— the permissioned token standard used to enforce on-chain KYC, jurisdiction,
and investor-eligibility rules for tokenized securities and other regulated
real-world assets.

This is not a fork or a copy of Tokeny's reference implementation. It's
written to teach the architecture: every contract carries NatSpec explaining
*why* a design decision exists, not just what the code does, and the test
suite is organized to demonstrate how to actually verify a compliance
boundary rather than just exercise the happy path.

> **Read this alongside the code, don't copy it wholesale.** This repo
> accompanies a two-part written series that walks through the reasoning
> behind every piece here. If you're integrating ERC-3643 into something
> real, understand *why* each contract is separated the way it is before you
> adapt this code — the separation is the entire point of the standard.

**[Part 1 — ERC-3643 (T-REX) Explained: The Standard Behind RWA Tokenization](https://medium.com/@sidarths/erc-3643-t-rex-explained-the-standard-behind-rwa-regulated-asset-tokenization-515daa156dd3)** : 
What the standard is, why it exists, and how its six contracts fit together.

**[Part 2 — Building, Testing & Auditing Compliant Token Contracts](https://medium.com/@sidarths/erc-3643-t-rex-part-2-building-testing-auditing-compliant-token-contracts-4784b712fea1)** : 
How to actually build it: writing the Token, Identity Registry, and
Compliance contracts from scratch, extending them with custom modules,
testing the compliance boundary the way an auditor would, and the pitfalls
that catch people who've only read the spec.

---

## Table of Contents

- [Why ERC-3643](#why-erc-3643)
- [Architecture](#architecture)
- [Repository Structure](#repository-structure)
- [Quick Start](#quick-start)
- [Compliance Module Patterns](#compliance-module-patterns)
- [Testing](#testing)
- [Documentation](#documentation)
- [Security](#security)
- [Design Philosophy](#design-philosophy)
- [Contributing](#contributing)
- [Disclaimer](#disclaimer)
- [License](#license)

---

## Why ERC-3643

Plain ERC-20 answers one question: does the sender have enough balance? A
regulated security has to answer several more on every transfer — is the
receiver KYC'd, are they in a permitted jurisdiction, would this transfer
breach an investor cap, is this holder still inside a lockup period — and
those rules need to be able to change after deployment without a token
migration.

ERC-3643 solves this by splitting a compliant token into independent,
swappable contracts instead of one monolithic override of `transfer()`:
identity verification, claim trust, and business-rule enforcement each live
in their own contract, so any one of them can evolve without touching the
others.

## Architecture

```
                             Token
                                │
                ┌───────────────┴───────────────┐
                │                                │
       Identity Registry                 Modular Compliance
     "is this address verified"      "does this transfer obey the rules"
                │                                │
     ┌──────────┼──────────┐                     │
     │          │          │                     │
 Identity   Claim Topics   │               Compliance
 Storage      Registry     │                Modules
     │                     │
Trusted Issuers      (queries token
   Registry           balance / identity
     │                as needed)
     ▼
 ONCHAINID
 (per-investor identity contract,
  holds signed claims)
```

**Token** never talks to an investor's identity directly — it always goes
through the Identity Registry. **Identity Registry** never enforces business
rules — it only answers "is this address verified." **Modular Compliance**
never touches identity — it only answers "does this specific transfer obey
the rules in effect right now." Three separate questions, three separate
contracts, each independently upgradeable without touching the others.

Full breakdown, including the claim-signing flow and the transfer lifecycle,
is in [`docs/architecture.md`](./docs/architecture.md) and
[`docs/claims.md`](./docs/claims.md).

## Repository Structure

```
contracts/
  interfaces/          Every interface: IToken, IIdentityRegistry,
                        ITrustedIssuersRegistry, IModularCompliance, IModule...
  identity/             Identity.sol (minimal ONCHAINID), ClaimIssuer.sol
  registry/             IdentityRegistry + its three supporting registries
  compliance/
    ModularCompliance.sol
    modules/             CountryRestrictModule, MaxBalanceModule,
                          TransferVolumeModule, LockupModule
  factory/               TREXFactory.sol — deploys and wires a full suite
  Token.sol

script/
  DeployTREXSuite.s.sol  Runnable end-to-end deployment + onboarding demo

test/
  unit/                 One contract at a time
  integration/           Full flows: onboard → mint → transfer → freeze → revoke
  fuzz/                  Boundary conditions per compliance module
  invariant/             Properties that must hold under any reachable call sequence
  security/              Wrong signer, encoding mismatch, access control, module isolation
  utils/                 Shared test base + claim-signing helper

docs/
  architecture.md
  claims.md
  compliance-modules.md
  deployment.md
  testing.md

SECURITY_CHECKLIST.md    Pre-deployment checklist, grouped by category
```

## Quick Start

```bash
git clone <this-repo>
cd erc3643-trex-implementation

forge install foundry-rs/forge-std
forge install OpenZeppelin/openzeppelin-contracts

forge build
forge test
```

Copy `.env.example` to `.env` before running the deployment script against
anything other than a local node:

```bash
anvil
forge script script/DeployTREXSuite.s.sol --rpc-url http://127.0.0.1:8545 --broadcast -vvvv
```

See [`docs/deployment.md`](./docs/deployment.md) for the full deployment
order and why it matters — deploying these contracts out of sequence is the
most common reason a first attempt doesn't work.

## Compliance Module Patterns

Four modules ship with this repo, each demonstrating a distinct
implementation pattern so you have a template for whatever rule you need to
write next:

| Module | Pattern | Why |
|---|---|---|
| `CountryRestrictModule` | Stateless read | Reads identity data at check time; nothing to record after |
| `MaxBalanceModule` | Delegated state | Reads `token.balanceOf()` directly instead of duplicating it |
| `TransferVolumeModule` | Genuine state tracking | Rolling window the token itself has no concept of |
| `LockupModule` | Time-based rule | `block.timestamp` is already the ground truth |

Every module namespaces its storage by `compliance` address first, so a
single deployed module contract can be safely reused across many different
tokens without one issuer's rules leaking into another's holders — see
[`test/security/ModuleStorageIsolation.t.sol`](./test/security/ModuleStorageIsolation.t.sol)
for a test that proves this directly. Full writeup in
[`docs/compliance-modules.md`](./docs/compliance-modules.md).

## Testing

```bash
forge test                                   # full suite
forge test --match-path "test/unit/**"       # unit tests only
forge test --match-contract Invariant -vvv   # invariant suite, verbose
FOUNDRY_INVARIANT_RUNS=1000 forge test --match-contract ComplianceInvariantTest
```

The suite is organized in five layers — see
[`docs/testing.md`](./docs/testing.md) for what each is actually for:

- **Unit** — one contract at a time
- **Integration** — full onboarding → mint → transfer → freeze → revocation flows
- **Fuzz** — boundary conditions on every compliance module
- **Invariant** — properties that must hold under *any* reachable sequence of
  calls, most importantly: an unverified address must never hold a nonzero
  balance, no matter what a fuzzer throws at the system
- **Security** — wrong signer, `abi.encode` vs `abi.encodePacked` mismatches,
  missing claim topics, revoked claims, malicious/reverting modules, and
  access control on every privileged function

## Documentation

| Doc | Covers |
|---|---|
| [`docs/architecture.md`](./docs/architecture.md) | Why the system is split into three contracts, and the transfer lifecycle |
| [`docs/claims.md`](./docs/claims.md) | ONCHAINID, claim signing, and the encoding mismatch that costs the most debugging time |
| [`docs/compliance-modules.md`](./docs/compliance-modules.md) | The module interface, the four implementation patterns, and ordering/gas notes |
| [`docs/deployment.md`](./docs/deployment.md) | Correct deployment order and the factory pattern |
| [`docs/testing.md`](./docs/testing.md) | What each test layer is for and how to run it |

## Security

[`SECURITY_CHECKLIST.md`](./SECURITY_CHECKLIST.md) is a pre-deployment
checklist grouped into deployment, security, testing, gas, upgradeability,
and monitoring — use it before any deployment based on this code goes
anywhere near real capital.

A few things worth internalizing before you extend this codebase:

- **Trusted Issuers Registry ownership is the actual root of trust.**
  Compromising it is equivalent to compromising the compliance program for
  every token that relies on it.
- **`isVerified` wraps external claim-issuer calls in `try/catch`.** A single
  malformed or reverting issuer contract should never be able to brick
  verification for every investor holding a claim from it.
- **Compliance modules only write state in their action hooks, never in
  `moduleCheck`.** Mixing mutation into a `view` check breaks the
  check-effects-interactions boundary the whole system relies on.

If you find a genuine vulnerability, please open an issue rather than a
public PR with exploit details.

## Design Philosophy

- **Readability over gas-optimality.** This is meant to be read and
  understood before it's adapted, not deployed byte-for-byte as-is.
- **Every non-obvious decision is commented, not just documented.** Look for
  `SECURITY NOTE`, `ARCHITECTURE NOTE`, and `COMMON MISTAKE` comments
  throughout the contracts — they explain *why*, not just *what*.
- **Tests are written to fail closed.** Most of `test/security/` exists to
  prove the system rejects a bad case, not to prove the happy path works.

## Contributing

Issues and PRs are welcome, especially additional compliance module examples
or test cases that catch something the current suite doesn't. If you're
proposing a new module, please follow the existing pattern: NatSpec
explaining which of the four patterns it demonstrates and why, plus a
matching test file.

## Disclaimer

This is an educational implementation written to accompany a technical
article series. It has not been professionally audited. Do not deploy it,
or code adapted from it, with real capital behind it without an independent
security review.

## License

[MIT](./LICENSE)
