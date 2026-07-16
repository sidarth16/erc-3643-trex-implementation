// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../utils/T3643TestBase.sol";
import "../../contracts/compliance/modules/CountryRestrictModule.sol";

contract CountryRestrictModuleFuzzTest is T3643TestBase {
    address alice = address(0x1);
    address bob = address(0x2);
    CountryRestrictModule module;

    function setUp() public {
        _deployBaseSuite();
        module = new CountryRestrictModule();
        compliance.addModule(address(module));
    }

    function testFuzz_RestrictedCountryAlwaysBlocked(uint16 country, uint256 amount) public {
        vm.assume(country > 1 && country < 1000); // must differ from alice's own country (1)
        amount = bound(amount, 1, 1_000_000e18);

        _onboard(alice, 1); // arbitrary sender country, not restricted
        _onboard(bob, country);
        module.setCountryRestricted(address(compliance), country, true);

        vm.prank(agent);
        token.mint(alice, amount);

        vm.prank(alice);
        vm.expectRevert("Token: compliance check failed");
        token.transfer(bob, amount);
    }

    function testFuzz_UnrestrictedCountryAlwaysAllowed(uint16 country, uint256 amount) public {
        vm.assume(country > 0 && country < 1000);
        amount = bound(amount, 1, 1_000_000e18);

        _onboard(alice, 1);
        _onboard(bob, country);
        // no restriction set

        vm.prank(agent);
        token.mint(alice, amount);

        vm.prank(alice);
        token.transfer(bob, amount);
        assertEq(token.balanceOf(bob), amount);
    }
}
