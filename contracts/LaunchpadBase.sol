//SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interface/IOriginERC721.sol";
import "./interface/ILaunchpadFactory.sol";
import "./interface/IEventProvider.sol";
import "./interface/IConfig.sol";
import "./LaunchpadConstants.sol";

contract LaunchpadBase is LaunchpadConstants, OwnableUpgradeable {

    struct SaleInfo {
        uint256 maxSupply;
        uint256 startTime;
        uint256 endTime;
        uint256 price;
        uint256 fee;
        uint256 maxAllocationPerUser;
        bool active;
        uint256 sold;
        bool fcfs;
    }

    struct Purchase {
        uint256 whitelist;
        uint256 publicSale;
        uint256 guaranteed;
    }

    struct PaymentQueue {
        uint256 buyType;
        address sender;
        uint256 paymentAmount; // aka ticketId in ClaimNFT
        uint256 amount;
        uint256 requestId;
    }

    struct UserQueue {
        PaymentQueue[] queue;
        uint256 current;
    }

    struct Refund {
        uint256 amount;
        bool refunded;
    }

    IOriginERC721 public collection;
    IERC20 public paymentToken;
    ILaunchpadFactory public factory;
    IConfig public config;
    SaleInfo public guaranteedSale;
    SaleInfo public privateSale;
    SaleInfo public publicSale;

    address public nftVault;
    mapping(address => Purchase) internal itemSoldMapping;
    mapping(address => UserQueue) internal paymentQueueMapping;
    mapping(address => Refund) internal refundMapping;
    mapping(uint256 => bool) public ticketClaimed;
    address[] public userQueueList;
    uint256 public currentQueue;
    uint256 public mintType;
    mapping(uint256 => mapping(uint256 => bool)) public requestIdIndexMapping;
    mapping(uint256 => mapping(uint256 => bool)) public requestIdTicketIdMapping;
    mapping(address => mapping(uint256 => bool)) public ticketMapping;

    function isMinterLaunchpad() public view returns (bool) {
        return nftVault == address(0);
    }

    function isNativePayment() public view returns (bool) {
        return address(paymentToken) == address(0);
    }

    function isPublicFCFS() public view returns (bool) {
        return publicSale.fcfs;
    }

    function skipQueue(uint256 skip) external onlyOwner {
        require(currentQueue + skip <= userQueueList.length, "Skip too high");
        currentQueue += skip;
    }

    function revertQueue(uint256 _revert) external onlyOwner {
        require(_revert < currentQueue, "Revert too low");
        currentQueue -= _revert;
    }

    function setMinterType(uint256 _mintType) public onlyOwner {
        mintType = _mintType;
        if (_mintType == MINT_TYPE_MULTI) {
            nftVault = address(0);
        }
    }

    function _consumeRandomness(uint256 randomness) internal returns (bool){
        uint256 nftBalanceOfVault = collection.balanceOf(nftVault);
        require(nftBalanceOfVault > 0, "Vault dont have any NFT");
        uint256 indexPicker = (randomness % nftBalanceOfVault);

        if (userQueueList.length <= currentQueue) {
            return false;
        }

        address user = userQueueList[currentQueue];
        currentQueue++;
        UserQueue storage userQueue = paymentQueueMapping[user];
        require(userQueue.queue.length > userQueue.current, "User dont have any queue");
        PaymentQueue memory payment = userQueue.queue[userQueue.current];
        userQueue.current++;

        uint256 id = collection.tokenOfOwnerByIndex(nftVault, indexPicker);
        collection.transferFrom(nftVault, payment.sender, id);
        if (payment.buyType == CLAIM_NFT) {
            _getEventProvider().submitNFTClaim(address(this), user, payment.paymentAmount, id, payment.requestId);
        } else {
            _getEventProvider().submitBuyNFTBatch(address(this), payment.buyType, payment.sender, payment.paymentAmount, 1, id, payment.amount, payment.requestId);
        }
        return true;
    }

    function _getEventProvider() internal view returns (IEventProvider) {
        return IEventProvider(config.eventProvider());
    }

    function _transferTokenToAddress(address sender, uint256 amount) internal returns (uint256) {
        if (isNativePayment()) {
            require(address(this).balance >= amount, "Not enough balance");
            (bool sent,) = sender.call{value: amount}("");
            require(sent, "Refund failed");
            return TOKEN_NATIVE;
        } else {
            require(paymentToken.balanceOf(address(this)) >= amount, "Not enough balance");
            paymentToken.transfer(sender, amount);
            return TOKEN_ERC20;
        }
    }

    function _updateLaunchpad(address _collection, address _paymentToken, address _nftVault) internal {
        require(_collection != address(0), "Collection address invalid");

        nftVault = _nftVault;
        collection = IOriginERC721(_collection);
        paymentToken = IERC20(_paymentToken);

        _getEventProvider().submitLaunchpadUpdate(address(this), _collection, _paymentToken);
    }

    function _updateInfo(uint256[] memory _saleInfo) internal {
        bool updated = false;
        if (!_isStart(publicSale)) {
            _updateSaleInfo(publicSale, _saleInfo, 0);
            updated = true;
        }

        if (!_isStart(privateSale)) {
            _updateSaleInfo(privateSale, _saleInfo, SALE_INFO_OFFSET);
            updated = true;
        }

        if (!_isStart(guaranteedSale)) {
            _updateSaleInfo(guaranteedSale, _saleInfo, 2 * SALE_INFO_OFFSET);
            updated = true;
        }
        require(updated, "Sale info cannot update after started");
        _getEventProvider().submitSaleInfoUpdate(address(this), _saleInfo);
    }

    function _updateSaleInfo(SaleInfo storage _saleInfo, uint256[] memory _saleInfos, uint256 offset) internal {
        uint256 _startTime = _saleInfos[2 + offset];
        uint256 _endTime = _saleInfos[3 + offset];

        require(block.timestamp < _startTime, "Start time invalidate");
        require(_startTime < _endTime, "Start time must be lower than End time");

        _saleInfo.maxSupply = _saleInfos[0 + offset];
        _saleInfo.maxAllocationPerUser = _saleInfos[1 + offset];
        _saleInfo.startTime = _startTime;
        _saleInfo.endTime = _endTime;
        _saleInfo.price = _saleInfos[4 + offset];
        _saleInfo.fee = _saleInfos[5 + offset];
        _saleInfo.active = _saleInfos[6 + offset] == 1;
        _saleInfo.fcfs = _saleInfos[7 + offset] == 1;
    }

    function getRefundInfo(address _user) external view returns (Refund memory) {
        return refundMapping[_user];
    }

    function _buyNFTValidate(SaleInfo memory saleInfo, uint256 quantity, uint256 offset) internal view {
        require(saleInfo.active, "Sale not active");
        require(block.timestamp > saleInfo.startTime, "Sale not started");
        require(block.timestamp < saleInfo.endTime, "Sale ended");
        require(saleInfo.sold + quantity <= saleInfo.maxSupply + offset, "The purchase limit has been reached");
    }

    function _buyNFTWhitelist(uint256 buyType, uint256 quantity, uint256 paymentAmount, uint256[] memory index, uint256 requestId) internal {
        uint256 offset = _isEnd(guaranteedSale) ? guaranteedSale.maxSupply - guaranteedSale.sold : 0;

        _buyNFTValidate(privateSale, quantity, offset);
        Purchase storage purchased = itemSoldMapping[_msgSender()];
        require(purchased.whitelist + quantity <= privateSale.maxAllocationPerUser, "The individual purchase limit has been reached.");

        privateSale.sold += quantity;
        purchased.whitelist += quantity;

        _buyNFT(buyType, quantity, paymentAmount, index, requestId);
    }

    function _buyNFTGuaranteed(uint256 buyType, uint256 quantity, uint256 paymentAmount, uint256[] memory index, uint256 requestId) internal {
        _buyNFTValidate(guaranteedSale, quantity, 0);
        Purchase storage purchased = itemSoldMapping[_msgSender()];
        require(purchased.guaranteed + quantity <= guaranteedSale.maxAllocationPerUser, "The individual purchase limit has been reached.");

        guaranteedSale.sold += quantity;
        purchased.guaranteed += quantity;

        _buyNFT(buyType, quantity, paymentAmount, index, requestId);
    }

    function _buyNFTPublic(uint256 buyType, uint256 quantity, uint256 paymentAmount, uint256[] memory index, uint256 requestId) internal {
        uint256 offset = _getNFTRemaining();
        _buyNFTValidate(publicSale, quantity, offset);
        Purchase storage purchased = itemSoldMapping[_msgSender()];
        require(purchased.publicSale + quantity <= publicSale.maxAllocationPerUser, "The individual purchase limit has been reached.");

        publicSale.sold += quantity;
        purchased.publicSale += quantity;

        _buyNFT(buyType, quantity, paymentAmount, index, requestId);
    }

    function _getNFTRemaining() internal view returns (uint256) {
        (uint256 maxSupplyG, uint256 soldG) = _getPurchaseInfo(guaranteedSale);
        (uint256 maxSupplyW, uint256 soldW) = _getPurchaseInfo(privateSale);
        return (maxSupplyG + maxSupplyW) - (soldG + soldW);
    }

    function _getPurchaseInfo(SaleInfo memory saleInfo) private view returns (uint256 maxSupply, uint256 sold) {
        if (!_isEnd(saleInfo)) {
            maxSupply = 0;
            sold = 0;
        } else {
            maxSupply = saleInfo.active ? saleInfo.maxSupply : 0;
            sold = saleInfo.active ? saleInfo.sold : 0;
        }
    }

    function _buyNFT(uint256 buyType, uint256 quantity, uint256 paymentAmount, uint256[] memory index, uint256 requestId) internal {
        if (isMinterLaunchpad()) {
            (uint256 from, uint256 to) = _mintNFTToAddress(_msgSender(), quantity);
            _getEventProvider().submitBuyNFT(address(this), buyType, _msgSender(), paymentAmount, quantity, from, to, requestId);
            return;
        }

        // buy nft with nft vault
        for (uint256 i = 0; i < index.length; i++) {
            requestIdIndexMapping[requestId][index[i]] = true;
            paymentQueueMapping[_msgSender()].queue.push(PaymentQueue(buyType, _msgSender(), paymentAmount, index[i], requestId));
            userQueueList.push(_msgSender());
            factory.requestRandomness();
        }
    }

    function _mintNFTToAddress(address sender, uint256 quantity) internal returns (uint256 from, uint256 to) {
        if (mintType == MINT_TYPE_BATCH) {
            to = collection.mintBatch(sender, quantity);
            from = to + 1 - quantity;
        } else if (mintType == MINT_TYPE_MULTI) {
            from = collection.totalSupply() + 1;
            to = from + quantity - 1;
            collection.mintMulti(sender, quantity);
        } else {
            revert("MintType invalid");
        }
    }

    function _buyTicket(uint256 buyType, uint256 paymentAmount, uint256 quantity, uint256 requestId) internal {
        require(publicSale.active, "PublicSale not active");
        require(block.timestamp > publicSale.startTime, "PublicSale not started");
        require(block.timestamp < publicSale.endTime, "PublicSale ended");
        Purchase storage purchased = itemSoldMapping[_msgSender()];
        require(purchased.publicSale + quantity <= publicSale.maxAllocationPerUser, "The individual purchase limit has been reached.");

        uint256 from = publicSale.sold;
        uint256 to = publicSale.sold + quantity - 1;
        publicSale.sold += quantity;
        purchased.publicSale += quantity;

        for (uint256 i = 0; i < quantity; i ++) {
            ticketMapping[_msgSender()][i + from] = true;
        }

        _getEventProvider().submitBuyTicket(address(this), buyType, _msgSender(), paymentAmount, from, to, requestId);
    }

    function _claimNFTWithTicketId(uint256 ticketId, uint256 requestId) internal {
        requestIdTicketIdMapping[requestId][ticketId] = true;
        require(ticketMapping[_msgSender()][ticketId], "User not own this ticket");
        require(!ticketClaimed[ticketId], "ticket claim already requested");
        ticketClaimed[ticketId] = true;
        if (isMinterLaunchpad()) {
            (uint256 from,) = _mintNFTToAddress(_msgSender(), 1);
            _getEventProvider().submitNFTClaim(address(this), _msgSender(), ticketId, from, requestId);
        } else {
            paymentQueueMapping[_msgSender()].queue.push(PaymentQueue(CLAIM_NFT, _msgSender(), ticketId, 1, requestId));
            userQueueList.push(_msgSender());
            factory.requestRandomness();
            _getEventProvider().submitNFTClaimRequested(address(this), _msgSender(), ticketId, requestId);
        }
    }

    function _startTimeValid() internal view {
        require(!_isStart(publicSale), "Cannot change payment token after publicSale started");
        require(!_isStart(privateSale), "Cannot change payment token after privateSale started");
        require(!_isStart(guaranteedSale), "Cannot change payment token after guaranteedSale started");
    }

    function _isStart(SaleInfo memory _saleInfo) internal view returns (bool) {
        return _saleInfo.startTime <= block.timestamp && _saleInfo.active;
    }

    function _isEnd(SaleInfo memory _saleInfo) internal view returns (bool) {
        return _saleInfo.endTime <= block.timestamp && _saleInfo.active;
    }
}
