// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IClaimTopicsRegistry.sol";

/**
 * @title ClaimTopicsRegistry
 * @notice Defines which claim topics a specific token requires for an investor
 * to count as "verified". Topic IDs are just uint256s with no on-chain meaning --
 * the meaning (1 = KYC, 7 = accredited investor, etc.) is a convention agreed
 * between the issuer and its claim providers off-chain.
 *
 * DESIGN NOTE:
 * Different tokens under the same issuer can require different topic sets by
 * simply pointing at different ClaimTopicsRegistry instances, while still
 * sharing the same Trusted Issuers Registry and investor ONCHAINIDs.
 */
contract ClaimTopicsRegistry is IClaimTopicsRegistry {
    address public owner;
    uint256[] private _claimTopics;

    modifier onlyOwner() {
        require(msg.sender == owner, "CTR: not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    function addClaimTopic(uint256 _claimTopic) external onlyOwner {
        for (uint256 i = 0; i < _claimTopics.length; i++) {
            require(_claimTopics[i] != _claimTopic, "CTR: topic already exists");
        }
        _claimTopics.push(_claimTopic);
    }

    function removeClaimTopic(uint256 _claimTopic) external onlyOwner {
        for (uint256 i = 0; i < _claimTopics.length; i++) {
            if (_claimTopics[i] == _claimTopic) {
                _claimTopics[i] = _claimTopics[_claimTopics.length - 1];
                _claimTopics.pop();
                break;
            }
        }
    }

    function getClaimTopics() external view returns (uint256[] memory) {
        return _claimTopics;
    }
}
