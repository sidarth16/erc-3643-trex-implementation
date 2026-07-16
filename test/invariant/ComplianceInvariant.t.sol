// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../utils/T3643TestBase.sol";

/// @notice The single highest-leverage test category for a T-REX deployment:
/// proving that no sequence of mints, transfers, and burns a fuzzer can find
/// ever leaves an unverified address holding a nonzero balance, or leaves
/// frozen accounting inconsistent with actual balances.
contract ComplianceInvariantHandler is Test {
    Token public token;
    IdentityRegistry public identityRegistry;
    address public agent;

    address[] public verifiedActors;
    address[] public unverifiedActors;

    // ghost totals, tracked independently of the contracts under test
    uint256 public ghost_totalMinted;
    uint256 public ghost_totalBurned;

    constructor(
        Token _token,
        IdentityRegistry _identityRegistry,
        address _agent,
        address[] memory _verified,
        address[] memory _unverified
    ) {
        token = _token;
        identityRegistry = _identityRegistry;
        agent = _agent;
        verifiedActors = _verified;
        unverifiedActors = _unverified;
    }

    function mintToVerified(uint256 actorSeed, uint256 amount) external {
        address actor = verifiedActors[actorSeed % verifiedActors.length];
        amount = bound(amount, 0, 1_000_000e18);
        vm.prank(agent);
        try token.mint(actor, amount) {
            ghost_totalMinted += amount;
        } catch {}
    }

    function mintToUnverified(uint256 actorSeed, uint256 amount) external {
        // Deliberately tries the forbidden path -- should always revert and
        // therefore never affect ghost totals or balances.
        address actor = unverifiedActors[actorSeed % unverifiedActors.length];
        amount = bound(amount, 0, 1_000_000e18);
        vm.prank(agent);
        try token.mint(actor, amount) {
            // If this branch is ever reached, the invariant test below will
            // already have caught it -- but assert defensively here too.
            assertTrue(false, "minted to an unverified address without reverting");
        } catch {}
    }

    function transferBetweenVerified(uint256 fromSeed, uint256 toSeed, uint256 amount) external {
        address from = verifiedActors[fromSeed % verifiedActors.length];
        address to = verifiedActors[toSeed % verifiedActors.length];
        amount = bound(amount, 0, 1_000_000e18);
        vm.prank(from);
        try token.transfer(to, amount) {} catch {}
    }

    function transferToUnverified(uint256 fromSeed, uint256 toSeed, uint256 amount) external {
        address from = verifiedActors[fromSeed % verifiedActors.length];
        address to = unverifiedActors[toSeed % unverifiedActors.length];
        amount = bound(amount, 0, 1_000_000e18);
        vm.prank(from);
        try token.transfer(to, amount) {
            assertTrue(false, "transferred to an unverified address without reverting");
        } catch {}
    }

    function burnFromVerified(uint256 actorSeed, uint256 amount) external {
        address actor = verifiedActors[actorSeed % verifiedActors.length];
        amount = bound(amount, 0, 1_000_000e18);
        vm.prank(agent);
        try token.burn(actor, amount) {
            ghost_totalBurned += amount;
        } catch {}
    }

    function freezePartial(uint256 actorSeed, uint256 amount) external {
        address actor = verifiedActors[actorSeed % verifiedActors.length];
        amount = bound(amount, 0, 1_000_000e18);
        vm.prank(agent);
        try token.freezePartialTokens(actor, amount) {} catch {}
    }
}

contract ComplianceInvariantTest is T3643TestBase {
    ComplianceInvariantHandler handler;

    address[] verified;
    address[] unverified;

    function setUp() public {
        _deployBaseSuite();

        for (uint256 i = 0; i < 5; i++) {
            address a = address(uint160(0x1000 + i));
            _onboard(a, 840);
            verified.push(a);
        }
        for (uint256 i = 0; i < 3; i++) {
            unverified.push(address(uint160(0x2000 + i)));
        }

        handler = new ComplianceInvariantHandler(token, identityRegistry, agent, verified, unverified);
        targetContract(address(handler));
    }

    /// @dev The core compliance boundary: an unverified address must never,
    /// under any reachable sequence of actions, hold a nonzero balance.
    function invariant_UnverifiedNeverHoldsBalance() public view {
        for (uint256 i = 0; i < unverified.length; i++) {
            assertEq(token.balanceOf(unverified[i]), 0);
        }
    }

    /// @dev Frozen accounting must never exceed actual balance -- if it did,
    /// `balanceOf(x) - frozenTokens[x]` would underflow on every future check.
    function invariant_FrozenNeverExceedsBalance() public view {
        for (uint256 i = 0; i < verified.length; i++) {
            assertLe(token.getFrozenTokens(verified[i]), token.balanceOf(verified[i]));
        }
    }

    /// @dev Total supply should always equal ghost-tracked mint/burn totals --
    /// proves transfers alone never inflate or deflate supply.
    function invariant_SupplyMatchesGhostMintBurn() public view {
        assertEq(token.totalSupply(), handler.ghost_totalMinted() - handler.ghost_totalBurned());
    }
}
