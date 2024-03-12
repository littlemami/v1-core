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
        address rewardsTokenAddress;
        uint256 stakedAmount;
        bool passRequired;
        uint256[] sharePoolIds;
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
        address tokenAddress = 0x5195b2709770180903b7aCB3841B081Ec7b6DfFf;
        address nftAddress = 0xd3427F2F46cCa277FFBe068fc0a1B417750AcC33;
        passAddress = IERC721(0x12c771b96080f243B3e3E0D9643F38FBEb029E24);

        uint256[] memory sharePoolIds0 = new uint256[](1);
        sharePoolIds0[0] = 1;
        uint256[] memory sharePoolIds1 = new uint256[](1);
        sharePoolIds1[0] = 0;

        setPool(
            0,
            nftAddress,
            tokenAddress,
            40000 ether,
            block.number,
            8.8 ether,
            tokenAddress,
            false,
            sharePoolIds0
        );

        setPool(
            1,
            nftAddress,
            tokenAddress,
            40000 ether,
            block.number,
            10 ether,
            tokenAddress,
            true,
            sharePoolIds1
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
            for (uint256 y = 0; y < pool.sharePoolIds.length; y++) {
                require(
                    tokenUsed[pool.sharePoolIds[y]][stakeTokenIds[i]] ==
                        address(0),
                    "The nft already staked"
                );
            }
            tokenUsed[poolId][stakeTokenIds[i]] = msg.sender;
        }
        if (pool.passRequired && poolUsers[poolId][msg.sender].amount == 0) {
            _equipPass(poolId, passTokenId);
        }
        poolUsers[poolId][msg.sender].amount += stakeTokenIds.length;
        pool.stakedAmount += stakeTokenIds.length;

        IERC20(pool.tokenAddress).transferFrom(
            msg.sender,
            address(this),
            pool.tokenAmount * stakeTokenIds.length
        );
    }

    function _equipPass(uint256 poolId, uint256 passTokenId) private {
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

    function _unEquipPass(uint256 poolId) private {
        _sync(poolId);
        User storage user = poolUsers[poolId][msg.sender];
        uint256 passTokenId = user.passTokenId;

        passUsed[poolId][passTokenId] = address(0);

        user.passTokenId = 0;
    }

    function genUser(uint256 poolId) private {
        poolUsers[poolId][msg.sender] = User(block.number, 0, 0, 0);
        poolAddrs[poolId].push(msg.sender);
    }

    function unStake(
        uint256 poolId,
        uint256[] calldata unStakeTokenIds
    ) external checkPool(poolId) {
        Pool storage pool = poolInfos[poolId];

        claim(poolId);

        for (uint256 i = 0; i < unStakeTokenIds.length; i++) {
            require(
                tokenUsed[poolId][unStakeTokenIds[i]] == msg.sender,
                "Stake token id not used by you"
            );
            tokenUsed[poolId][unStakeTokenIds[i]] = address(0);
        }

        poolUsers[poolId][msg.sender].amount -= unStakeTokenIds.length;
        pool.stakedAmount -= unStakeTokenIds.length;
        IERC20(pool.tokenAddress).transfer(
            msg.sender,
            pool.tokenAmount * unStakeTokenIds.length
        );

        if (pool.passRequired && poolUsers[poolId][msg.sender].amount == 0) {
            _unEquipPass(poolId);
        }
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
        address rewardsTokenAddress,
        bool passRequired,
        uint256[] memory sharePoolIds
    ) public onlyOwner {
        poolInfos[poolId] = Pool(
            nftAddress,
            tokenAddress,
            tokenAmount,
            start,
            rate,
            rewardsTokenAddress,
            0,
            passRequired,
            sharePoolIds
        );
    }

    modifier checkPool(uint256 poolId) {
        Pool memory pool = poolInfos[poolId];
        require(pool.tokenAddress != address(0), "Pool not exist");
        require(pool.start <= block.number, "Pool not start");
        _;
    }

    function _sync(uint256 poolId) private {
        uint256 pendingRemain = getPendingRemain(poolId, msg.sender);
        User storage user = poolUsers[poolId][msg.sender];
        user.remain += pendingRemain;
        user.last = block.number;
    }

    function getPendingRemain(
        uint256 poolId,
        address account
    ) public view returns (uint256) {
        uint256 pendingRemain = 0;
        Pool memory pool = poolInfos[poolId];
        if (pool.stakedAmount > 0) {
            User memory user = poolUsers[poolId][account];
            uint256 last = pool.start > user.last ? pool.start : user.last;

            pendingRemain =
                ((block.number - last) * user.amount * pool.rate) /
                pool.stakedAmount;
        }
        return pendingRemain;
    }

    function getSharedTokenIds(
        uint256 poolId
    ) public view returns (uint256[] memory) {
        return poolInfos[poolId].sharePoolIds;
    }
}
