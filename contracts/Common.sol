pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

abstract contract Common is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20Metadata;

    constructor() Ownable(msg.sender) {}

    function withdrawETH(address payable to) external onlyOwner nonReentrant {
        (bool success, ) = to.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    function withdrawERC20(
        address token,
        address to
    ) external onlyOwner nonReentrant {
        IERC20Metadata(token).safeTransfer(
            to,
            IERC20Metadata(token).balanceOf(address(this))
        );
    }

    function withdrawERC721(
        address token,
        address to,
        uint256[] calldata tokenIds
    ) external onlyOwner nonReentrant {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            IERC721(token).transferFrom(address(this), to, tokenIds[i]);
        }
    }
}
