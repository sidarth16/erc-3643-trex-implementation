// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../utils/T3643TestBase.sol";
import "../../contracts/compliance/modules/MaxBalanceModule.sol";

contract MaxBalanceModuleFuzzTest is T3643TestBase {
    address alice = address(0x1);
    MaxBalanceModule module;

    function setUp() public {
        _deployBaseSuite();
        _onboard(alice, 840);
        module = new MaxBalanceModule();
        compliance.addModule(address(module));
    }

    function testFuzz_MaxBalanceNeverExceeded(uint256 cap, uint256 mintAmount) public {
        cap = bound(cap, 1e18, 1_000_000e18);
        mintAmount = bound(mintAmount, 0, 2_000_000e18);

        module.setMaxBalance(address(compliance), cap);

        vm.prank(agent);
        if (mintAmount > cap) {
            vm.expectRevert("Token: compliance check failed");
            token.mint(alice, mintAmount);
        } else {
            token.mint(alice, mintAmount);
            assertLe(token.balanceOf(alice), cap);
        }
    }

    function testFuzz_UncappedWhenLimitIsZero(uint256 mintAmount) public {
        mintAmount = bound(mintAmount, 0, 10_000_000e18);
        // maxBalance defaults to 0 == uncapped
        vm.prank(agent);
        token.mint(alice, mintAmount);
        assertEq(token.balanceOf(alice), mintAmount);
    }
}
