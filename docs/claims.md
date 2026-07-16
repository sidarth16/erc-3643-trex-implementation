# Claims

## Why identity is a contract, not a database row

An ONCHAINID is a smart contract the investor (or a custodian on their
behalf) controls, holding cryptographically signed statements from third
parties. It is deliberately not a row in the token issuer's database, for two
reasons: it survives the investor moving to a different token issuer, and the
actual KYC documents never touch the chain -- only a signed attestation does.

## The flow

```
Investor
   |
ONCHAINID (identity contract, investor-owned)
   |
Claim issuer signs off-chain
   |
Signed claim added to ONCHAINID
   |
Identity Registry checks the claim on every transfer
   |
Mint / transfer allowed
```

## Why the signature, not the data, is what matters

A claim's `data` field can be almost anything -- a hash, a short string, an
off-chain document reference. What actually carries trust is the signature:

```solidity
bytes32 dataHash = keccak256(abi.encode(identityAddress, claimTopic, data));
bytes32 signedHash = MessageHashUtils.toEthSignedMessageHash(dataHash);
address recovered = ECDSA.recover(signedHash, signature);
```

Anyone can call `addClaim` on an identity contract and attach any signature
they want -- that's fine, because a claim only counts if `isClaimValid` on
the named issuer recomputes this exact hash and recovers an address holding
a `CLAIM_SIGNER` key on that issuer's contract. Submission is permissionless;
validity is not.

## The mistake that costs the most debugging time

The hash signed off-chain has to byte-for-byte match what `isClaimValid`
recomputes on-chain. Sign with `abi.encodePacked`, verify with `abi.encode`
(or vice versa), and the recovered address won't match the real signer --
**there is no revert**. `isVerified` just quietly returns `false`, and
without knowing to check the encoding specifically, this can burn an hour of
debugging time chasing the wrong thing. Keep the off-chain signing code and
the on-chain verification using the exact same encoding, ideally sharing a
single helper (see `test/utils/ClaimSigner.sol`) rather than reimplementing
the hash construction in more than one place.

## Revocation

Two distinct ways a claim stops being valid, with different blast radii:

- **`identity.removeClaim(claimId)`** -- revokes one claim, for one investor.
- **`trustedIssuersRegistry.removeTrustedIssuer(issuer)`** -- instantly
  invalidates every claim that issuer ever signed, for every investor, across
  every token pointed at that registry. This is the actual root-of-trust
  control in the system; see `docs/compliance-modules.md` and the security
  checklist for why its ownership deserves the tightest access control of
  any contract in the suite.
