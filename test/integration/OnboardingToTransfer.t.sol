// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../utils/T3643TestBase.sol";
import "../../contracts/compliance/modules/LockupModule.sol";
import "../../contracts/compliance/modules/CountryRestrictModule.sol";

/// @notice End-to-end flows spanning claim issuance, onboarding, minting,
/// transfer, forced transfer, freezing, and claim revocation -- the full loop
/// a real deployment goes through, rather than one contract in isolation.
contract OnboardingToTransferIntegrationTest is T3643TestBase {
    address alice = address(0x1);
    address bob = address(0x2);

    function setUp() public {
        _deployBaseSuite();
    }

    function test_FullLifecycle_OnboardMintTransfer() public {
        _onboard(alice, 840);
        _onboard(bob, 276);

        vm.prank(agent);
        token.mint(alice, 1000e18);

        vm.prank(alice);
        token.transfer(bob, 250e18);

        assertEq(token.balanceOf(alice), 750e18);
        assertEq(token.balanceOf(bob), 250e18);
    }

    function test_LockupModuleBlocksThenAllowsAfterUnlock() public {
        _onboard(alice, 840);
        _onboard(bob, 276);

        LockupModule lockup = new LockupModule();
        compliance.addModule(address(lockup));
        lockup.setUnlockTime(address(compliance), alice, block.timestamp + 30 days);

        vm.prank(agent);
        token.mint(alice, 1000e18);

        vm.prank(alice);
        vm.expectRevert("Token: compliance check failed");
        token.transfer(bob, 100e18);

        vm.warp(block.timestamp + 31 days);

        vm.prank(alice);
        token.transfer(bob, 100e18);
        assertEq(token.balanceOf(bob), 100e18);
    }

    function test_CountryRestrictionBlocksSanctionedJurisdiction() public {
        _onboard(alice, 840);
        _onboard(bob, 276);

        CountryRestrictModule countryModule = new CountryRestrictModule();
        compliance.addModule(address(countryModule));
        countryModule.setCountryRestricted(address(compliance), 276, true); // restrict Germany

        vm.prank(agent);
        token.mint(alice, 1000e18);

        vm.prank(alice);
        vm.expectRevert("Token: compliance check failed");
        token.transfer(bob, 100e18);
    }

    function test_ClaimRevocationBlocksFutureTransfersButNotExistingBalance() public {
        _onboard(alice, 840);
        _onboard(bob, 276);

        vm.prank(agent);
        token.mint(alice, 1000e18);

        // Revoke the trusted issuer entirely -- this invalidates every claim
        // it ever signed, for both alice and bob, instantly and without
        // touching either investor's identity contract directly.
        tir.removeTrustedIssuer(claimIssuer);
        assertFalse(identityRegistry.isVerified(alice));
        assertFalse(identityRegistry.isVerified(bob));

        // Existing balance is untouched by the revocation...
        assertEq(token.balanceOf(alice), 1000e18);

        // ...but no further transfer TO bob can succeed, since the receiver
        // must pass isVerified at transfer time, not just at onboarding time.
        vm.prank(alice);
        vm.expectRevert("Token: receiver not verified");
        token.transfer(bob, 100e18);
    }

    function test_ForcedTransferRecoversFromCompromisedWallet() public {
        _onboard(alice, 840);
        address newWallet = address(0x777);
        _onboard(newWallet, 840);

        vm.prank(agent);
        token.mint(alice, 1000e18);

        // Simulate lost-key recovery: agent force-moves the full balance to
        // a fresh, already-onboarded wallet.
        vm.prank(agent);
        token.forcedTransfer(alice, newWallet, 1000e18);

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(newWallet), 1000e18);
    }
}
