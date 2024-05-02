// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface ILaunchpadFactory {

    function getConfig() external view returns (address);

    function validSignature(uint256 typeFunc, bytes32 hash, bytes memory signature, uint256 requestId, uint256 expiredTime) external returns (bool);

    function requestRandomness() external;
}
