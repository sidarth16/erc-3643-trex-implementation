// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IIdentityRegistry.sol";
import "./interfaces/IModularCompliance.sol";
import "./interfaces/IToken.sol";

/**
 * @title Token
 * @notice An ERC-20 where every state-changing function checks the Identity
 * Registry and Modular Compliance contracts before it's allowed to execute.
 *
 * LIFECYCLE (every gatekept function follows this order, and the order is
 * not stylistic -- it's checks-effects-interactions applied to compliance):
 *
 *   validate (identity + compliance)
 *        |
 *        v
 *   transfer (mutate balances)
 *        |
 *        v
 *   compliance.transferred() / created() / destroyed()  (notify AFTER success)
 *
 * Checking after mutating would mean balances could already be wrong before
 * you discover the transfer shouldn't have happened. Notifying compliance
 * before the mutation would let stateful modules record volume/counters for
 * transfers that could still fail downstream.
 */
contract Token is ERC20, IToken {
    IIdentityRegistry public identityRegistryContract;
    IModularCompliance public complianceContract;

    address public owner;
    mapping(address => bool) private _agents;
    mapping(address => bool) private _frozen;
    mapping(address => uint256) private _frozenTokens;
    bool private _paused;

    modifier onlyOwner() {
        require(msg.sender == owner, "Token: not owner");
        _;
    }

    modifier onlyAgent() {
        require(_agents[msg.sender], "Token: not agent");
        _;
    }

    modifier whenNotPaused() {
        require(!_paused, "Token: paused");
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        address identityRegistry_,
        address compliance_
    ) ERC20(name_, symbol_) {
        identityRegistryContract = IIdentityRegistry(identityRegistry_);
        complianceContract = IModularCompliance(compliance_);
        owner = msg.sender;
    }

    // ---- IToken view accessors (interface requires plain address getters) ----

    function identityRegistry() external view override returns (address) {
        return address(identityRegistryContract);
    }

    function compliance() external view override returns (address) {
        return address(complianceContract);
    }

    function paused() external view override returns (bool) {
        return _paused;
    }

    function isFrozen(address account) external view override returns (bool) {
        return _frozen[account];
    }

    function getFrozenTokens(address account) external view override returns (uint256) {
        return _frozenTokens[account];
    }

    function isAgent(address account) external view override returns (bool) {
        return _agents[account];
    }

    // ---- Gatekept ERC-20 overrides ----

    function transfer(address to, uint256 amount) public override(ERC20, IERC20) whenNotPaused returns (bool) {
        _checkTransferAllowed(msg.sender, to, amount);
        _transfer(msg.sender, to, amount);
        complianceContract.transferred(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount)
        public
        override(ERC20, IERC20)
        whenNotPaused
        returns (bool)
    {
        _checkTransferAllowed(from, to, amount);
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        complianceContract.transferred(from, to, amount);
        return true;
    }

    /// @notice Optional convenience for onboarding/distribution flows -- still
    /// routes every leg through the same checks as a normal transfer, just batched
    /// to save the caller repeated external transactions.
    function batchTransfer(address[] calldata recipients, uint256[] calldata amounts)
        external
        whenNotPaused
        returns (bool)
    {
        require(recipients.length == amounts.length, "Token: array length mismatch");
        for (uint256 i = 0; i < recipients.length; i++) {
            _checkTransferAllowed(msg.sender, recipients[i], amounts[i]);
            _transfer(msg.sender, recipients[i], amounts[i]);
            complianceContract.transferred(msg.sender, recipients[i], amounts[i]);
        }
        return true;
    }

    function _checkTransferAllowed(address from, address to, uint256 amount) internal view {
        require(!_frozen[from] && !_frozen[to], "Token: address frozen");
        require(balanceOf(from) - _frozenTokens[from] >= amount, "Token: insufficient unfrozen balance");
        require(identityRegistryContract.isVerified(to), "Token: receiver not verified");
        require(complianceContract.canTransfer(from, to, amount), "Token: compliance check failed");
    }

    // ---- Agent-only operations ----

    function mint(address to, uint256 amount) external override onlyAgent {
        require(identityRegistryContract.isVerified(to), "Token: receiver not verified");
        require(complianceContract.canTransfer(address(0), to, amount), "Token: compliance check failed");
        _mint(to, amount);
        complianceContract.created(to, amount);
    }

    function burn(address from, uint256 amount) external override onlyAgent {
        require(balanceOf(from) - _frozenTokens[from] >= amount, "Token: insufficient unfrozen balance");
        _burn(from, amount);
        complianceContract.destroyed(from, amount);
    }

    /// @notice The regulatory recovery mechanism -- court-ordered clawback, lost-key
    /// recovery, compliance action. Unlike a normal transfer, this is ALLOWED to
    /// move frozen tokens: unfreezing exactly enough to cover the requested amount.
    /// Omitting this special case means a legitimate forced transfer on a frozen
    /// wallet hits a revert the agent can't work around -- defeating the point of
    /// the function existing.
    function forcedTransfer(address from, address to, uint256 amount) external override onlyAgent returns (bool) {
        require(identityRegistryContract.isVerified(to), "Token: receiver not verified");
        uint256 unfrozen = balanceOf(from) - _frozenTokens[from];
        if (unfrozen < amount) {
            _frozenTokens[from] -= (amount - unfrozen);
        }
        _transfer(from, to, amount);
        complianceContract.transferred(from, to, amount);
        return true;
    }

    function freezePartialTokens(address account, uint256 amount) external override onlyAgent {
        require(balanceOf(account) >= _frozenTokens[account] + amount, "Token: amount exceeds balance");
        _frozenTokens[account] += amount;
    }

    function unfreezePartialTokens(address account, uint256 amount) external override onlyAgent {
        require(_frozenTokens[account] >= amount, "Token: amount exceeds frozen balance");
        _frozenTokens[account] -= amount;
    }

    function setAddressFrozen(address account, bool freeze) external override onlyAgent {
        _frozen[account] = freeze;
    }

    function pause() external override onlyAgent {
        _paused = true;
    }

    function unpause() external override onlyAgent {
        _paused = false;
    }

    // ---- Owner-only governance ----

    function addAgent(address agent) external override onlyOwner {
        _agents[agent] = true;
    }

    function removeAgent(address agent) external override onlyOwner {
        _agents[agent] = false;
    }

    function setIdentityRegistry(address _identityRegistry) external onlyOwner {
        identityRegistryContract = IIdentityRegistry(_identityRegistry);
    }

    function setCompliance(address _compliance) external onlyOwner {
        complianceContract = IModularCompliance(_compliance);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }
}
