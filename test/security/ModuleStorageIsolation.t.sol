// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../utils/T3643TestBase.sol";
import "../../contracts/compliance/modules/MaxBalanceModule.sol";
import "../../contracts/compliance/ModularCompliance.sol";

/// @notice A single module contract instance is meant to be reused across many
/// different tokens' compliance contracts. This test proves rules set for one
/// compliance instance never leak into another -- the entire reason every
/// module namespaces its mappings by `compliance` address first.
contract ModuleStorageIsolationTest is T3643TestBase {
    address alice = address(0x1);
    ModularCompliance complianceB;
    Token tokenB;

    function setUp() public {
        _deployBaseSuite();
        _onboard(alice, 840);

        // Stand up a second, independent token + compliance pair, reusing the
        // SAME MaxBalanceModule contract instance as the first token.
        complianceB = new ModularCompliance();
        tokenB = new Token("Second Bond", "TBOND2", address(identityRegistry), address(complianceB));
        complianceB.bindToken(address(tokenB));
        tokenB.addAgent(agent);
    }

    function test_MaxBalanceCapDoesNotLeakAcrossTokens() public {
        MaxBalanceModule module = new MaxBalanceModule();
        compliance.addModule(address(module));
        complianceB.addModule(address(module));

        module.setMaxBalance(address(compliance), 100e18);
        module.setMaxBalance(address(complianceB), 5000e18);

        vm.prank(agent);
        vm.expectRevert("Token: compliance check failed");
        token.mint(alice, 200e18); // exceeds token A's 100e18 cap

        vm.prank(agent);
        tokenB.mint(alice, 200e18); // well within token B's 5000e18 cap
        assertEq(tokenB.balanceOf(alice), 200e18);
    }
}
