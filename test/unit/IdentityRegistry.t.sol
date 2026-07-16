// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../utils/T3643TestBase.sol";
import "../../contracts/interfaces/IClaimIssuer.sol";
import "../../contracts/interfaces/IIdentity.sol";

contract IdentityRegistryUnitTest is T3643TestBase {
    address alice = address(0x1);

    function setUp() public {
        _deployBaseSuite();
    }

    function test_UnregisteredAddressNotVerified() public {
        assertFalse(identityRegistry.isVerified(alice));
    }

    function test_RegisteredWithValidClaimIsVerified() public {
        _onboard(alice, 840);
        assertTrue(identityRegistry.isVerified(alice));
    }

    function test_NoRequiredTopicsMeansOpenVerification() public {
        // Deploy a second suite with zero required claim topics to prove the
        // "open token" branch: an empty required-topics list means isVerified
        // just checks that an identity is registered at all.
        IdentityRegistryStorage irs2 = new IdentityRegistryStorage();
        TrustedIssuersRegistry tir2 = new TrustedIssuersRegistry();
        ClaimTopicsRegistry ctr2 = new ClaimTopicsRegistry();
        IdentityRegistry ir2 = new IdentityRegistry(address(irs2), address(tir2), address(ctr2));
        irs2.bindIdentityRegistry(address(ir2));

        Identity id = new Identity(alice, false);
        ir2.registerIdentity(alice, id, 840);

        assertTrue(ir2.isVerified(alice));
    }

    function test_UpdateCountry() public {
        _onboard(alice, 840);
        assertEq(identityRegistry.investorCountry(alice), 840);

        vm.prank(agent);
        identityRegistry.updateCountry(alice, 276);
        assertEq(identityRegistry.investorCountry(alice), 276);
    }

    function test_DeleteIdentityRevokesVerification() public {
        _onboard(alice, 840);
        assertTrue(identityRegistry.isVerified(alice));

        vm.prank(agent);
        identityRegistry.deleteIdentity(alice);
        assertFalse(identityRegistry.isVerified(alice));
    }

    function test_MalformedIssuerContractDoesNotBrickVerification() public {
        // A claim pointing at an issuer contract that reverts on isClaimValid
        // should be skipped, not brick the whole isVerified() call -- this is
        // exactly what the try/catch in IdentityRegistry._hasValidClaimForTopic
        // is there to prevent.
        _onboard(alice, 840);
        assertTrue(identityRegistry.isVerified(alice));

        Identity id = Identity(address(identityRegistry.identity(alice)));
        RevertingIssuer badIssuer = new RevertingIssuer();
        uint256[] memory topics = new uint256[](1);
        topics[0] = KYC_TOPIC;
        tir.addTrustedIssuer(IClaimIssuer(address(badIssuer)), topics);

        vm.prank(alice);
        id.addClaim(KYC_TOPIC, 1, address(badIssuer), "", "", "");

        // Still verified via the original, valid claim -- the bad one is skipped.
        assertTrue(identityRegistry.isVerified(alice));
    }
}

/// @dev A claim issuer contract that always reverts, used to prove isVerified
/// doesn't brick when a claim issuer's contract misbehaves.
contract RevertingIssuer is IClaimIssuer {
    function isClaimValid(IIdentity, uint256, bytes calldata, bytes calldata) external pure returns (bool) {
        revert("intentionally broken issuer");
    }
}
