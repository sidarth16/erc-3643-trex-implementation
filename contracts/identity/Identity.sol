// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IIdentity.sol";

/**
 * @title Identity
 * @notice A simplified ONCHAINID implementation (ERC-734 keys + ERC-735 claims).
 *
 * ARCHITECTURE NOTE:
 * This contract is deliberately owned by the investor it represents, not by
 * the token or the issuer. That's the entire point of ONCHAINID: identity is
 * portable. One Identity contract can be reused across every T-REX token the
 * investor ever gets verified for, as long as each token's Trusted Issuers
 * Registry recognizes the same claim issuers.
 *
 * SECURITY NOTE:
 * Keys are separated by purpose (MANAGEMENT vs CLAIM_SIGNER) so an issuer's
 * signing key compromise doesn't grant control over the identity itself, and
 * so an investor's day-to-day management key never needs claim-signing rights.
 */
contract Identity is IIdentity {
    // ERC-734 key purposes
    uint256 public constant MANAGEMENT_PURPOSE = 1;
    uint256 public constant ACTION_PURPOSE = 2;
    uint256 public constant CLAIM_SIGNER_PURPOSE = 3;

    mapping(bytes32 => mapping(uint256 => bool)) private _keyPurposes; // key => purpose => held
    mapping(bytes32 => Claim) private _claims;
    mapping(uint256 => bytes32[]) private _claimsByTopic;

    address public owner;

    modifier onlyManagementKeyOrOwner() {
        require(
            msg.sender == owner || keyHasPurpose(keccak256(abi.encode(msg.sender)), MANAGEMENT_PURPOSE),
            "Identity: not authorized"
        );
        _;
    }

    constructor(address initialManagementKey, bool /*isLibrary*/) {
        owner = initialManagementKey;
        _keyPurposes[keccak256(abi.encode(initialManagementKey))][MANAGEMENT_PURPOSE] = true;
    }

    // ---- ERC-734: Keys ----

    function addKey(bytes32 _key, uint256 _purpose, uint256 /*_keyType*/)
        external
        onlyManagementKeyOrOwner
        returns (bool)
    {
        _keyPurposes[_key][_purpose] = true;
        emit KeyAdded(_key, _purpose, 1);
        return true;
    }

    function keyHasPurpose(bytes32 _key, uint256 _purpose) public view returns (bool) {
        return _keyPurposes[_key][_purpose];
    }

    // ---- ERC-735: Claims ----

    /// @notice Anyone can submit a claim on behalf of the identity, but it only carries
    /// weight if `isClaimValid` on the issuer recomputes a valid signature from a
    /// registered CLAIM_SIGNER key. Accepting submission from anyone (not just the
    /// owner) mirrors real ONCHAINID behavior: claim issuers often push claims directly.
    function addClaim(
        uint256 _topic,
        uint256 _scheme,
        address _issuer,
        bytes calldata _signature,
        bytes calldata _data,
        string calldata _uri
    ) external returns (bytes32 claimId) {
        claimId = keccak256(abi.encode(_issuer, _topic));
        _claims[claimId] = Claim(_topic, _scheme, _issuer, _signature, _data, _uri);
        _claimsByTopic[_topic].push(claimId);
        emit ClaimAdded(claimId, _topic, _issuer);
    }

    function removeClaim(bytes32 _claimId) external onlyManagementKeyOrOwner returns (bool) {
        Claim memory c = _claims[_claimId];
        require(c.issuer != address(0), "Identity: claim not found");

        bytes32[] storage ids = _claimsByTopic[c.topic];
        for (uint256 i = 0; i < ids.length; i++) {
            if (ids[i] == _claimId) {
                ids[i] = ids[ids.length - 1];
                ids.pop();
                break;
            }
        }
        delete _claims[_claimId];
        emit ClaimRemoved(_claimId, c.topic, c.issuer);
        return true;
    }

    function getClaim(bytes32 _claimId)
        external
        view
        returns (
            uint256 topic,
            uint256 scheme,
            address issuer,
            bytes memory signature,
            bytes memory data,
            string memory uri
        )
    {
        Claim memory c = _claims[_claimId];
        return (c.topic, c.scheme, c.issuer, c.signature, c.data, c.uri);
    }

    function getClaimIdsByTopic(uint256 _topic) external view returns (bytes32[] memory) {
        return _claimsByTopic[_topic];
    }
}
