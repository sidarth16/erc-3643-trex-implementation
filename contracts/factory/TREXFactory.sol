// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../registry/IdentityRegistry.sol";
import "../registry/IdentityRegistryStorage.sol";
import "../registry/TrustedIssuersRegistry.sol";
import "../registry/ClaimTopicsRegistry.sol";
import "../compliance/ModularCompliance.sol";
import "../Token.sol";

/**
 * @title TREXFactory
 * @notice Deploys and wires a full T-REX suite -- Identity Registry Storage,
 * Trusted Issuers Registry, Claim Topics Registry, Identity Registry, Modular
 * Compliance, and the Token itself -- in a single transaction.
 *
 * WHY THIS EXISTS: hand-wiring these six contracts individually is where most
 * first deployments go wrong -- forgetting `bindToken`, minting before any
 * claim topics are set, or binding the Identity Registry to the wrong storage
 * instance. The factory enforces the correct order every time and returns
 * every deployed address so the caller doesn't have to track them separately.
 */
contract TREXFactory {
    struct TokenDetails {
        address owner;
        string name;
        string symbol;
        uint256[] claimTopics;
    }

    struct DeployedSuite {
        address token;
        address identityRegistry;
        address identityRegistryStorage;
        address trustedIssuersRegistry;
        address claimTopicsRegistry;
        address compliance;
    }

    event SuiteDeployed(address indexed token, address indexed owner, address identityRegistry, address compliance);

    function deployTREXSuite(TokenDetails calldata details) external returns (DeployedSuite memory suite) {
        IdentityRegistryStorage irs = new IdentityRegistryStorage();
        TrustedIssuersRegistry tir = new TrustedIssuersRegistry();
        ClaimTopicsRegistry ctr = new ClaimTopicsRegistry();

        IdentityRegistry identityRegistry = new IdentityRegistry(address(irs), address(tir), address(ctr));
        irs.bindIdentityRegistry(address(identityRegistry));

        ModularCompliance compliance = new ModularCompliance();

        Token token = new Token(details.name, details.symbol, address(identityRegistry), address(compliance));
        compliance.bindToken(address(token));

        for (uint256 i = 0; i < details.claimTopics.length; i++) {
            ctr.addClaimTopic(details.claimTopics[i]);
        }

        // Hand off ownership of every piece to the requested owner. The factory
        // itself holds no ongoing privileges after deployment -- it's a one-shot
        // wiring tool, not an admin layer. Order matters here too: agent grants
        // happen BEFORE ownership transfer, since granting an agent is itself an
        // owner-only action on IdentityRegistry.
        identityRegistry.addAgent(details.owner);
        token.addAgent(details.owner);

        irs.transferOwnership(details.owner);
        tir.transferOwnership(details.owner);
        ctr.transferOwnership(details.owner);
        identityRegistry.transferOwnership(details.owner);
        compliance.transferOwnership(details.owner);
        token.transferOwnership(details.owner);

        suite = DeployedSuite({
            token: address(token),
            identityRegistry: address(identityRegistry),
            identityRegistryStorage: address(irs),
            trustedIssuersRegistry: address(tir),
            claimTopicsRegistry: address(ctr),
            compliance: address(compliance)
        });

        emit SuiteDeployed(address(token), details.owner, address(identityRegistry), address(compliance));
    }
}
