// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts-upgradeable/access/IAccessControlUpgradeable.sol";

interface IEventProvider is IAccessControlUpgradeable {

    function EMIT_EVENT() external returns (bytes32);

    function submitCreateLaunchpad(address _launchpadAddress, address _collection, address _owner, uint256 _requestId) external;

    function submitLaunchpadUpdate(address _launchpadAddress, address collection, address paymentToken) external;

    function submitSaleInfoUpdate(address _launchpadAddress, uint256[] memory info) external;

    function submitBuyTicket(address _launchpadAddress, uint256 buyType, address account, uint256 amount, uint256 from, uint256 to, uint256 requestId) external;

    function submitBuyNFT(address _launchpadAddress, uint256 buyType, address account, uint256 quantity, uint256 nftAmount, uint256 fromId, uint256 toId, uint256 requestId) external;

    function submitBuyNFTBatch(address _launchpadAddress, uint256 buyType, address account, uint256 quantity, uint256 nftAmount, uint256 tokenId, uint256 index, uint256 requestId) external;

    function submitRefund(address _launchpadAddress, address account, uint256 amount, uint256 requestId) external;

    function submitNFTClaimRequested(address _launchpadAddress, address account, uint256 ticketId, uint256 requestId) external;

    function submitNFTClaim(address _launchpadAddress, address account, uint256 ticketId, uint256 tokenId, uint256 requestId) external;

    function submitTokenClaim(address launchpad, uint256 buyType, address account, uint256 amount, uint256 requestId) external;

    function submitErrorConsume(address launchpad, bytes memory reason) external;

}