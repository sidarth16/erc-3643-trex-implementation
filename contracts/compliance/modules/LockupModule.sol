// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/IModule.sol";

/**
 * @title LockupModule
 * @dev PATTERN: Time-based rule.
 *
 * Blocks outbound transfers from an investor's wallet until a per-investor
 * unlock timestamp passes -- the on-chain equivalent of a vesting cliff or a
 * Reg D/Reg S holding period. Unlike TransferVolumeModule, this needs no
 * action-hook bookkeeping at all: `block.timestamp` is already the ground
 * truth for "has enough time passed," so all three action hooks stay empty,
 * same as the stateless CountryRestrictModule.
 */
contract LockupModule is IModule {
    mapping(address => mapping(address => uint256)) public unlockTime; // compliance => investor => timestamp

    address public owner;
    modifier onlyOwner() { require(msg.sender == owner, "LM: not owner"); _; }
    constructor() { owner = msg.sender; }

    function setUnlockTime(address compliance, address investor, uint256 timestamp) external onlyOwner {
        unlockTime[compliance][investor] = timestamp;
    }

    function moduleCheck(address from, address, uint256, address compliance)
        external
        view
        override
        returns (bool)
    {
        uint256 unlock = unlockTime[compliance][from];
        return unlock == 0 || block.timestamp >= unlock;
    }

    function moduleTransferAction(address, address, uint256) external override {}
    function moduleMintAction(address, uint256) external override {}
    function moduleBurnAction(address, uint256) external override {}

    function canComplianceBind(address) external pure override returns (bool) { return true; }
    function isPlugAndPlay() external pure override returns (bool) { return true; }
}
