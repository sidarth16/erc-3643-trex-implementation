// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IModularCompliance.sol";
import "../interfaces/IModule.sol";

/**
 * @title ModularCompliance
 * @notice The rules engine. Every bound module's `moduleCheck` must return true
 * for a transfer to be allowed -- modules are ANDed together, never ORed. If you
 * need either/or logic, that has to live inside a single custom module.
 *
 * GAS NOTE: `canTransfer` short-circuits on the first `false`. Bind cheap,
 * likely-to-reject modules (a plain storage read like a country check) before
 * expensive ones, so the common rejection path stays cheap.
 */
contract ModularCompliance is IModularCompliance {
    address public tokenBound;
    address public owner;
    address[] public modules;
    mapping(address => bool) public isModuleBound;

    modifier onlyOwner() {
        require(msg.sender == owner, "MC: not owner");
        _;
    }

    modifier onlyToken() {
        require(msg.sender == tokenBound, "MC: caller is not the bound token");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    function bindToken(address _token) external onlyOwner {
        require(tokenBound == address(0), "MC: token already bound");
        tokenBound = _token;
    }

    function unbindToken(address _token) external onlyOwner {
        require(tokenBound == _token, "MC: not the bound token");
        tokenBound = address(0);
    }

    /// @dev `canComplianceBind` lets a module refuse to bind to a compliance
    /// contract it isn't compatible with -- e.g. one that expects the token to
    /// expose an extension this deployment doesn't have.
    function addModule(address _module) external onlyOwner {
        require(!isModuleBound[_module], "MC: module already bound");
        require(IModule(_module).canComplianceBind(address(this)), "MC: module rejected binding");
        modules.push(_module);
        isModuleBound[_module] = true;
    }

    function removeModule(address _module) external onlyOwner {
        require(isModuleBound[_module], "MC: module not bound");
        isModuleBound[_module] = false;
        for (uint256 i = 0; i < modules.length; i++) {
            if (modules[i] == _module) {
                modules[i] = modules[modules.length - 1];
                modules.pop();
                break;
            }
        }
    }

    function canTransfer(address _from, address _to, uint256 _amount) external view returns (bool) {
        for (uint256 i = 0; i < modules.length; i++) {
            if (!IModule(modules[i]).moduleCheck(_from, _to, _amount, address(this))) {
                return false;
            }
        }
        return true;
    }

    function transferred(address _from, address _to, uint256 _amount) external onlyToken {
        for (uint256 i = 0; i < modules.length; i++) {
            IModule(modules[i]).moduleTransferAction(_from, _to, _amount);
        }
    }

    function created(address _to, uint256 _amount) external onlyToken {
        for (uint256 i = 0; i < modules.length; i++) {
            IModule(modules[i]).moduleMintAction(_to, _amount);
        }
    }

    function destroyed(address _from, uint256 _amount) external onlyToken {
        for (uint256 i = 0; i < modules.length; i++) {
            IModule(modules[i]).moduleBurnAction(_from, _amount);
        }
    }
}
