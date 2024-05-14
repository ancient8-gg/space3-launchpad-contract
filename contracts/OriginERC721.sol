// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract OriginERC721 is Context, AccessControlEnumerable, ERC721Enumerable, ERC721Burnable {

    using Counters for Counters.Counter;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    Counters.Counter private _tokenIdTracker;

    string private _baseTokenURI = "";

    event Minted(address toAddress, uint256 tokenId);
    event MultipleMinted(address toAddress, uint256 from, uint256 to);

    modifier onlyAdmin() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "must have admin role"
        );
        _;
    }

    modifier onlyMinter() {
        require(hasRole(MINTER_ROLE, _msgSender()), "must have minter role");
        _;
    }

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _setupRole(MINTER_ROLE, _msgSender());

        _tokenIdTracker.increment();
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string memory baseTokenURI) external onlyAdmin {
        _baseTokenURI = baseTokenURI;
    }

    function setupMinterRole(address account, bool _enable) external onlyAdmin {
        require(account != address(0), "account must be not equal address 0x");
        if (_enable) {
            _setupRole(MINTER_ROLE, account);
        } else {
            _revokeRole(MINTER_ROLE, account);
        }
    }

    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        string memory currentBaseUri = _baseURI();
        return
            bytes(currentBaseUri).length > 0
                ? string(
                abi.encodePacked(
                    currentBaseUri,
                    Strings.toString(tokenId)
                )
            ) : "";
    }

    function mint(address toAddress) external onlyMinter returns (uint256) {
        require(toAddress != address(0), "could not mint to zero address");

        _mint(toAddress, _tokenIdTracker.current());

        emit Minted(toAddress, _tokenIdTracker.current());

        _tokenIdTracker.increment();

        return _tokenIdTracker.current() - 1;
    }

    function mintBatch(address toAddress, uint256 amount) external onlyMinter returns (uint256) {
        require(toAddress != address(0), "could not mint to zero address");
        uint256 from = _tokenIdTracker.current();
        for (uint256 i = 0; i < amount; i++) {
            _mint(toAddress, _tokenIdTracker.current());
            _tokenIdTracker.increment();
        }

        emit MultipleMinted(toAddress, from, _tokenIdTracker.current() - 1);
        return _tokenIdTracker.current() - 1;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(AccessControlEnumerable, ERC721, ERC721Enumerable)
    returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
