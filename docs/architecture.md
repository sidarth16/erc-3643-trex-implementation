# Architecture

## Why three separate contracts instead of one

A regulated token has to answer three genuinely different questions on every
transfer: *is this address who it claims to be*, *does this address hold the
attributes this offering requires*, and *does this specific transfer obey the
business rules in effect right now*. Bundling all three into one `transfer()`
override is how most teams start, and it's also why most of those tokens
can't survive a rule change without a full redeploy.

This implementation keeps them apart:

```
                             Token
                                |
                ________________|________________
                |                                 |
       Identity Registry                 Modular Compliance
   "is this address verified"        "does this transfer obey the rules"
                |
     ____________________________
     |             |             |
 Identity      Claim Topics   (delegates to)
 Storage         Registry
     |
Trusted Issuers
   Registry
```

**Token** never talks to an investor's ONCHAINID directly. It always asks the
Identity Registry.

**Identity Registry** never enforces business rules. It only resolves an
address to an identity, checks the identity's claims against the topics this
token requires, and confirms each claim was signed by an issuer the Trusted
Issuers Registry actually trusts *for that topic*.

**Modular Compliance** never touches identity. It only asks each bound module
whether this specific transfer is allowed, ANDing every module's answer
together.

## Why this separation matters in practice

- **Compliance rules can change without touching the token.** Bind or unbind
  a module, and every future transfer respects the new rule immediately --
  no migration, no new token contract.
- **Identity is reusable across tokens.** An investor verified once for Token
  A doesn't need to re-verify for Token B, as long as both tokens' Trusted
  Issuers Registries recognize the same claim issuer.
- **Revocation propagates instantly and globally.** Removing a claim issuer
  from the Trusted Issuers Registry invalidates every claim it ever signed,
  across every Identity Registry pointed at that registry -- without
  touching a single investor's identity contract.

## The transfer lifecycle

Every gatekept function on `Token` -- `transfer`, `transferFrom`, `mint`,
`forcedTransfer` -- follows the same three-step shape, and the order is load
bearing, not stylistic:

```
validate (identity + compliance)
        |
        v
transfer (mutate balances)
        |
        v
compliance.transferred() / created() / destroyed()   <- notify AFTER success
```

Validating after mutating would mean balances could already be wrong before
discovering a transfer shouldn't have happened. Notifying compliance before
the mutation would let stateful modules record volume or counters for
transfers that could still fail downstream. Check, then mutate, then notify
-- always in that order.
