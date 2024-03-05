pragma solidity ^0.8.22;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface RewardsToken {
    function mint(address, uint256) external;
}

contract MamiStakeV2 is Ownable, ReentrancyGuard {
    struct Pool {
        address nftAddress;
        address tokenAddress;
        uint256 tokenAmount;
        uint256 rate;
        address rewardsTokenAddress;
    }

    struct User {
        uint256 last;
        uint256 amount;
        uint256 remain;
    }

    mapping(uint256 => Pool) public poolInfos;

    //poolId => user addrs
    mapping(uint256 => address[]) public poolAddrs;
    //poolId => user address => User
    mapping(uint256 => mapping(address => User)) public poolUsers;
    //poolId => pass token id => user address
    mapping(uint256 => mapping(uint256 => address)) public passUsed;
    //poolId => stake token id => user address
    mapping(uint256 => mapping(uint256 => address)) public tokenUsed;

    constructor() Ownable(msg.sender) {}

    function stake(
        uint256 poolId,
        uint256[] calldata stakeTokenIds,
        uint256 passTokenId
    ) external {
        Pool storage pool = poolInfos[poolId];
        bool userExist;
        for (uint256 i = 0; i < poolAddrs[poolId].length; i++) {
            if (poolAddrs[poolId][i] == msg.sender) {
                userExist = true;
                break;
            }
        }
        if (!userExist) {
            genUser(poolId);
        }

        equipPass(poolId, passTokenId);

        for (uint256 i = 0; i < stakeTokenIds.length; i++) {
            require(
                msg.sender ==
                    IERC721(pool.nftAddress).ownerOf(stakeTokenIds[i]),
                "You dont owner this nft"
            );
            require(
                tokenUsed[poolId][stakeTokenIds[i]] == address(0),
                "stake token id used"
            );
            tokenUsed[poolId][stakeTokenIds[i]] = msg.sender;
        }
        poolUsers[poolId][msg.sender].amount += stakeTokenIds.length;
        IERC20(pool.tokenAddress).transferFrom(
            msg.sender,
            address(this),
            pool.tokenAmount
        );
    }

    function equipPass(uint256 poolId, uint256 passTokenId) public {
        if (passTokenId != 0) {
            require(
                passUsed[poolId][passTokenId] == address(0),
                "pass token id used"
            );
            passUsed[poolId][passTokenId] = msg.sender;
        }
    }

    function unEquipPass(uint256 poolId, uint256 passTokenId) public {
        if (passTokenId != 0) {
            require(
                passUsed[poolId][passTokenId] == msg.sender,
                "pass token id not used by you"
            );
            passUsed[poolId][passTokenId] = address(0);
        }
    }

    function genUser(uint256 poolId) private {
        poolUsers[poolId][msg.sender] = User(block.number, 0, 0);
        poolAddrs[poolId].push(msg.sender);
    }

    function unStake(
        uint256 poolId,
        uint256[] calldata unStakeTokenIds,
        uint256 passTokenId
    ) external {
        Pool storage pool = poolInfos[poolId];
        unEquipPass(poolId, passTokenId);

        for (uint256 i = 0; i < unStakeTokenIds.length; i++) {
            require(
                msg.sender ==
                    IERC721(pool.nftAddress).ownerOf(unStakeTokenIds[i]),
                "You dont owner this nft"
            );
            require(
                tokenUsed[poolId][unStakeTokenIds[i]] == msg.sender,
                "stake token id not used by you"
            );
            tokenUsed[poolId][unStakeTokenIds[i]] = address(0);
        }
        poolUsers[poolId][msg.sender].amount -= unStakeTokenIds.length;
        IERC20(pool.tokenAddress).transfer(msg.sender, pool.tokenAmount);
    }
}
