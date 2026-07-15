// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/ITrustedIssuersRegistry.sol";

/**
 * @title TrustedIssuersRegistry
 * @notice Tracks which claim-issuer addresses are trusted, and for which claim topics.
 *
 * SECURITY NOTE:
 * This is the highest-leverage administrative control in the whole system.
 * Removing an issuer here instantly invalidates every claim it ever signed,
 * across every Identity Registry that points at this contract -- no need to
 * touch individual investor identities. Ownership of this contract should
 * never share a hot key with day-to-day agent operations (minting, freezing).
 * A compromised owner key here is equivalent to a compromised compliance
 * program for every token relying on it.
 */
contract TrustedIssuersRegistry is ITrustedIssuersRegistry {
    address public owner;

    IClaimIssuer[] private _trustedIssuers;
    mapping(address => uint256[]) private _issuerClaimTopics;
    mapping(address => bool) private _isTrusted;

    modifier onlyOwner() {
        require(msg.sender == owner, "TIR: not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    function addTrustedIssuer(IClaimIssuer _trustedIssuer, uint256[] calldata _claimTopics) external onlyOwner {
        require(!_isTrusted[address(_trustedIssuer)], "TIR: already trusted");
        _trustedIssuers.push(_trustedIssuer);
        _isTrusted[address(_trustedIssuer)] = true;
        _issuerClaimTopics[address(_trustedIssuer)] = _claimTopics;
    }

    function removeTrustedIssuer(IClaimIssuer _trustedIssuer) external onlyOwner {
        require(_isTrusted[address(_trustedIssuer)], "TIR: not trusted");
        _isTrusted[address(_trustedIssuer)] = false;
        delete _issuerClaimTopics[address(_trustedIssuer)];

        for (uint256 i = 0; i < _trustedIssuers.length; i++) {
            if (address(_trustedIssuers[i]) == address(_trustedIssuer)) {
                _trustedIssuers[i] = _trustedIssuers[_trustedIssuers.length - 1];
                _trustedIssuers.pop();
                break;
            }
        }
    }

    function updateIssuerClaimTopics(IClaimIssuer _trustedIssuer, uint256[] calldata _claimTopics)
        external
        onlyOwner
    {
        require(_isTrusted[address(_trustedIssuer)], "TIR: not trusted");
        _issuerClaimTopics[address(_trustedIssuer)] = _claimTopics;
    }

    function getTrustedIssuers() external view returns (IClaimIssuer[] memory) {
        return _trustedIssuers;
    }

    function hasClaimTopic(address _issuer, uint256 _claimTopic) external view returns (bool) {
        uint256[] memory topics = _issuerClaimTopics[_issuer];
        for (uint256 i = 0; i < topics.length; i++) {
            if (topics[i] == _claimTopic) return true;
        }
        return false;
    }

    function isTrustedIssuer(address _issuer) external view returns (bool) {
        return _isTrusted[_issuer];
    }
}
