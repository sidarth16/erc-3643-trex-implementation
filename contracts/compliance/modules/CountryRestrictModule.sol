// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/IModule.sol";
import "../../interfaces/IIdentityRegistry.sol";
import "../../interfaces/IToken.sol";
import "../../interfaces/IModularCompliance.sol";

/**
 * @title CountryRestrictModule
 * @dev PATTERN: Stateless read.
 *
 * This module holds no per-transfer bookkeeping of its own -- it just reads
 * the receiver's country from the Identity Registry at check time and
 * compares it against a restriction list. Because there's nothing to record
 * after a transfer succeeds, all three action hooks stay empty. This is the
 * right shape for any rule that only depends on state another contract
 * already tracks (identity, country, balance).
 */
contract CountryRestrictModule is IModule {
    mapping(address => mapping(uint16 => bool)) public isCountryRestricted; // compliance => country => restricted

    address public owner;
    modifier onlyOwner() { require(msg.sender == owner, "CRM: not owner"); _; }
    constructor() { owner = msg.sender; }

    function setCountryRestricted(address compliance, uint16 country, bool restricted) external onlyOwner {
        isCountryRestricted[compliance][country] = restricted;
    }

    function moduleCheck(address, address to, uint256, address compliance)
        external
        view
        override
        returns (bool)
    {
        address token = IModularCompliance(compliance).tokenBound();
        if (token == address(0)) return true; // not bound yet, nothing to check against

        IIdentityRegistry ir = IIdentityRegistry(IToken(token).identityRegistry());
        uint16 country = ir.investorCountry(to);
        return !isCountryRestricted[compliance][country];
    }

    function moduleTransferAction(address, address, uint256) external override {}
    function moduleMintAction(address, uint256) external override {}
    function moduleBurnAction(address, uint256) external override {}

    function canComplianceBind(address) external pure override returns (bool) { return true; }
    function isPlugAndPlay() external pure override returns (bool) { return true; }
}
