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

    address[] public userAddresses;

    constructor() {
        //test
        lmc = 0x5195b2709770180903b7aCB3841B081Ec7b6DfFf;
    }

    function getUserAddressesLength() external view returns (uint256) {
        return userAddresses.length;
    }

    function stake(uint256 amount) external {
        _sync(msg.sender);
        User storage user = users[msg.sender];
        IERC20(lmc).transferFrom(msg.sender, address(this), amount);
        user.stake += amount;
    }

    function unstake(uint256 amount) external {
        _sync(msg.sender);
        User storage user = users[msg.sender];
        require(user.stake >= amount, "Insufficient balance");
        IERC20(lmc).transfer(msg.sender, amount);
        user.stake -= amount;
    }

    function _sync(address addr) private {
        User storage user = users[addr];
        if (user.last == 0) {
            userAddresses.push(addr);
        }
        user.point += user.stake * (block.number - user.last);
        user.last = block.number;
    }

    function getPendingPoint(address addr) external view returns (uint256) {
        User memory user = users[addr];
        return user.point + user.stake * (block.number - user.last);
    }
}
