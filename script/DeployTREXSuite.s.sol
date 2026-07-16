// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../contracts/Token.sol";
import "../contracts/registry/IdentityRegistry.sol";
import "../contracts/registry/IdentityRegistryStorage.sol";
import "../contracts/registry/TrustedIssuersRegistry.sol";
import "../contracts/registry/ClaimTopicsRegistry.sol";
import "../contracts/compliance/ModularCompliance.sol";
import "../contracts/compliance/modules/CountryRestrictModule.sol";
import "../contracts/compliance/modules/MaxBalanceModule.sol";
import "../contracts/identity/Identity.sol";
import "../contracts/identity/ClaimIssuer.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title DeployTREXSuite
 * @notice End-to-end demo deployment: wires a full T-REX suite by hand (not
 * through the factory, so every step is visible), configures claim topics and
 * a trusted issuer, onboards two investors with signed claims, mints to one,
 * and executes a transfer between them -- then prints every deployed address.
 *
 * Run against a local Anvil node:
 *   anvil
 *   forge script script/DeployTREXSuite.s.sol --rpc-url http://127.0.0.1:8545 --broadcast -vvvv
 *
 * Run against a real network (fill in .env first):
 *   forge script script/DeployTREXSuite.s.sol --rpc-url $RPC_URL --broadcast --verify -vvvv
 */
contract DeployTREXSuite is Script {
    uint256 constant KYC_TOPIC = 1;

    function run() external {
        uint256 deployerKey = vm.envOr("PRIVATE_KEY", uint256(0xA11CE));
        address deployer = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);

        IdentityRegistryStorage irs = new IdentityRegistryStorage();
        TrustedIssuersRegistry tir = new TrustedIssuersRegistry();
        ClaimTopicsRegistry ctr = new ClaimTopicsRegistry();

        IdentityRegistry identityRegistry = new IdentityRegistry(address(irs), address(tir), address(ctr));
        irs.bindIdentityRegistry(address(identityRegistry));

        ModularCompliance compliance = new ModularCompliance();

        Token token = new Token(
            "Example Tokenized Bond",
            "EXBOND",
            address(identityRegistry),
            address(compliance)
        );
        compliance.bindToken(address(token));

        token.addAgent(deployer);
        identityRegistry.addAgent(deployer);

        CountryRestrictModule countryModule = new CountryRestrictModule();
        MaxBalanceModule maxBalanceModule = new MaxBalanceModule();
        compliance.addModule(address(countryModule));
        compliance.addModule(address(maxBalanceModule));
        maxBalanceModule.setMaxBalance(address(compliance), 1_000_000e18);

        ctr.addClaimTopic(KYC_TOPIC);

        // ---- Claim issuer setup ----
        ClaimIssuer claimIssuer = new ClaimIssuer(deployer);
        uint256 issuerSignerKey = uint256(keccak256(abi.encodePacked("demo-issuer-signer")));
        address issuerSigner = vm.addr(issuerSignerKey);
        claimIssuer.addKey(keccak256(abi.encode(issuerSigner)), claimIssuer.CLAIM_SIGNER_PURPOSE(), 1);

        uint256[] memory topics = new uint256[](1);
        topics[0] = KYC_TOPIC;
        tir.addTrustedIssuer(claimIssuer, topics);

        // ---- Onboard two demo investors ----
        address investorA = vm.addr(uint256(keccak256("investor-a")));
        address investorB = vm.addr(uint256(keccak256("investor-b")));

        _onboardInvestor(identityRegistry, claimIssuer, issuerSignerKey, investorA, 840);
        _onboardInvestor(identityRegistry, claimIssuer, issuerSignerKey, investorB, 276);

        // ---- Mint and transfer ----
        token.mint(investorA, 10_000e18);

        // Demo transfer: executed via forcedTransfer under the deployer's agent
        // role, since the deployer's key is the only one this script controls.
        // In a real flow this would instead be investorA calling transfer()
        // directly, signed with investorA's own key.
        token.forcedTransfer(investorA, investorB, 2_500e18);

        vm.stopBroadcast();

        console2.log("Token:", address(token));
        console2.log("IdentityRegistry:", address(identityRegistry));
        console2.log("IdentityRegistryStorage:", address(irs));
        console2.log("TrustedIssuersRegistry:", address(tir));
        console2.log("ClaimTopicsRegistry:", address(ctr));
        console2.log("ModularCompliance:", address(compliance));
        console2.log("ClaimIssuer:", address(claimIssuer));
        console2.log("Investor A:", investorA);
        console2.log("Investor B:", investorB);
    }

    function _onboardInvestor(
        IdentityRegistry identityRegistry,
        ClaimIssuer claimIssuer,
        uint256 issuerSignerKey,
        address investor,
        uint16 country
    ) internal {
        Identity id = new Identity(investor, false);
        bytes memory data = abi.encode("KYC_APPROVED");

        bytes32 dataHash = keccak256(abi.encode(address(id), KYC_TOPIC, data));
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(dataHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(issuerSignerKey, ethSignedHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        id.addClaim(KYC_TOPIC, 1, address(claimIssuer), signature, data, "");
        identityRegistry.registerIdentity(investor, id, country);
    }
}
