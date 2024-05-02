// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

interface IOriginERC721 is IERC721Enumerable {

    function mintBatch(address toAddress, uint256 amount) external returns (uint256);

    function mintMulti(address owner, uint256 amount) external;

    function setBaseURI(string memory baseTokenURI) external;

    function transferOwnership(address newOwner) external;

    function grantRole(bytes32 role, address account) external;

    function revokeRole(bytes32 role, address account) external;
}
