// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/IModule.sol";
import "../../interfaces/IToken.sol";
import "../../interfaces/IModularCompliance.sol";

/**
 * @title MaxBalanceModule
 * @dev PATTERN: Delegated state.
 *
 * This looks like it should track "how many tokens does each investor hold"
 * itself, but it deliberately doesn't -- it reads `token.balanceOf()` directly.
 * The token's balance is already the ground truth; duplicating it into module
 * storage would just create a second copy that can drift out of sync with the
 * first (e.g. if a forced transfer or burn happens through a path the module
 * doesn't hook into). Not every rule that "sounds stateful" needs its own
 * storage -- check whether the answer already exists somewhere else first.
 */
contract MaxBalanceModule is IModule {
    mapping(address => uint256) public maxBalance; // compliance => cap, 0 = uncapped

    address public owner;
    modifier onlyOwner() { require(msg.sender == owner, "MBM: not owner"); _; }
    constructor() { owner = msg.sender; }

    function setMaxBalance(address compliance, uint256 cap) external onlyOwner {
        maxBalance[compliance] = cap;
    }

    function moduleCheck(address, address to, uint256 amount, address compliance)
        external
        view
        override
        returns (bool)
    {
        uint256 cap = maxBalance[compliance];
        if (cap == 0) return true;

        address token = IModularCompliance(compliance).tokenBound();
        if (token == address(0)) return true;

        return IToken(token).balanceOf(to) + amount <= cap;
    }

    function moduleTransferAction(address, address, uint256) external override {}
    function moduleMintAction(address, uint256) external override {}
    function moduleBurnAction(address, uint256) external override {}

    function canComplianceBind(address) external pure override returns (bool) { return true; }
    function isPlugAndPlay() external pure override returns (bool) { return true; }
}
