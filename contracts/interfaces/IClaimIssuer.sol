// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IIdentity.sol";

interface IClaimIssuer {
    function isClaimValid(
        IIdentity _identity,
        uint256 _claimTopic,
        bytes calldata _sig,
        bytes calldata _data
    ) external view returns (bool);
}
