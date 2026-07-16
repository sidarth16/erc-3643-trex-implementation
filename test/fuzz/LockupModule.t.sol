// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../utils/T3643TestBase.sol";
import "../../contracts/compliance/modules/LockupModule.sol";

contract LockupModuleFuzzTest is T3643TestBase {
    address alice = address(0x1);
    address bob = address(0x2);
    LockupModule module;

    function setUp() public {
        _deployBaseSuite();
        _onboard(alice, 840);
        _onboard(bob, 276);
        module = new LockupModule();
        compliance.addModule(address(module));

        vm.prank(agent);
        token.mint(alice, 1000e18);
    }

    function testFuzz_TransferBlockedBeforeUnlockAllowedAfter(uint256 unlockDelay, uint256 warpAmount) public {
        unlockDelay = bound(unlockDelay, 1, 365 days);
        warpAmount = bound(warpAmount, 0, 730 days);

        module.setUnlockTime(address(compliance), alice, block.timestamp + unlockDelay);
        vm.warp(block.timestamp + warpAmount);

        vm.prank(alice);
        if (warpAmount < unlockDelay) {
            vm.expectRevert("Token: compliance check failed");
            token.transfer(bob, 10e18);
        } else {
            token.transfer(bob, 10e18);
            assertEq(token.balanceOf(bob), 10e18);
        }
    }
}
