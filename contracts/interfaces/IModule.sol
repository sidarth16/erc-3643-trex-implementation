// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IModule {
    function moduleCheck(
        address _from,
        address _to,
        uint256 _value,
        address _compliance
    ) external view returns (bool);

    function moduleTransferAction(address _from, address _to, uint256 _value) external;
    function moduleMintAction(address _to, uint256 _value) external;
    function moduleBurnAction(address _from, uint256 _value) external;

    function canComplianceBind(address _compliance) external view returns (bool);
    function isPlugAndPlay() external pure returns (bool);
}
