// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface ILaunchpadERC721 {

    function updateLaunchpadSaleInfo(uint256[] memory _saleInfo) external;

    function transferOwnership(address newOwner) external;

    function initialize(address _collection, address _paymentToken, address nftVault) external;

    function consumeRandomness(uint256 randomness) external returns (bool);

    function checkRequestIdIndex(uint256 requestId, uint256 index) external view returns (bool);

    function checkRequestIdTicketId(uint256 requestId, uint256 ticketId) external view returns (bool);
}
