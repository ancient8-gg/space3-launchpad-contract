// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract LaunchpadConstants {

    uint256 public constant FULL_PERCENTAGE = 10000;

    uint256 public constant TOKEN_ERC20 = 2001;
    uint256 public constant TOKEN_NATIVE = 2002;
    uint256 public constant CLAIM_NFT = 2003;

    bytes32 internal constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;

    uint256 internal constant SALE_INFO_OFFSET = 8;
    uint256 internal constant TYPE_FUNC_BUY_NFT_WL_ERC20 = 1;
    uint256 internal constant TYPE_FUNC_BUY_NFT_PL_ERC20 = 11;
    uint256 internal constant TYPE_FUNC_BUY_NFT_GT_ERC20 = 12;
    uint256 internal constant TYPE_FUNC_BUY_NFT_WL_NATIVE = 2;
    uint256 internal constant TYPE_FUNC_BUY_NFT_PL_NATIVE = 21;
    uint256 internal constant TYPE_FUNC_BUY_NFT_GT_NATIVE = 22;
    uint256 internal constant TYPE_FUNC_BUY_TICKET_ERC20 = 3;
    uint256 internal constant TYPE_FUNC_BUY_TICKET_NATIVE = 4;
    uint256 internal constant TYPE_FUNC_REFUND = 5;
    uint256 internal constant TYPE_FUNC_CLAIM_NFT = 6;
    uint256 internal constant TYPE_FUNC_CLAIM_TOKEN = 7;

    uint256 public constant MINT_TYPE_BATCH = 0;
    uint256 public constant MINT_TYPE_MULTI = 1001;
}
