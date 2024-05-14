// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import {IEventProvider} from "./interface/IEventProvider.sol";

contract EventProvider is IEventProvider, AccessControlEnumerableUpgradeable {

    bytes32 public constant EMIT_EVENT = keccak256("EMIT_EVENT");

    struct NFTBuy {
        address launchpad;
        uint256 fromId;
        uint256 toId;
        uint256 index;
        uint256 ticketId;
    }

    mapping(uint256 => NFTBuy) public buyEventMapping;
    mapping(uint256 => NFTBuy) public claimEventMapping;
    mapping(uint256 => NFTBuy) public buyBatchEventMapping;

    event CreateLaunchpad(address indexed launchpad, address indexed token, address indexed owner, uint256 requestId);
    event LaunchpadUpdate(address indexed launchpad, address collection, address paymentToken);
    event SaleInfoUpdate(address indexed launchpad, uint256[] info);
    event BuyTicket(address indexed launchpad, uint256 buyType, address indexed account, uint256 amount, uint256 from, uint256 to, uint256 requestId);
    event BuyNFT(address indexed launchpad, uint256 buyType, address indexed account, uint256 quantity, uint256 nftAmount, uint256 fromId, uint256 toId, uint256 requestId);
    event Refund(address indexed launchpad, address indexed account, uint256 amount, uint256 requestId);
    event NFTClaimRequested(address indexed launchpad, address indexed account, uint256 ticketId, uint256 requestId);
    event NFTClaim(address indexed launchpad, address indexed account, uint256 ticketId, uint256 tokenId, uint256 requestId);
    event TokenClaim(address indexed launchpad, uint256 buyType, address indexed account, uint256 amount, uint256 requestId);
    event BuyNFTBatch(address indexed launchpad, uint256 buyType, address indexed account, uint256 quantity, uint256 nftAmount, uint256 tokenId, uint256 index, uint256 requestId);
    event ErrorConsume(address indexed launchpad, bytes reason);
    event ErrorConsumeRevert(address indexed launchpad, string reason);
    event RandomnessRequest();

    function initialize() public initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function submitCreateLaunchpad(address _launchpadAddress, address _collection, address _owner, uint256 _requestId) external onlyRole(EMIT_EVENT) {
        emit CreateLaunchpad(_launchpadAddress, _collection, _owner, _requestId);
    }

    function submitLaunchpadUpdate(address _launchpadAddress, address collection, address paymentToken) external onlyRole(EMIT_EVENT) {
        emit LaunchpadUpdate(_launchpadAddress, collection, paymentToken);
    }

    function submitSaleInfoUpdate(address _launchpadAddress, uint256[] memory info) external onlyRole(EMIT_EVENT) {
        emit SaleInfoUpdate(_launchpadAddress, info);
    }

    function submitBuyTicket(address _launchpadAddress, uint256 buyType, address account, uint256 amount, uint256 from, uint256 to, uint256 requestId) external onlyRole(EMIT_EVENT) {
        buyEventMapping[requestId] = NFTBuy(_launchpadAddress, from, to, 0, 0);
        emit BuyTicket(_launchpadAddress, buyType, account, amount, from, to, requestId);
    }

    function submitBuyNFT(address _launchpadAddress, uint256 buyType, address account, uint256 quantity, uint256 nftAmount, uint256 fromId, uint256 toId, uint256 requestId) external onlyRole(EMIT_EVENT) {
        buyEventMapping[requestId] = NFTBuy(_launchpadAddress, fromId, toId, 0, 0);
        emit BuyNFT(_launchpadAddress, buyType, account, quantity, nftAmount, fromId, toId, requestId);
    }

    function submitBuyNFTBatch(address _launchpadAddress, uint256 buyType, address account, uint256 quantity, uint256 nftAmount, uint256 tokenId, uint256 index, uint256 requestId) external onlyRole(EMIT_EVENT) {
        buyBatchEventMapping[requestId] = NFTBuy(_launchpadAddress, tokenId, tokenId, index, 0);
        emit BuyNFTBatch(_launchpadAddress, buyType, account, quantity, nftAmount, tokenId, index, requestId);
    }

    function submitRefund(address _launchpadAddress, address account, uint256 amount, uint256 requestId) external onlyRole(EMIT_EVENT) {
        emit Refund(_launchpadAddress, account, amount, requestId);
    }

    function submitNFTClaimRequested(address _launchpadAddress, address account, uint256 ticketId, uint256 requestId) external onlyRole(EMIT_EVENT) {
        emit NFTClaimRequested(_launchpadAddress, account, ticketId, requestId);
    }

    function submitNFTClaim(address _launchpadAddress, address account, uint256 ticketId, uint256 tokenId, uint256 requestId) external onlyRole(EMIT_EVENT) {
        claimEventMapping[requestId] = NFTBuy(_launchpadAddress, tokenId, tokenId, 0, ticketId);
        emit NFTClaim(_launchpadAddress, account, ticketId, tokenId, requestId);
    }

    function submitTokenClaim(address launchpad, uint256 buyType, address account, uint256 amount, uint256 requestId) external onlyRole(EMIT_EVENT) {
        emit TokenClaim(launchpad, buyType, account, amount, requestId);
    }

    function submitErrorConsume(address launchpad, bytes memory reason) external onlyRole(EMIT_EVENT) {
        emit ErrorConsume(launchpad, reason);
    }

    function submitErrorRevert(address launchpad, string memory reason) external onlyRole(EMIT_EVENT) {
        emit ErrorConsumeRevert(launchpad, reason);
    }

    function submitRandomnessRequest() external onlyRole(EMIT_EVENT) {
        emit RandomnessRequest();
    }
}
