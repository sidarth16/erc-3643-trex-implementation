// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IIdentity.sol";

interface IIdentityRegistryStorage {
    function bindIdentityRegistry(address _identityRegistry) external;

    function addIdentityToStorage(address _userAddress, IIdentity _identity, uint16 _country) external;
    function removeIdentityFromStorage(address _userAddress) external;
    function modifyStoredInvestorCountry(address _userAddress, uint16 _country) external;
    function modifyStoredIdentity(address _userAddress, IIdentity _identity) external;

    function storedIdentity(address _userAddress) external view returns (IIdentity);
    function storedInvestorCountry(address _userAddress) external view returns (uint16);
}
