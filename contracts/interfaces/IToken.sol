// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IToken is IERC20 {
    function identityRegistry() external view returns (address);
    function compliance() external view returns (address);

    function mint(address _to, uint256 _amount) external;
    function burn(address _from, uint256 _amount) external;

    function forcedTransfer(address _from, address _to, uint256 _amount) external returns (bool);

    function freezePartialTokens(address _userAddress, uint256 _amount) external;
    function unfreezePartialTokens(address _userAddress, uint256 _amount) external;
    function getFrozenTokens(address _userAddress) external view returns (uint256);

    function setAddressFrozen(address _userAddress, bool _freeze) external;
    function isFrozen(address _userAddress) external view returns (bool);

    function pause() external;
    function unpause() external;
    function paused() external view returns (bool);

    function addAgent(address _agent) external;
    function removeAgent(address _agent) external;
    function isAgent(address _agent) external view returns (bool);
}
