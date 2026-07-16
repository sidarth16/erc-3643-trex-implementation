// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../utils/T3643TestBase.sol";
import "../../contracts/compliance/modules/MaxBalanceModule.sol";
import "../../contracts/compliance/modules/CountryRestrictModule.sol";
import "../../contracts/interfaces/IModule.sol";

contract ModularComplianceUnitTest is T3643TestBase {
    address alice = address(0x1);
    address bob = address(0x2);

    function setUp() public {
        _deployBaseSuite();
        _onboard(alice, 840);
        _onboard(bob, 276);
    }

    function test_RevertAddingSameModuleTwice() public {
        MaxBalanceModule module = new MaxBalanceModule();
        compliance.addModule(address(module));

        vm.expectRevert("MC: module already bound");
        compliance.addModule(address(module));
    }

    function test_RemoveModuleStopsEnforcement() public {
        MaxBalanceModule module = new MaxBalanceModule();
        compliance.addModule(address(module));
        module.setMaxBalance(address(compliance), 100e18);

        vm.prank(agent);
        vm.expectRevert("Token: compliance check failed");
        token.mint(alice, 200e18);

        compliance.removeModule(address(module));

        vm.prank(agent);
        token.mint(alice, 200e18); // succeeds once the cap is no longer enforced
        assertEq(token.balanceOf(alice), 200e18);
    }

    function test_ModulesShortCircuitOnFirstFalse() public {
        // Bind a module that always rejects, and one that would revert if
        // ever reached -- proves canTransfer short-circuits rather than
        // evaluating every module unconditionally.
        AlwaysRejectModule reject = new AlwaysRejectModule();
        RevertIfCalledModule neverCalled = new RevertIfCalledModule();
        compliance.addModule(address(reject));
        compliance.addModule(address(neverCalled));

        vm.prank(agent);
        vm.expectRevert("Token: compliance check failed");
        token.mint(alice, 100e18);
    }

    function test_OnlyBoundTokenCanNotifyCompliance() public {
        vm.expectRevert("MC: caller is not the bound token");
        compliance.transferred(alice, bob, 100e18);
    }
}

contract AlwaysRejectModule is IModule {
    function moduleCheck(address, address, uint256, address) external pure override returns (bool) {
        return false;
    }
    function moduleTransferAction(address, address, uint256) external override {}
    function moduleMintAction(address, uint256) external override {}
    function moduleBurnAction(address, uint256) external override {}
    function canComplianceBind(address) external pure override returns (bool) { return true; }
    function isPlugAndPlay() external pure override returns (bool) { return true; }
}

contract RevertIfCalledModule is IModule {
    function moduleCheck(address, address, uint256, address) external pure override returns (bool) {
        revert("should never be reached after AlwaysRejectModule returns false");
    }
    function moduleTransferAction(address, address, uint256) external override {}
    function moduleMintAction(address, uint256) external override {}
    function moduleBurnAction(address, uint256) external override {}
    function canComplianceBind(address) external pure override returns (bool) { return true; }
    function isPlugAndPlay() external pure override returns (bool) { return true; }
}
