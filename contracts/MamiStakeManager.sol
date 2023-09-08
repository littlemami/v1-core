pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface RewardsToken {
    function mint(address, uint256) external;
}

interface IMamiStakePool {
    function initParameters(
        address _stakeAddress,
        address _rewardsToken,
        uint256 _rewardsPerBlock,
        address _foundation
    ) external;

    function changeRate(uint256 _rewardsPerBlock) external;

    function changeFoundation(address _foundation) external;
}

contract MamiErc20StakePool is ReentrancyGuard, IMamiStakePool {
    struct User {
        uint256 amount;
        uint256 rewards;
        uint256 last;
    }

    mapping(address => User) public users;

    address[] public userList;

    uint256 public totalStake;

    uint256 public rewardsPerBlock;

    address public stakeErc20Address;

    address public rewardsToken;

    address public foundation;

    address public immutable factory;

    uint256 public startBlock;

    event Stake(address, uint256);

    event UnStake(address, uint256);

    event Claim(address, uint256);

    using SafeERC20 for IERC20;

    modifier onlyFactory() {
        require(factory == msg.sender, "Caller is not the factory");
        _;
    }

    constructor() {
        factory = msg.sender;
    }

    function changeRate(uint256 _rewardsPerBlock) external onlyFactory {
        for (uint256 i = 0; i < userList.length; i++) {
            _flush(userList[i]);
        }
        startBlock = block.number;

        rewardsPerBlock = _rewardsPerBlock;
    }

    function changeFoundation(address _foundation) external onlyFactory {
        foundation = _foundation;
    }

    function initParameters(
        address _stakeErc20Address,
        address _rewardsToken,
        uint256 _rewardsPerBlock,
        address _foundation
    ) external onlyFactory {
        rewardsToken = _rewardsToken;
        stakeErc20Address = _stakeErc20Address;
        rewardsPerBlock = _rewardsPerBlock;
        foundation = _foundation;
        startBlock = block.number;
    }

    function getStakeAmount(address _address) external view returns (uint256) {
        User storage user = users[_address];
        return user.amount;
    }

    function getClaimableRewards(
        address _address
    ) public view returns (uint256) {
        User memory user = users[_address];
        return user.rewards + getNewRewards(_address);
    }

    function pendingRewards() public view returns (uint256) {
        return (block.number - startBlock) * rewardsPerBlock;
    }

    function getNewRewards(address _address) public view returns (uint256) {
        User memory user = users[_address];
        uint256 newRewards = 0;

        if (user.last != 0 && (block.number - startBlock) * totalStake > 0) {
            newRewards =
                (pendingRewards() * (block.number - user.last) * user.amount) /
                ((block.number - startBlock) * totalStake);
        }

        return newRewards;
    }

    function stake(uint256 _amount) external {
        require(_amount > 0, "must select at least one");
        if (users[msg.sender].last == 0) {
            userList.push(msg.sender);
        }
        _flush(msg.sender);

        IERC20(stakeErc20Address).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );
        users[msg.sender].amount += _amount;
        totalStake += _amount;
        emit Stake(msg.sender, _amount);
    }

    function unStake(uint256 _amount) external {
        require(_amount > 0, "must select at least one");
        User storage user = users[msg.sender];
        _flush(msg.sender);
        IERC20(stakeErc20Address).safeTransfer(msg.sender, _amount);
        user.amount -= _amount;
        totalStake -= _amount;
        emit UnStake(msg.sender, _amount);
    }

    function claimAll() public {
        _flush(msg.sender);
        uint256 rewards = users[msg.sender].rewards;
        uint256 fee = rewards / 20;
        RewardsToken(rewardsToken).mint(foundation, fee);
        RewardsToken(rewardsToken).mint(msg.sender, rewards - fee);
        users[msg.sender].rewards = 0;
        emit Claim(msg.sender, rewards - fee);
        emit Claim(foundation, fee);
    }

    function _flush(address _address) private nonReentrant {
        User storage user = users[_address];
        uint256 newRewards = getNewRewards(_address);
        user.rewards += newRewards;
        user.last = block.number;
    }
}

