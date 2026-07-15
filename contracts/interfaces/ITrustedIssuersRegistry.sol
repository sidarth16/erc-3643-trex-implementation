// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IClaimIssuer.sol";

interface ITrustedIssuersRegistry {
    function addTrustedIssuer(IClaimIssuer _trustedIssuer, uint256[] calldata _claimTopics) external;
    function removeTrustedIssuer(IClaimIssuer _trustedIssuer) external;
    function updateIssuerClaimTopics(IClaimIssuer _trustedIssuer, uint256[] calldata _claimTopics) external;

    function getTrustedIssuers() external view returns (IClaimIssuer[] memory);
    function hasClaimTopic(address _issuer, uint256 _claimTopic) external view returns (bool);
    function isTrustedIssuer(address _issuer) external view returns (bool);
}
