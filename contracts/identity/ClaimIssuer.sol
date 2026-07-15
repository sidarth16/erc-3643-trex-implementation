// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "../interfaces/IClaimIssuer.sol";
import "../interfaces/IIdentity.sol";
import "./Identity.sol";

/**
 * @title ClaimIssuer
 * @notice A claim issuer is itself an Identity contract (it can hold its own keys),
 * plus the ability to verify claims it has signed.
 *
 * SECURITY NOTE (read this before wiring a Trusted Issuers Registry):
 * `isClaimValid` is the single highest-leverage function in the entire T-REX
 * system. It recomputes the signed hash and recovers the signer — if that
 * recovered address holds a CLAIM_SIGNER key on THIS contract, the claim is
 * valid. Compromise of the private key behind a CLAIM_SIGNER key is
 * equivalent to the ability to mint arbitrary "verified" status for any
 * address. Treat these keys as the actual root of trust, not the token owner.
 */
contract ClaimIssuer is Identity, IClaimIssuer {
    constructor(address initialManagementKey) Identity(initialManagementKey, false) {}

    /// @notice Recomputes keccak256(identity, topic, data), applies the Ethereum
    /// signed message prefix, recovers the signer, and checks that signer holds
    /// a CLAIM_SIGNER (purpose 3) key on this issuer contract.
    ///
    /// COMMON MISTAKE: signing off-chain with abi.encodePacked but verifying here
    /// with abi.encode (or vice versa) produces a different hash and therefore a
    /// different recovered address. The claim will silently read as invalid --
    /// there's no revert to point you at the bug. Keep off-chain signing code and
    /// this function using the exact same encoding.
    function isClaimValid(
        IIdentity _identity,
        uint256 _claimTopic,
        bytes calldata _sig,
        bytes calldata _data
    ) external view override returns (bool) {
        bytes32 dataHash = keccak256(abi.encode(address(_identity), _claimTopic, _data));
        bytes32 signedHash = MessageHashUtils.toEthSignedMessageHash(dataHash);
        address recovered = ECDSA.recover(signedHash, _sig);
        return keyHasPurpose(keccak256(abi.encode(recovered)), CLAIM_SIGNER_PURPOSE);
    }
}
