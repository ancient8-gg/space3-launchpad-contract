//SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./OriginERC721.sol";
import "./interface/ILaunchpadERC721.sol";
import "./interface/IEventProvider.sol";
import "./interface/IConfig.sol";

contract LaunchpadFactory is AccessControlEnumerableUpgradeable {
    using Clones for address;

    bytes32 public constant CREATE_LAUNCHPAD = keccak256("CREATE_LAUNCHPAD");

    uint256 internal constant TYPE_FUNC_BUY_NFT_WL_ERC20 = 1;
    uint256 internal constant TYPE_FUNC_BUY_NFT_PL_ERC20 = 11;
    uint256 internal constant TYPE_FUNC_BUY_NFT_WL_NATIVE = 2;
    uint256 internal constant TYPE_FUNC_BUY_NFT_PL_NATIVE = 21;
    uint256 internal constant TYPE_FUNC_BUY_TICKET_ERC20 = 3;
    uint256 internal constant TYPE_FUNC_BUY_TICKET_NATIVE = 4;
    uint256 internal constant TYPE_FUNC_BUY_NFT_GT_ERC20 = 12;
    uint256 internal constant TYPE_FUNC_BUY_NFT_GT_NATIVE = 22;
    uint256 internal constant TYPE_FUNC_REFUND = 5;
    uint256 internal constant TYPE_FUNC_CLAIM_NFT = 6;
    uint256 internal constant TYPE_FUNC_CLAIM_TOKEN = 7;
    uint256 internal constant TYPE_FUNC_LAUNCHPAD = 8;

    IConfig public config;
    address[] public nftList;
    address[] public launchpadList;
    address[] public launchpadQueue;
    uint256 public currentQueue;

    mapping(uint256 => mapping(uint256 => bool)) private requestIdStorage;
    mapping(bytes => bool) public signatureUsed;
    mapping(address => bool) public launchpadMapping;

    modifier onlyOrandProvider() {
        require(_msgSender() == config.orochiProvider() || _msgSender() == config.orochiProvider2(), "Provider Invalid");
        _;
    }

    modifier onlyLaunchpad() {
        require(launchpadMapping[msg.sender], "Sender not launchpad");
        _;
    }

    modifier onlyAdmin() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "must have admin role"
        );
        _;
    }

    modifier onlyCreator() {
        require(
            hasRole(CREATE_LAUNCHPAD, _msgSender()),
            "must have create launchpad role"
        );
        _;
    }

    function initialize(address _config) public initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        config = IConfig(_config);
    }

    function setConfig(address _config) external onlyAdmin {
        config = IConfig(_config);
    }

    function skipQueue(uint256 skip) external onlyAdmin {
        require(currentQueue + skip <= launchpadQueue.length, "Skip too high");
        currentQueue += skip;
    }

    function revertQueue(uint256 _revert) external onlyAdmin {
        require(_revert < currentQueue, "Revert too low");
        currentQueue -= _revert;
    }

    function setupLaunchpad(
        address _collection,
        uint256[] memory _saleInfo,
        address _paymentToken,
        address _nftVault,
        bytes memory _signature,
        uint256 _requestId,
        uint256 _expiredTime
    ) external onlyCreator returns (address) {
        bytes32 msgHash = keccak256(
            abi.encodePacked(_msgSender(), TYPE_FUNC_LAUNCHPAD, _collection, _saleInfo, _paymentToken, _nftVault, _requestId, _expiredTime)
        );
        require(validSignature(TYPE_FUNC_LAUNCHPAD, msgHash, _signature, _requestId, _expiredTime), "Signature invalid");
        require(_nftVault != address(0), "NFT Vault cannot be Zero");
        return _setupLaunchpad(_collection, _saleInfo, _paymentToken, _nftVault, _requestId);
    }

    function createToken(
        string memory _name,
        string memory _symbol,
        string memory _baseURI,
        address _paymentToken,
        uint256[] memory _saleInfo,
        bytes memory signature,
        uint256 requestId,
        uint256 expiredTime
    ) external onlyCreator returns (address) {
        bytes32 msgHash = keccak256(
            abi.encodePacked(_msgSender(), TYPE_FUNC_LAUNCHPAD, _name, _symbol, _baseURI, _paymentToken, _saleInfo, requestId, expiredTime)
        );
        require(validSignature(TYPE_FUNC_LAUNCHPAD, msgHash, signature, requestId, expiredTime), "Signature invalid");
        OriginERC721 nft = new OriginERC721(_name, _symbol);
        address nftAddress = address(nft);
        nftList.push(nftAddress);
        address launchpadAddress = _setupLaunchpad(nftAddress, _saleInfo, _paymentToken, address(0), requestId);

        nft.setBaseURI(_baseURI);
        nft.grantRole(nft.DEFAULT_ADMIN_ROLE(), launchpadAddress);
        nft.grantRole(nft.MINTER_ROLE(), launchpadAddress);
        nft.revokeRole(nft.MINTER_ROLE(), address(this));
        nft.revokeRole(nft.DEFAULT_ADMIN_ROLE(), address(this));

        return nftAddress;
    }

    function pushOrochiRandom(uint256 _count) external onlyOrandProvider {
        for (uint256 i = 0; i < _count; i++) {
            _requestOrochi();
        }
    }

    function consumeRandomnessBatch(uint256[] memory randomnesses) external onlyOrandProvider {
        for (uint256 i = 0; i < randomnesses.length; i++) {
            _consumeRandomness(randomnesses[i]);
        }
    }

    function consumeRandomness(uint256 randomness) external onlyOrandProvider returns (bool) {
        return _consumeRandomness(randomness);
    }

    function requestRandomness() external onlyLaunchpad {
        _requestRandomness();
    }

    function getConfig() external view returns (address){
        return address(config);
    }

    function getQueueLength() external view returns (uint256){
        return launchpadQueue.length;
    }

    function queryRequestId(uint256 typeFunc, uint256[] memory requestIds) external view returns (bool[] memory){
        bool[] memory result = new bool[](requestIds.length);
        uint256 typeTable = _getTypeTableFromTypeFunc(typeFunc);

        for (uint256 i = 0; i < requestIds.length; i++) {
            result[i] = requestIdStorage[typeTable][requestIds[i]];
        }

        return result;
    }

    function validSignature(uint256 typeFunc, bytes32 hash, bytes memory signature, uint256 requestId, uint256 expiredTime) public returns (bool) {
        require(block.timestamp < expiredTime, "Request expired");
        require(requestId > 0, "RequestId invalid");

        uint256 typeTable = _getTypeTableFromTypeFunc(typeFunc);
        require(!requestIdStorage[typeTable][requestId], "RequestId already used");
        requestIdStorage[typeTable][requestId] = true;

        require(!signatureUsed[signature], "Signature already used");
        signatureUsed[signature] = true;
        return isValidSign(signature, hash, config.signer());
    }

    function isValidSign(bytes memory signature, bytes32 hash, address signer) public pure returns (bool) {
        return ECDSA.recover(ECDSA.toEthSignedMessageHash(hash), signature) == signer;
    }

    function checkRequestIdIndex(address launchpad, uint256 requestId, uint256 index) external view returns (bool) {
        return ILaunchpadERC721(launchpad).checkRequestIdIndex(requestId, index);
    }

    function checkRequestIdTicketId(address launchpad, uint256 requestId, uint256 ticketId) external view returns (bool) {
        return ILaunchpadERC721(launchpad).checkRequestIdTicketId(requestId, ticketId);
    }

    function _getTypeTableFromTypeFunc(uint256 typeFunc) private pure returns (uint256){
        uint256 typeTable = typeFunc;
        if (
            (typeFunc >= TYPE_FUNC_BUY_NFT_WL_ERC20 && typeFunc <= TYPE_FUNC_BUY_TICKET_NATIVE) ||
            typeFunc == TYPE_FUNC_BUY_NFT_PL_ERC20 || typeFunc == TYPE_FUNC_BUY_NFT_PL_NATIVE ||
            typeFunc == TYPE_FUNC_BUY_NFT_GT_ERC20 || typeFunc == TYPE_FUNC_BUY_NFT_GT_NATIVE
        ) {
            typeTable = TYPE_FUNC_BUY_NFT_WL_ERC20;
        }
        return typeTable;
    }

    function _getEventProvider() private view returns (IEventProvider) {
        return IEventProvider(config.eventProvider());
    }

    function _setupLaunchpad(
        address _collection,
        uint256[] memory _saleInfo,
        address _paymentToken,
        address _nftVault,
        uint256 _requestId
    ) private returns (address) {
        require(config.launchpadImplement() != address(0), "launchpad not found");
        require(_collection != address(0), "Collection invalid");

        IEventProvider eventProvider = _getEventProvider();
        address launchpadAddress = config.launchpadImplement().clone();
        eventProvider.grantRole(eventProvider.EMIT_EVENT(), launchpadAddress);
        ILaunchpadERC721 launchpad = ILaunchpadERC721(launchpadAddress);

        launchpad.initialize(_collection, _paymentToken, _nftVault);
        launchpad.updateLaunchpadSaleInfo(_saleInfo);
        launchpad.transferOwnership(_msgSender());

        launchpadList.push(launchpadAddress);
        launchpadMapping[launchpadAddress] = true;

        eventProvider.submitCreateLaunchpad(launchpadAddress, _collection, _msgSender(), _requestId);

        return launchpadAddress;
    }

    function _requestRandomness() private {
        launchpadQueue.push(msg.sender);
        _requestOrochi();
    }

    function _requestOrochi() private {
        _getEventProvider().submitRandomnessRequest();
    }

    function _consumeRandomness(uint256 randomness) private returns (bool){
        if (currentQueue >= launchpadQueue.length) return false;
        bool result;
        try ILaunchpadERC721(launchpadQueue[currentQueue]).consumeRandomness(randomness) returns (bool success){
            result = success;
        } catch Error(string memory reason) {
            _getEventProvider().submitErrorRevert(address(this), reason);
            result = false;
        } catch(bytes memory reason){
            _getEventProvider().submitErrorConsume(address(this), reason);
            result = false;
        }
        currentQueue++;
        return result;
    }

}