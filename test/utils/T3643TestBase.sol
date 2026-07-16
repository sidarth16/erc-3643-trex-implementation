// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "./ClaimSigner.sol";
import "../../contracts/Token.sol";
import "../../contracts/registry/IdentityRegistry.sol";
import "../../contracts/registry/IdentityRegistryStorage.sol";
import "../../contracts/registry/TrustedIssuersRegistry.sol";
import "../../contracts/registry/ClaimTopicsRegistry.sol";
import "../../contracts/compliance/ModularCompliance.sol";
import "../../contracts/identity/Identity.sol";
import "../../contracts/identity/ClaimIssuer.sol";

/// @notice Deploys a full T-REX suite by hand (not through the factory) so unit
/// and fuzz tests can reach into every piece directly, and provides a reusable
/// `_onboard` helper that mirrors the exact claim-signing flow described in the
/// accompanying articles.
abstract contract T3643TestBase is Test, ClaimSigner {
    Token internal token;
    IdentityRegistry internal identityRegistry;
    IdentityRegistryStorage internal irs;
    TrustedIssuersRegistry internal tir;
    ClaimTopicsRegistry internal ctr;
    ModularCompliance internal compliance;
    ClaimIssuer internal claimIssuer;

    uint256 internal issuerKey = 0xA11CE;
    address internal agent = address(0xA6EA7);
    uint256 internal constant KYC_TOPIC = 1;

    function _deployBaseSuite() internal {
        irs = new IdentityRegistryStorage();
        tir = new TrustedIssuersRegistry();
        ctr = new ClaimTopicsRegistry();

        identityRegistry = new IdentityRegistry(address(irs), address(tir), address(ctr));
        irs.bindIdentityRegistry(address(identityRegistry));

        compliance = new ModularCompliance();

        token = new Token("Test Bond", "TBOND", address(identityRegistry), address(compliance));
        compliance.bindToken(address(token));

        token.addAgent(agent);
        identityRegistry.addAgent(agent);

        ctr.addClaimTopic(KYC_TOPIC);

        claimIssuer = new ClaimIssuer(address(this));
        claimIssuer.addKey(keccak256(abi.encode(vm.addr(issuerKey))), claimIssuer.CLAIM_SIGNER_PURPOSE(), 1);
        uint256[] memory topics = new uint256[](1);
        topics[0] = KYC_TOPIC;
        tir.addTrustedIssuer(claimIssuer, topics);
    }

    /// @dev Registers `investor` with a valid KYC claim signed by the test suite's
    /// claim issuer. Skipping this before a mint is the #1 cause of "mint reverts
    /// with no message" when people write their first T-REX test.
    function _onboard(address investor, uint16 country) internal {
        Identity id = new Identity(investor, false);
        bytes memory data = abi.encode("KYC_APPROVED");
        bytes memory sig = signClaim(issuerKey, address(id), KYC_TOPIC, data);

        vm.prank(investor);
        id.addClaim(KYC_TOPIC, 1, address(claimIssuer), sig, data, "");

        vm.prank(agent);
        identityRegistry.registerIdentity(investor, id, country);
    }
}
