pragma solidity 0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Common is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20Metadata;

    constructor() Ownable(msg.sender) {}

    function withdrawErc721(
        address token,
        address account,
        uint256 tokenId
    ) external onlyOwner nonReentrant {
        IERC721(token).transferFrom(address(this), account, tokenId);
    }

    function withdrawErc20(
        address token,
        address account,
        uint256 amount
    ) external onlyOwner nonReentrant {
        require(
            IERC20Metadata(token).balanceOf(address(this)) >= amount,
            "Common : Not enough balance"
        );
        IERC20Metadata(token).safeTransfer(account, amount);
    }

    function withdrawEth(
        address payable account,
        uint256 amount
    ) external onlyOwner nonReentrant {
        require(address(this).balance >= amount, "Common : Not enough balance");
        account.transfer(amount);
    }
}
