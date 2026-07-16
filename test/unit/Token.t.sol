// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../utils/T3643TestBase.sol";

contract TokenUnitTest is T3643TestBase {
    address alice = address(0x1);
    address bob = address(0x2);
    address stranger = address(0x999);

    function setUp() public {
        _deployBaseSuite();
        _onboard(alice, 840); // US
        _onboard(bob, 276);   // Germany
    }

    function test_MintToVerifiedInvestor() public {
        vm.prank(agent);
        token.mint(alice, 1000e18);
        assertEq(token.balanceOf(alice), 1000e18);
    }

    function test_RevertMintToUnverifiedWallet() public {
        vm.prank(agent);
        vm.expectRevert("Token: receiver not verified");
        token.mint(stranger, 1000e18);
    }

    function test_RevertMintFromNonAgent() public {
        vm.prank(alice);
        vm.expectRevert("Token: not agent");
        token.mint(alice, 1000e18);
    }

    function test_TransferBetweenVerifiedInvestors() public {
        vm.prank(agent);
        token.mint(alice, 1000e18);

        vm.prank(alice);
        token.transfer(bob, 400e18);

        assertEq(token.balanceOf(alice), 600e18);
        assertEq(token.balanceOf(bob), 400e18);
    }

    function test_RevertTransferToUnverifiedWallet() public {
        vm.prank(agent);
        token.mint(alice, 1000e18);

        vm.prank(alice);
        vm.expectRevert("Token: receiver not verified");
        token.transfer(stranger, 100e18);
    }

    function test_ForcedTransferByAgent() public {
        vm.prank(agent);
        token.mint(alice, 1000e18);

        vm.prank(agent);
        token.forcedTransfer(alice, bob, 1000e18);

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), 1000e18);
    }

    function test_FreezePartialBlocksExcessTransfer() public {
        vm.prank(agent);
        token.mint(alice, 1000e18);

        vm.prank(agent);
        token.freezePartialTokens(alice, 800e18);

        vm.prank(alice);
        vm.expectRevert("Token: insufficient unfrozen balance");
        token.transfer(bob, 300e18); // only 200e18 unfrozen

        vm.prank(alice);
        token.transfer(bob, 150e18); // within unfrozen amount
        assertEq(token.balanceOf(bob), 150e18);
    }

    function test_ForcedTransferCanMoveFrozenTokens() public {
        vm.prank(agent);
        token.mint(alice, 1000e18);

        vm.prank(agent);
        token.freezePartialTokens(alice, 1000e18); // fully frozen

        vm.prank(agent);
        token.forcedTransfer(alice, bob, 1000e18); // must still succeed -- recovery mechanism

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), 1000e18);
    }

    function test_PauseBlocksTransfers() public {
        vm.prank(agent);
        token.mint(alice, 1000e18);

        vm.prank(agent);
        token.pause();

        vm.prank(alice);
        vm.expectRevert("Token: paused");
        token.transfer(bob, 100e18);
    }

    function test_RevokedTrustedIssuerBreaksVerification() public {
        assertTrue(identityRegistry.isVerified(alice));
        tir.removeTrustedIssuer(claimIssuer);
        assertFalse(identityRegistry.isVerified(alice));
    }

    function test_RevertBurnBeyondUnfrozenBalance() public {
        vm.prank(agent);
        token.mint(alice, 1000e18);

        vm.prank(agent);
        token.freezePartialTokens(alice, 900e18);

        vm.prank(agent);
        vm.expectRevert("Token: insufficient unfrozen balance");
        token.burn(alice, 200e18); // only 100e18 unfrozen
    }
}
