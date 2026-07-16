// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title ClaimSigner
 * @notice Test helper for producing valid ONCHAINID claim signatures with vm.sign.
 *
 * This exists because getting the hash encoding wrong here is the single most
 * common bug when writing T-REX tests -- sign with abi.encodePacked, verify with
 * abi.encode (or vice versa), and the claim silently reads as invalid with no
 * revert to point you at why. This helper keeps the encoding in exactly one
 * place so every test uses the same, correct version.
 */
abstract contract ClaimSigner is Test {
    function signClaim(uint256 issuerPrivateKey, address identityAddress, uint256 topic, bytes memory data)
        internal
        returns (bytes memory signature)
    {
        bytes32 dataHash = keccak256(abi.encode(identityAddress, topic, data));
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(dataHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(issuerPrivateKey, ethSignedHash);
        signature = abi.encodePacked(r, s, v);
    }
}
