pragma solidity ^0.8.22;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface RewardsToken {
    function mint(address, uint256) external;
}

contract MamiStakeV3 is Ownable, ReentrancyGuard {
    struct Pool {
        address nftAddress;
        address tokenAddress;
        uint256 tokenAmount;
        uint256 start;
        uint256 rate;
        uint256 passRate;
        address rewardsTokenAddress;
        uint256 stakedAmount;
    }

    struct User {
        uint256 last;
        uint256 amount;
        uint256 remain;
        uint256 passTokenId;
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

    IERC721 public passAddress;

    constructor() Ownable(msg.sender) {
        //test
        address tokenAddress = 0x42A282eCea54dF092d32D1937e9B83C769DDF1c6;
        address nftAddress = 0x7023ba9cFA134E5c781a9278Fc7486467B221D5E;
        passAddress = IERC721(0x7023ba9cFA134E5c781a9278Fc7486467B221D5E);
        setPool(
            0,
            nftAddress,
            tokenAddress,
            40000 ether,
            block.number,
            10 ether,
            8.8 ether,
            tokenAddress
        );
    }

    function stake(
        uint256 poolId,
        uint256[] calldata stakeTokenIds,
        uint256 passTokenId
    ) external checkPool(poolId) {
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
                "Stake token id used"
            );
            tokenUsed[poolId][stakeTokenIds[i]] = msg.sender;
        }
        poolUsers[poolId][msg.sender].amount += stakeTokenIds.length;
        pool.stakedAmount += stakeTokenIds.length;

        IERC20(pool.tokenAddress).transferFrom(
            msg.sender,
            address(this),
            pool.tokenAmount
        );
    }

    function equipPass(uint256 poolId, uint256 passTokenId) public {
        if (passTokenId != 0) {
            _sync(poolId);
            require(
                IERC721(passAddress).ownerOf(passTokenId) == msg.sender,
                "You dont owner this pass"
            );
            require(
                passUsed[poolId][passTokenId] == address(0),
                "Pass token id used"
            );
            passUsed[poolId][passTokenId] = msg.sender;
            User storage user = poolUsers[poolId][msg.sender];
            user.passTokenId = passTokenId;
        }
    }

    function unEquipPass(uint256 poolId, uint256 passTokenId) public {
        if (passTokenId != 0) {
            _sync(poolId);
            require(
                passUsed[poolId][passTokenId] == msg.sender,
                "Pass token id not used by you"
            );
            passUsed[poolId][passTokenId] = address(0);
            User storage user = poolUsers[poolId][msg.sender];
            user.passTokenId = 0;
        }
    }

    function genUser(uint256 poolId) private {
        poolUsers[poolId][msg.sender] = User(block.number, 0, 0, 0);
        poolAddrs[poolId].push(msg.sender);
    }

    function unStake(
        uint256 poolId,
        uint256[] calldata unStakeTokenIds,
        uint256 passTokenId
    ) external checkPool(poolId) {
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
                "Stake token id not used by you"
            );
            tokenUsed[poolId][unStakeTokenIds[i]] = address(0);
        }
        poolUsers[poolId][msg.sender].amount -= unStakeTokenIds.length;
        pool.stakedAmount -= unStakeTokenIds.length;
        IERC20(pool.tokenAddress).transfer(msg.sender, pool.tokenAmount);
    }

    function claim(uint256 poolId) public checkPool(poolId) {
        _sync(poolId);
        Pool memory pool = poolInfos[poolId];
        User storage user = poolUsers[poolId][msg.sender];
        RewardsToken(pool.rewardsTokenAddress).mint(msg.sender, user.remain);
        user.remain = 0;
    }

    function setPool(
        uint256 poolId,
        address nftAddress,
        address tokenAddress,
        uint256 tokenAmount,
        uint256 start,
        uint256 rate,
        uint256 passRate,
        address rewardsTokenAddress
    ) public onlyOwner {
        poolInfos[poolId] = Pool(
            nftAddress,
            tokenAddress,
            tokenAmount,
            start,
            rate,
            passRate,
            rewardsTokenAddress,
            0
        );
    }

    modifier checkPool(uint256 poolId) {
        Pool memory pool = poolInfos[poolId];
        require(pool.tokenAddress != address(0), "Pool not exist");
        require(pool.start <= block.number, "Pool not start");
        _;
    }

    function _sync(uint256 poolId) private {
        Pool memory pool = poolInfos[poolId];
        User storage user = poolUsers[poolId][msg.sender];
        uint256 last = pool.start > user.last ? pool.start : user.last;
        uint256 rate = user.passTokenId > 0 ? pool.passRate : pool.rate;
        uint256 remain = ((block.number - last) * user.amount * rate) /
            pool.stakedAmount;

        user.remain += remain;
        user.last = block.number;
    }
}
