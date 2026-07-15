// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/IModule.sol";

/**
 * @title TransferVolumeModule
 * @dev PATTERN: Genuine state tracking.
 *
 * A rolling 30-day per-investor transfer volume cap. Unlike MaxBalanceModule,
 * there is no existing ground truth to read for "how much has this investor
 * moved in the last 30 days" -- the token doesn't track that, so the module
 * has to maintain its own rolling window.
 *
 * CRITICAL INVARIANT: `moduleCheck` only READS the window; only
 * `moduleTransferAction`/`moduleBurnAction` (which fire after a transfer is
 * already guaranteed to succeed) WRITE to it. If a write ever happened inside
 * moduleCheck, a transfer that passed this module's check but was then
 * rejected by a DIFFERENT bound module would still have consumed volume that
 * never actually moved -- corrupting the investor's limit for no reason.
 */
contract TransferVolumeModule is IModule {
    struct Window {
        uint256 windowStart;
        uint256 volumeInWindow;
    }

    mapping(address => mapping(address => Window)) public windows; // compliance => investor => window
    mapping(address => uint256) public monthlyLimit; // compliance => cap, 0 = uncapped
    uint256 public constant WINDOW = 30 days;

    address public owner;
    modifier onlyOwner() { require(msg.sender == owner, "TVM: not owner"); _; }
    constructor() { owner = msg.sender; }

    function setMonthlyLimit(address compliance, uint256 limit) external onlyOwner {
        monthlyLimit[compliance] = limit;
    }

    function moduleCheck(address from, address, uint256 amount, address compliance)
        external
        view
        override
        returns (bool)
    {
        uint256 limit = monthlyLimit[compliance];
        if (limit == 0) return true;

        Window memory w = windows[compliance][from];
        uint256 currentVolume = block.timestamp >= w.windowStart + WINDOW ? 0 : w.volumeInWindow;
        return currentVolume + amount <= limit;
    }

    function moduleTransferAction(address from, address, uint256 amount) external override {
        _recordVolume(msg.sender, from, amount);
    }

    function moduleBurnAction(address from, uint256 amount) external override {
        _recordVolume(msg.sender, from, amount);
    }

    function moduleMintAction(address, uint256) external override {
        // minting doesn't draw down an investor's outbound transfer allowance
    }

    function _recordVolume(address compliance, address investor, uint256 amount) internal {
        Window storage w = windows[compliance][investor];
        if (block.timestamp >= w.windowStart + WINDOW) {
            w.windowStart = block.timestamp;
            w.volumeInWindow = amount;
        } else {
            w.volumeInWindow += amount;
        }
    }

    function canComplianceBind(address) external pure override returns (bool) { return true; }
    function isPlugAndPlay() external pure override returns (bool) { return true; }
}
