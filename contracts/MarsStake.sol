pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MarsStake {
    address public lmc;

    struct User {
        uint256 stake;
        uint256 last;
        uint256 point;
    }

    mapping(address => User) public users;

    constructor() {
        //test
        lmc = 0x5195b2709770180903b7aCB3841B081Ec7b6DfFf;
    }

    function stake(uint256 amount) external {
        _sync();
        User storage user = users[msg.sender];
        IERC20(lmc).transferFrom(msg.sender, address(this), amount);
        user.stake += amount;
    }

    function unstake(uint256 amount) external {
        _sync();
        User storage user = users[msg.sender];
        require(user.stake >= amount, "Insufficient balance");
        IERC20(lmc).transfer(msg.sender, amount);
        user.stake -= amount;
    }

    function _sync() private {
        User storage user = users[msg.sender];
        user.point += user.stake * user.point;
        user.last = block.number;
    }
}
