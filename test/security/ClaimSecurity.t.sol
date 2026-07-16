// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../utils/T3643TestBase.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "../../contracts/interfaces/IModule.sol";

/// @notice Tests for the specific claim/signature failure modes that cost the
/// most debugging time in practice -- wrong signer, wrong encoding, missing
/// claim topic, revoked claim -- each written to prove the system fails
/// CLOSED (unverified) rather than silently accepting a bad claim.
contract ClaimSecurityTest is T3643TestBase {
    address alice = address(0x1);

    function setUp() public {
        _deployBaseSuite();
    }

    function test_WrongSignerProducesInvalidClaim() public {
        Identity id = new Identity(alice, false);
        uint256 wrongKey = 0xBAD5EED;
        bytes memory data = abi.encode("KYC_APPROVED");
        bytes memory sig = signClaim(wrongKey, address(id), KYC_TOPIC, data); // signed by an untrusted key

        vm.prank(alice);
        id.addClaim(KYC_TOPIC, 1, address(claimIssuer), sig, data, "");

        vm.prank(agent);
        identityRegistry.registerIdentity(alice, id, 840);

        // Claim exists on-chain, but the signature doesn't recover to a
        // registered CLAIM_SIGNER key on the issuer -- must read as invalid.
        assertFalse(identityRegistry.isVerified(alice));
    }

    function test_EncodingMismatchProducesInvalidClaim() public {
        Identity id = new Identity(alice, false);
        bytes memory data = abi.encode("KYC_APPROVED");

        // Deliberately sign with abi.encodePacked instead of abi.encode --
        // the exact mismatch that silently breaks claims in practice.
        bytes32 wrongHash = keccak256(abi.encodePacked(address(id), KYC_TOPIC, data));
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(wrongHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(issuerKey, ethSignedHash);
        bytes memory badSig = abi.encodePacked(r, s, v);

        vm.prank(alice);
        id.addClaim(KYC_TOPIC, 1, address(claimIssuer), badSig, data, "");

        vm.prank(agent);
        identityRegistry.registerIdentity(alice, id, 840);

        assertFalse(identityRegistry.isVerified(alice));
    }

    function test_MissingClaimTopicOnIssuerProducesInvalidClaim() public {
        // Issuer is trusted, key is correct, signature is correct -- but the
        // issuer isn't authorized for THIS topic in the Trusted Issuers Registry.
        uint256 otherTopic = 999;
        Identity id = new Identity(alice, false);
        bytes memory data = abi.encode("SOME_OTHER_CLAIM");
        bytes memory sig = signClaim(issuerKey, address(id), otherTopic, data);

        vm.prank(alice);
        id.addClaim(otherTopic, 1, address(claimIssuer), sig, data, "");

        vm.prank(agent);
        identityRegistry.registerIdentity(alice, id, 840);

        // otherTopic was never added to the Claim Topics Registry as required,
        // so isVerified only checks KYC_TOPIC -- and alice has no valid claim there.
        assertFalse(identityRegistry.isVerified(alice));
    }

    function test_RevokedClaimNoLongerVerifies() public {
        _onboard(alice, 840);
        assertTrue(identityRegistry.isVerified(alice));

        Identity id = Identity(address(identityRegistry.identity(alice)));
        bytes32 claimId = keccak256(abi.encode(address(claimIssuer), KYC_TOPIC));

        vm.prank(alice);
        id.removeClaim(claimId);

        assertFalse(identityRegistry.isVerified(alice));
    }

    function test_MaliciousModuleCannotBypassOtherModulesRejection() public {
        // A module that always approves should NOT be able to override an
        // earlier module's rejection -- compliance is AND, never OR.
        AlwaysRejectModule reject = new AlwaysRejectModule();
        AlwaysApproveModule approve = new AlwaysApproveModule();
        compliance.addModule(address(reject));
        compliance.addModule(address(approve));

        _onboard(alice, 840);
        vm.prank(agent);
        vm.expectRevert("Token: compliance check failed");
        token.mint(alice, 100e18);
    }
}

contract AlwaysRejectModule is IModule {
    function moduleCheck(address, address, uint256, address) external pure override returns (bool) { return false; }
    function moduleTransferAction(address, address, uint256) external override {}
    function moduleMintAction(address, uint256) external override {}
    function moduleBurnAction(address, uint256) external override {}
    function canComplianceBind(address) external pure override returns (bool) { return true; }
    function isPlugAndPlay() external pure override returns (bool) { return true; }
}

contract AlwaysApproveModule is IModule {
    function moduleCheck(address, address, uint256, address) external pure override returns (bool) { return true; }
    function moduleTransferAction(address, address, uint256) external override {}
    function moduleMintAction(address, uint256) external override {}
    function moduleBurnAction(address, uint256) external override {}
    function canComplianceBind(address) external pure override returns (bool) { return true; }
    function isPlugAndPlay() external pure override returns (bool) { return true; }
}
