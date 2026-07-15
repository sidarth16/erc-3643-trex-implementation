// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IIdentityRegistryStorage.sol";
import "../interfaces/IIdentity.sol";

/**
 * @title IdentityRegistryStorage
 * @notice Pure storage layer: address => ONCHAINID, address => country code.
 *
 * ARCHITECTURE NOTE:
 * This is split out from IdentityRegistry itself so multiple Identity
 * Registries (e.g. across several tokens from the same issuer) can share one
 * storage instance -- an investor registered once is registered everywhere
 * that binds to this storage contract. `bindIdentityRegistry` is what
 * authorizes a given Identity Registry to write here.
 */
contract IdentityRegistryStorage is IIdentityRegistryStorage {
    address public owner;
    mapping(address => bool) public boundIdentityRegistries;

    mapping(address => IIdentity) private _identities;
    mapping(address => uint16) private _countries;

    modifier onlyOwner() {
        require(msg.sender == owner, "IRS: not owner");
        _;
    }

    modifier onlyBoundRegistry() {
        require(boundIdentityRegistries[msg.sender], "IRS: caller not a bound registry");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function bindIdentityRegistry(address _identityRegistry) external onlyOwner {
        boundIdentityRegistries[_identityRegistry] = true;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    function addIdentityToStorage(address _userAddress, IIdentity _identity, uint16 _country)
        external
        onlyBoundRegistry
    {
        require(address(_identities[_userAddress]) == address(0), "IRS: already registered");
        _identities[_userAddress] = _identity;
        _countries[_userAddress] = _country;
    }

    function removeIdentityFromStorage(address _userAddress) external onlyBoundRegistry {
        delete _identities[_userAddress];
        delete _countries[_userAddress];
    }

    function modifyStoredInvestorCountry(address _userAddress, uint16 _country) external onlyBoundRegistry {
        _countries[_userAddress] = _country;
    }

    function modifyStoredIdentity(address _userAddress, IIdentity _identity) external onlyBoundRegistry {
        _identities[_userAddress] = _identity;
    }

    function storedIdentity(address _userAddress) external view returns (IIdentity) {
        return _identities[_userAddress];
    }

    function storedInvestorCountry(address _userAddress) external view returns (uint16) {
        return _countries[_userAddress];
    }
}
