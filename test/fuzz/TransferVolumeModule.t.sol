// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../utils/T3643TestBase.sol";
import "../../contracts/compliance/modules/TransferVolumeModule.sol";

contract TransferVolumeModuleFuzzTest is T3643TestBase {
    address alice = address(0x1);
    address bob = address(0x2);
    TransferVolumeModule module;

    function setUp() public {
        _deployBaseSuite();
        _onboard(alice, 840);
        _onboard(bob, 276);
        module = new TransferVolumeModule();
        compliance.addModule(address(module));

        vm.prank(agent);
        token.mint(alice, 10_000_000e18);
    }

    function testFuzz_VolumeNeverExceedsMonthlyLimitWithinWindow(uint256 limit, uint256 amount1, uint256 amount2)
        public
    {
        limit = bound(limit, 1e18, 1_000_000e18);
        amount1 = bound(amount1, 0, 2_000_000e18);
        amount2 = bound(amount2, 0, 2_000_000e18);

        module.setMonthlyLimit(address(compliance), limit);

        vm.prank(alice);
        if (amount1 > limit) {
            vm.expectRevert("Token: compliance check failed");
            token.transfer(bob, amount1);
            return;
        }
        token.transfer(bob, amount1);

        vm.prank(alice);
        if (amount1 + amount2 > limit) {
            vm.expectRevert("Token: compliance check failed");
            token.transfer(bob, amount2);
        } else {
            token.transfer(bob, amount2);
        }
    }

    function testFuzz_WindowResetsAfterThirtyDays(uint256 limit) public {
        limit = bound(limit, 1e18, 1_000_000e18);
        module.setMonthlyLimit(address(compliance), limit);

        vm.prank(alice);
        token.transfer(bob, limit); // use up the full window

        vm.warp(block.timestamp + 31 days);

        // A fresh window should allow the full limit again.
        vm.prank(alice);
        token.transfer(bob, limit);
    }
}
