// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Minimal ERC-734 (keys) + ERC-735 (claims) interface for an ONCHAINID identity contract.
interface IIdentity {
    struct Claim {
        uint256 topic;
        uint256 scheme;
        address issuer;
        bytes signature;
        bytes data;
        string uri;
    }

    event ClaimAdded(bytes32 indexed claimId, uint256 indexed topic, address indexed issuer);
    event ClaimRemoved(bytes32 indexed claimId, uint256 indexed topic, address indexed issuer);
    event KeyAdded(bytes32 indexed key, uint256 indexed purpose, uint256 keyType);

    function addKey(bytes32 _key, uint256 _purpose, uint256 _keyType) external returns (bool);
    function keyHasPurpose(bytes32 _key, uint256 _purpose) external view returns (bool);

    function addClaim(
        uint256 _topic,
        uint256 _scheme,
        address _issuer,
        bytes calldata _signature,
        bytes calldata _data,
        string calldata _uri
    ) external returns (bytes32 claimId);

    function removeClaim(bytes32 _claimId) external returns (bool);

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
        );

    function getClaimIdsByTopic(uint256 _topic) external view returns (bytes32[] memory claimIds);
}