contract MamiErc721StakePool is ReentrancyGuard, IMamiStakePool {
    struct User {
        uint256[] tokenIds;
        uint256 rewards;
        uint256 last;
    }

    mapping(address => User) public users;

    address[] public userList;

    uint256 public totalStake;

    uint256 public rewardsPerBlock;

    address public stakeErc721Address;

    address public rewardsToken;

    address public foundation;

    address public immutable factory;

    uint256 public startBlock;

    event Stake(address, uint256, uint256[]);

    event UnStake(address, uint256, uint256[]);

    event Claim(address, uint256);

    modifier onlyFactory() {
        require(factory == msg.sender, "Caller is not the factory");
        _;
    }

    constructor() {
        factory = msg.sender;
    }

    function changeRate(uint256 _rewardsPerBlock) external onlyFactory {
        for (uint256 i = 0; i < userList.length; i++) {
            _flush(userList[i]);
        }
        startBlock = block.number;
        rewardsPerBlock = _rewardsPerBlock;
    }

    function changeFoundation(address _foundation) external onlyFactory {
        foundation = _foundation;
    }

    function initParameters(
        address _stakeErc721Address,
        address _rewardsToken,
        uint256 _rewardsPerBlock,
        address _foundation
    ) external onlyFactory {
        rewardsToken = _rewardsToken;
        stakeErc721Address = _stakeErc721Address;
        rewardsPerBlock = _rewardsPerBlock;
        foundation = _foundation;
        startBlock = block.number;
    }

    function getUser(address _address) external view returns (User memory) {
        return users[_address];
    }

    function pendingRewards() public view returns (uint256) {
        return (block.number - startBlock) * rewardsPerBlock;
    }

    function getNewRewards(address _address) public view returns (uint256) {
        User memory user = users[_address];
        uint256 newRewards = 0;

        if (user.last != 0 && (block.number - startBlock) * totalStake > 0) {
            newRewards =
                (pendingRewards() *
                    (block.number - user.last) *
                    user.tokenIds.length) /
                ((block.number - startBlock) * totalStake);
        }

        return newRewards;
    }

    function getClaimableRewards(
        address _address
    ) public view returns (uint256) {
        User memory user = users[_address];
        return user.rewards + getNewRewards(_address);
    }

    function getStakeAmount(address _address) external view returns (uint256) {
        User storage user = users[_address];
        return user.tokenIds.length;
    }

    function stake(uint256[] calldata _tokenIds) external {
        require(_tokenIds.length > 0, "must select at least one");
        User storage user = users[msg.sender];
        if (user.last == 0) {
            userList.push(msg.sender);
        }
        _flush(msg.sender);
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            IERC721(stakeErc721Address).transferFrom(
                msg.sender,
                address(this),
                _tokenIds[i]
            );
            user.tokenIds.push(_tokenIds[i]);
        }
        totalStake += _tokenIds.length;
        emit Stake(msg.sender, _tokenIds.length, _tokenIds);
    }

    function unStake(uint256[] calldata _tokenIds) external {
        require(_tokenIds.length > 0, "must select at least one");
        User storage user = users[msg.sender];

        _flush(msg.sender);

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            bool find = false;
            for (uint256 y = 0; y < user.tokenIds.length; y++) {
                if (_tokenIds[i] == user.tokenIds[y]) {
                    IERC721(stakeErc721Address).transferFrom(
                        address(this),
                        msg.sender,
                        _tokenIds[i]
                    );
                    user.tokenIds[y] = user.tokenIds[user.tokenIds.length - 1];

                    user.tokenIds.pop();
                    find = true;
                }
            }
            require(find, "You don't have this tokenId");
        }
        totalStake -= _tokenIds.length;
        emit UnStake(msg.sender, _tokenIds.length, _tokenIds);
    }

    function claimAll() public {
        _flush(msg.sender);
        uint256 rewards = users[msg.sender].rewards;
        uint256 fee = rewards / 20;
        RewardsToken(rewardsToken).mint(foundation, fee);
        RewardsToken(rewardsToken).mint(msg.sender, rewards - fee);
        users[msg.sender].rewards = 0;
        emit Claim(msg.sender, rewards - fee);
        emit Claim(foundation, fee);
    }

    function _flush(address _address) private nonReentrant {
        User storage user = users[_address];

        uint256 newRewards = getNewRewards(_address);

        user.rewards += newRewards;
        user.last = block.number;
    }

    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract MamiStakeManager is Ownable {
    address[] public erc721StakePools;

    address[] public erc20StakePools;

    address public erc721StakeImplement;

    address public erc20StakeImplement;

    using SafeERC20 for IERC20;

    constructor() {
        erc721StakeImplement = address(new MamiErc721StakePool());
        erc20StakeImplement = address(new MamiErc20StakePool());
    }

    function changeRate(
        address _pool,
        uint256 _rewardsPerBlock
    ) public onlyOwner {
        IMamiStakePool(_pool).changeRate(_rewardsPerBlock);
    }

    function changeFoundation(
        address _pool,
        address _foundation
    ) public onlyOwner {
        IMamiStakePool(_pool).changeFoundation(_foundation);
    }

    function createStakePool(
        address _stakeAddress,
        address _rewardsToken,
        uint256 _rewardsPerBlock,
        address _foundation,
        uint256 _type
    ) public onlyOwner {
        address pool;
        if (_type == 0) {
            // type is 0 erc721stake is valid
            pool = Clones.clone(erc721StakeImplement);
            erc721StakePools.push(pool);
        } else if (_type == 1) {
            // type is 1 erc20stake is valid
            pool = Clones.clone(erc20StakeImplement);
            erc20StakePools.push(pool);
        } else {
            revert();
        }

        IMamiStakePool(pool).initParameters(
            _stakeAddress,
            _rewardsToken,
            _rewardsPerBlock,
            _foundation
        );
    }

    function getErc20StakePoolsLength() external view returns (uint256) {
        return erc20StakePools.length;
    }

    function getErc721StakePoolsLength() external view returns (uint256) {
        return erc721StakePools.length;
    }

    function withdrawETH(address payable _to) external onlyOwner {
        (bool success, ) = _to.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    function withdrawERC20(address _erc20, address _to) external onlyOwner {
        IERC20(_erc20).safeTransfer(
            _to,
            IERC20(_erc20).balanceOf(address(this))
        );
    }

    function withdrawERC721(
        address _erc721,
        address _to,
        uint256[] calldata _tokenIds
    ) external onlyOwner {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            IERC721(_erc721).transferFrom(address(this), _to, _tokenIds[i]);
        }
    }

    function withdrawERC1155(
        address _erc1155,
        address _to,
        uint256[] calldata _ids,
        uint256[] calldata _amounts,
        bytes calldata _data
    ) external onlyOwner {
        IERC1155(_erc1155).safeBatchTransferFrom(
            address(this),
            _to,
            _ids,
            _amounts,
            _data
        );
    }
}
