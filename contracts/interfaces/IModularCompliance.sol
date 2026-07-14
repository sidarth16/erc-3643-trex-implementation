// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IModularCompliance {
    function bindToken(address _token) external;
    function unbindToken(address _token) external;
    function tokenBound() external view returns (address);

    function addModule(address _module) external;
    function removeModule(address _module) external;
    function isModuleBound(address _module) external view returns (bool);

    function canTransfer(address _from, address _to, uint256 _amount) external view returns (bool);
    function transferred(address _from, address _to, uint256 _amount) external;
    function created(address _to, uint256 _amount) external;
    function destroyed(address _from, uint256 _amount) external;
}
