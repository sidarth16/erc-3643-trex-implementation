// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IIdentityRegistry.sol";
import "../interfaces/IIdentityRegistryStorage.sol";
import "../interfaces/ITrustedIssuersRegistry.sol";
import "../interfaces/IClaimTopicsRegistry.sol";
import "../interfaces/IClaimIssuer.sol";

/**
 * @title IdentityRegistry
 * @notice Answers exactly one question: "is this address verified?" It does not
 * store claims (that's the investor's ONCHAINID) and does not enforce business
 * rules (that's Modular Compliance). Keeping it single-purpose is what lets it
 * be reused, unmodified, across every token an issuer deploys.
 */
contract IdentityRegistry is IIdentityRegistry {
    IIdentityRegistryStorage public identityStorage;
    ITrustedIssuersRegistry public issuersRegistry;
    IClaimTopicsRegistry public topicsRegistry;

    address public owner;
    mapping(address => bool) public agents;

    modifier onlyAgentOrOwner() {
        require(msg.sender == owner || agents[msg.sender], "IR: not authorized");
        _;
    }

    constructor(address _storage, address _issuers, address _topics) {
        identityStorage = IIdentityRegistryStorage(_storage);
        issuersRegistry = ITrustedIssuersRegistry(_issuers);
        topicsRegistry = IClaimTopicsRegistry(_topics);
        owner = msg.sender;
    }

    function addAgent(address _agent) external {
        require(msg.sender == owner, "IR: not owner");
        agents[_agent] = true;
    }

    function transferOwnership(address newOwner) external {
        require(msg.sender == owner, "IR: not owner");
        owner = newOwner;
    }

    function registerIdentity(address _userAddress, IIdentity _identity, uint16 _country)
        external
        onlyAgentOrOwner
    {
        identityStorage.addIdentityToStorage(_userAddress, _identity, _country);
    }

    function batchRegisterIdentity(
        address[] calldata _userAddresses,
        IIdentity[] calldata _identities,
        uint16[] calldata _countries
    ) external onlyAgentOrOwner {
        require(
            _userAddresses.length == _identities.length && _identities.length == _countries.length,
            "IR: array length mismatch"
        );
        for (uint256 i = 0; i < _userAddresses.length; i++) {
            identityStorage.addIdentityToStorage(_userAddresses[i], _identities[i], _countries[i]);
        }
    }

    function deleteIdentity(address _userAddress) external onlyAgentOrOwner {
        identityStorage.removeIdentityFromStorage(_userAddress);
    }

    function updateCountry(address _userAddress, uint16 _country) external onlyAgentOrOwner {
        identityStorage.modifyStoredInvestorCountry(_userAddress, _country);
    }

    function updateIdentity(address _userAddress, IIdentity _identity) external onlyAgentOrOwner {
        identityStorage.modifyStoredIdentity(_userAddress, _identity);
    }

    function identity(address _userAddress) external view returns (IIdentity) {
        return identityStorage.storedIdentity(_userAddress);
    }

    function investorCountry(address _userAddress) external view returns (uint16) {
        return identityStorage.storedInvestorCountry(_userAddress);
    }

    /// @notice The single most-called function in the whole system. Every mint,
    /// transfer, and forcedTransfer routes through this before anything else.
    function isVerified(address _userAddress) external view returns (bool) {
        IIdentity id = identityStorage.storedIdentity(_userAddress);
        if (address(id) == address(0)) return false;

        uint256[] memory requiredTopics = topicsRegistry.getClaimTopics();
        for (uint256 i = 0; i < requiredTopics.length; i++) {
            if (!_hasValidClaimForTopic(id, requiredTopics[i])) {
                return false;
            }
        }
        return true;
    }

    /// @dev SECURITY NOTE: the try/catch here is deliberate. A claim issuer's
    /// contract is untrusted code from this registry's point of view. Without
    /// this guard, a single malformed or maliciously-upgraded issuer contract
    /// could revert `isVerified` for every investor holding a claim from it --
    /// a griefing vector that bricks verification token-wide, not just for one
    /// investor. Catching the failure and treating that one claim as invalid
    /// keeps the blast radius contained to the claim it actually belongs to.
    function _hasValidClaimForTopic(IIdentity id, uint256 topic) internal view returns (bool) {
        bytes32[] memory claimIds = id.getClaimIdsByTopic(topic);

        for (uint256 i = 0; i < claimIds.length; i++) {
            (uint256 claimTopic,, address issuer, bytes memory sig, bytes memory data,) = id.getClaim(claimIds[i]);

            if (!issuersRegistry.isTrustedIssuer(issuer)) continue;
            if (!issuersRegistry.hasClaimTopic(issuer, topic)) continue;

            try IClaimIssuer(issuer).isClaimValid(id, claimTopic, sig, data) returns (bool valid) {
                if (valid) return true;
            } catch {
                continue;
            }
        }
        return false;
    }
}
