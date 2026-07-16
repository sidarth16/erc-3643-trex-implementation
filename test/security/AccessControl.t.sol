// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../utils/T3643TestBase.sol";
import "../../contracts/compliance/modules/LockupModule.sol";

/// @notice Every privileged function should reject a non-privileged caller.
/// This is the test category an auditor writes first, and it's the cheapest
/// class of bug to catch -- a missing modifier is a one-line fix if caught
/// here, and a full incident if it isn't.
contract AccessControlTest is T3643TestBase {
    address alice = address(0x1);
    address randomCaller = address(0x999);

    function setUp() public {
        _deployBaseSuite();
        _onboard(alice, 840);
    }

    function test_RevertMintFromNonAgent() public {
        vm.prank(randomCaller);
        vm.expectRevert("Token: not agent");
        token.mint(alice, 100e18);
    }

    function test_RevertForcedTransferFromNonAgent() public {
        vm.prank(agent);
        token.mint(alice, 100e18);

        vm.prank(randomCaller);
        vm.expectRevert("Token: not agent");
        token.forcedTransfer(alice, randomCaller, 100e18);
    }

    function test_RevertPauseFromNonAgent() public {
        vm.prank(randomCaller);
        vm.expectRevert("Token: not agent");
        token.pause();
    }

    function test_RevertAddAgentFromNonOwner() public {
        vm.prank(randomCaller);
        vm.expectRevert("Token: not owner");
        token.addAgent(randomCaller);
    }

    function test_RevertRegisterIdentityFromNonAgentOrOwner() public {
        Identity id = new Identity(randomCaller, false);
        vm.prank(randomCaller);
        vm.expectRevert("IR: not authorized");
        identityRegistry.registerIdentity(randomCaller, id, 840);
    }

    function test_RevertAddTrustedIssuerFromNonOwner() public {
        uint256[] memory topics = new uint256[](1);
        topics[0] = KYC_TOPIC;
        vm.prank(randomCaller);
        vm.expectRevert("TIR: not owner");
        tir.addTrustedIssuer(claimIssuer, topics);
    }

    function test_RevertAddModuleFromNonOwner() public {
        LockupModule module = new LockupModule();
        vm.prank(randomCaller);
        vm.expectRevert("MC: not owner");
        compliance.addModule(address(module));
    }

    function test_AgentIsSeparateFromOwner() public {
        // Confirms the two roles are independently gated -- an agent cannot
        // perform owner-only actions, and vice versa, even though both are
        // "privileged" in a loose sense.
        vm.prank(agent);
        vm.expectRevert("Token: not owner");
        token.addAgent(randomCaller);
    }
}
