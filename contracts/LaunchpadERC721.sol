//SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interface/IOriginERC721.sol";
import "./interface/ILaunchpadFactory.sol";
import "./interface/IEventProvider.sol";
import "./interface/IConfig.sol";
import "./LaunchpadBase.sol";

contract LaunchpadERC721 is LaunchpadBase {

    modifier onlyFactory() {
        require(address(factory) == msg.sender, "Sender not factory");
        _;
    }

    modifier ignoreOwner() {
        require(_msgSender() != owner(), "Owner not permit");
        _;
    }

    function initialize(address _collection, address _paymentToken, address _nftVault) public initializer {
        __Ownable_init();

        factory = ILaunchpadFactory(_msgSender());
        config = IConfig(factory.getConfig());

        _updateLaunchpad(_collection, _paymentToken, _nftVault);
    }

    function updateLaunchpad(
        address _collection,
        address _paymentToken,
        address _nftVault
    ) external onlyOwner {
        _startTimeValid();
        _updateLaunchpad(_collection, _paymentToken, _nftVault);
    }

    function updateLaunchpadSaleInfo(uint256[] memory _saleInfo) external onlyOwner {
        _updateInfo(_saleInfo);
    }

    function updateSaleInfoMintType(uint256 mintType, uint256[] memory _saleInfo) external onlyOwner {
        _updateInfo(_saleInfo);
        if (!_isStart(publicSale) && !_isStart(privateSale) && !_isStart(guaranteedSale)) {
            setMinterType(mintType);
        }
    }

    function updatePaymentToken(address _paymentToken) external onlyOwner {
        _startTimeValid();
        paymentToken = IERC20(_paymentToken);
        _getEventProvider().submitLaunchpadUpdate(address(this), address(collection), _paymentToken);
    }

    function updateCollectionBaseURI(string memory baseURI) external onlyOwner {
        IOriginERC721(collection).setBaseURI(baseURI);
    }

    function buyNFTWhitelistERC20(uint256 quantity, uint256 maxQuantity, bytes memory signature, uint256[] memory index, uint256 requestId, uint256 expiredTime) external ignoreOwner {
        require(!isNativePayment(), "payment method not support");
        uint256 paymentAmount = quantity * privateSale.price;
        paymentToken.transferFrom(msg.sender, address(this), paymentAmount);
        bytes32 msgHash = keccak256(
            abi.encodePacked(_msgSender(), TYPE_FUNC_BUY_NFT_WL_ERC20, quantity, maxQuantity, index, requestId, expiredTime)
        );
        require(factory.validSignature(TYPE_FUNC_BUY_NFT_WL_ERC20, msgHash, signature, requestId, expiredTime), "Signature invalid");
        _buyNFTWhitelist(TOKEN_ERC20, quantity, maxQuantity, paymentAmount, index, requestId);
    }

    function buyNFTWhitelistETH(uint256 quantity, uint256 maxQuantity, bytes memory signature, uint256[] memory index, uint256 requestId, uint256 expiredTime) external payable ignoreOwner {
        require(isNativePayment(), "payment method not support");
        uint256 paymentAmount = quantity * privateSale.price;
        require(msg.value == paymentAmount, "value invalidate");
        bytes32 msgHash = keccak256(
            abi.encodePacked(_msgSender(), TYPE_FUNC_BUY_NFT_WL_NATIVE, quantity, maxQuantity, index, requestId, expiredTime)
        );
        require(factory.validSignature(TYPE_FUNC_BUY_NFT_WL_NATIVE, msgHash, signature, requestId, expiredTime), "Signature invalid");
        _buyNFTWhitelist(TOKEN_NATIVE, quantity, maxQuantity, paymentAmount, index, requestId);
    }

    function buyNFTGuaranteedERC20(uint256 quantity, uint256 maxQuantity, bytes memory signature, uint256[] memory index, uint256 requestId, uint256 expiredTime) external ignoreOwner {
        require(!isNativePayment(), "payment method not support");
        uint256 paymentAmount = quantity * guaranteedSale.price;
        paymentToken.transferFrom(msg.sender, address(this), paymentAmount);
        bytes32 msgHash = keccak256(
            abi.encodePacked(_msgSender(), TYPE_FUNC_BUY_NFT_GT_ERC20, quantity, maxQuantity, index, requestId, expiredTime)
        );
        require(factory.validSignature(TYPE_FUNC_BUY_NFT_GT_ERC20, msgHash, signature, requestId, expiredTime), "Signature invalid");
        _buyNFTGuaranteed(TOKEN_ERC20, quantity, maxQuantity, paymentAmount, index, requestId);
    }

    function buyNFTGuaranteedETH(uint256 quantity, uint256 maxQuantity, bytes memory signature, uint256[] memory index, uint256 requestId, uint256 expiredTime) external payable ignoreOwner {
        require(isNativePayment(), "payment method not support");
        uint256 paymentAmount = quantity * guaranteedSale.price;
        require(msg.value == paymentAmount, "value invalidate");
        bytes32 msgHash = keccak256(
            abi.encodePacked(_msgSender(), TYPE_FUNC_BUY_NFT_GT_NATIVE, quantity, maxQuantity, index, requestId, expiredTime)
        );
        require(factory.validSignature(TYPE_FUNC_BUY_NFT_GT_NATIVE, msgHash, signature, requestId, expiredTime), "Signature invalid");
        _buyNFTGuaranteed(TOKEN_NATIVE, quantity, maxQuantity, paymentAmount, index, requestId);
    }

    function buyNFTPublicERC20(uint256 quantity, bytes memory signature, uint256[] memory index, uint256 requestId, uint256 expiredTime) external ignoreOwner {
        require(!isNativePayment(), "payment method not support");
        require(isPublicFCFS(), "Public not FCFS");
        uint256 paymentAmount = quantity * publicSale.price;
        paymentToken.transferFrom(msg.sender, address(this), paymentAmount);
        bytes32 msgHash = keccak256(
            abi.encodePacked(_msgSender(), TYPE_FUNC_BUY_NFT_PL_ERC20, quantity, index, requestId, expiredTime)
        );
        require(factory.validSignature(TYPE_FUNC_BUY_NFT_PL_ERC20, msgHash, signature, requestId, expiredTime), "Signature invalid");
        _buyNFTPublic(TOKEN_ERC20, quantity, paymentAmount, index, requestId);
    }

    function buyNFTPublicETH(uint256 quantity, bytes memory signature, uint256[] memory index, uint256 requestId, uint256 expiredTime) external payable ignoreOwner {
        require(isNativePayment(), "payment method not support");
        require(isPublicFCFS(), "Public not FCFS");
        uint256 paymentAmount = quantity * publicSale.price;
        require(msg.value == paymentAmount, "value invalidate");
        bytes32 msgHash = keccak256(
            abi.encodePacked(_msgSender(), TYPE_FUNC_BUY_NFT_PL_NATIVE, quantity, index, requestId, expiredTime)
        );
        require(factory.validSignature(TYPE_FUNC_BUY_NFT_PL_NATIVE, msgHash, signature, requestId, expiredTime), "Signature invalid");
        _buyNFTPublic(TOKEN_NATIVE, quantity, paymentAmount, index, requestId);
    }

    function buyTicketERC20(uint256 quantity, bytes memory signature, uint256 requestId, uint256 expiredTime) external ignoreOwner {
        require(!isNativePayment(), "payment method not support");
        require(!isPublicFCFS(), "Public is FCFS");
        uint256 paymentAmount = quantity * publicSale.price;
        paymentToken.transferFrom(msg.sender, address(this), paymentAmount);
        bytes32 msgHash = keccak256(
            abi.encodePacked(_msgSender(), TYPE_FUNC_BUY_TICKET_ERC20, quantity, requestId, expiredTime)
        );
        require(factory.validSignature(TYPE_FUNC_BUY_TICKET_ERC20, msgHash, signature, requestId, expiredTime), "Signature invalid");
        _buyTicket(TOKEN_ERC20, paymentAmount, quantity, requestId);
    }

    function buyTicketETH(uint256 quantity, bytes memory signature, uint256 requestId, uint256 expiredTime) external payable ignoreOwner {
        require(isNativePayment(), "payment method not support");
        require(!isPublicFCFS(), "Public is FCFS");
        uint256 paymentAmount = quantity * publicSale.price;
        require(msg.value == paymentAmount, "value invalidate");
        bytes32 msgHash = keccak256(
            abi.encodePacked(_msgSender(), TYPE_FUNC_BUY_TICKET_NATIVE, quantity, requestId, expiredTime)
        );
        require(factory.validSignature(TYPE_FUNC_BUY_TICKET_NATIVE, msgHash, signature, requestId, expiredTime), "Signature invalid");
        _buyTicket(TOKEN_NATIVE, paymentAmount, quantity, requestId);
    }

    function refund(uint256 amount, bytes memory signature, uint256 requestId, uint256 expiredTime) external ignoreOwner {
        bytes32 msgHash = keccak256(
            abi.encodePacked(_msgSender(), TYPE_FUNC_REFUND, amount, requestId, expiredTime)
        );
        require(factory.validSignature(TYPE_FUNC_REFUND, msgHash, signature, requestId, expiredTime), "Signature invalid");
        require(block.timestamp > publicSale.endTime, "Cannot NFT token before publicSale's endTime");
        Refund storage userRefund = refundMapping[_msgSender()];
        require(!userRefund.refunded, "User refunded");
        userRefund.refunded = true;
        userRefund.amount = amount;
        _transferTokenToAddress(_msgSender(), amount);
        _getEventProvider().submitRefund(address(this), _msgSender(), amount, requestId);
    }

    function claimNFT(uint256[] memory ticketIds, bytes memory signature, uint256 requestId, uint256 expiredTime) external ignoreOwner {
        bytes32 msgHash = keccak256(
            abi.encodePacked(_msgSender(), TYPE_FUNC_CLAIM_NFT, ticketIds, requestId, expiredTime)
        );
        require(factory.validSignature(TYPE_FUNC_CLAIM_NFT, msgHash, signature, requestId, expiredTime), "Signature invalid");
        require(block.timestamp > publicSale.endTime, "Cannot NFT token before publicSale's endTime");
        for (uint256 i = 0; i < ticketIds.length; i++) {
            uint256 ticketId = ticketIds[i];
            _claimNFTWithTicketId(ticketId, requestId);
        }
    }

    function claimToken(address _to, uint256 _amount, bytes memory signature, uint256 requestId, uint256 expiredTime) external onlyOwner {
        bytes32 msgHash = keccak256(
            abi.encodePacked(_msgSender(), TYPE_FUNC_CLAIM_TOKEN, _to, _amount, requestId, expiredTime)
        );
        require(factory.validSignature(TYPE_FUNC_CLAIM_TOKEN, msgHash, signature, requestId, expiredTime), "Signature invalid");
        require(block.timestamp > publicSale.endTime, "Cannot claim token before publicSale's endTime");
        require(block.timestamp > privateSale.endTime, "Cannot claim token before privateSale's endTime");
        require(block.timestamp > guaranteedSale.endTime, "Cannot claim token before privateSale's endTime");
        uint256 buyType = _transferTokenToAddress(_to, _amount);
        _getEventProvider().submitTokenClaim(address(this), buyType, _to, _amount, requestId);
    }

    // orochi consume
    function consumeRandomness(uint256 randomness) external onlyFactory returns (bool) {
        return _consumeRandomness(randomness);
    }

    function getPendingTX(address _user) external view returns (uint256){
        UserQueue memory paymentQueue = paymentQueueMapping[_user];
        if (paymentQueue.queue.length > paymentQueue.current) {
            return paymentQueue.queue.length - paymentQueue.current;
        }
        return 0;
    }

    function getLaunchpadPendingTX() external view returns (uint256){
        if (userQueueList.length > currentQueue) {
            return userQueueList.length - currentQueue;
        }
        return 0;
    }

    function checkRequestIdIndex(uint256 requestId, uint256 index) external view returns (bool) {
        return requestIdIndexMapping[requestId][index];
    }

    function checkRequestIdTicketId(uint256 requestId, uint256 ticketId) external view returns (bool) {
        return requestIdTicketIdMapping[requestId][ticketId];
    }

    function getPurchase(address _user) external view returns (Purchase memory) {
        return itemSoldMapping[_user];
    }

    function getQueue(address _user) external view returns (UserQueue memory) {
        return paymentQueueMapping[_user];
    }

    function reOwnNFT(address _newOwner) external onlyOwner {
        if (mintType == MINT_TYPE_MULTI) {
            collection.transferOwnership(_newOwner);
        } else if (mintType == MINT_TYPE_BATCH) {
            collection.grantRole(DEFAULT_ADMIN_ROLE, _newOwner);
            collection.revokeRole(MINTER_ROLE, address(this));
            collection.revokeRole(DEFAULT_ADMIN_ROLE, address(this));
        }
    }
}