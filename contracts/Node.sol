pragma solidity 0.8.22;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Common} from "./Common.sol";

contract S is ERC20 {
    constructor(
        address account,
        uint256 amount
    ) ERC20("Littlemami Coin", "LMC") {
        _mint(account, amount);
    }
}

contract Node is Common {
    using Math for uint256;

    using SafeERC20 for IERC20Metadata;

    uint256 public maxSell;

    uint256 public totalSell;

    uint256 public tokenPrice;

    address public tokenAddress;

    uint256 public grow;

    uint256 public growDivBy;

    event Buy(address indexed buyer, uint256 num);

    constructor() {
        S s = new S(msg.sender, 1e30);
        tokenPrice = 300 * 1e18;
        tokenAddress = address(s);

        maxSell = 30000;
        grow = 1005;
        growDivBy = 1000;
    }

    function buy(uint256 num) external nonReentrant {
        require(totalSell + num <= maxSell, "Node : Out of max sell");
        uint256 totalTokenNeed;
        for (uint256 i = 0; i < num; i++) {
            totalTokenNeed += tokenPrice;
            totalSell += 1;
            _setPrice();
        }
        IERC20Metadata(tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            totalTokenNeed
        );
        emit Buy(msg.sender, num);
    }

    function _setPrice() private {
        if (totalSell % 50 == 0) {
            uint256 tokenDecimals = IERC20Metadata(tokenAddress).decimals();
            tokenPrice = ((tokenPrice * grow) / growDivBy).ceilDiv(
                10 ** tokenDecimals
            );
            tokenPrice = tokenPrice * 10 ** tokenDecimals;
        }
    }

    function set(address token, uint256 price) external onlyOwner {
        tokenAddress = token;
        tokenPrice = price;
    }
}
