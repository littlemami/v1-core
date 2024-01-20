pragma solidity 0.8.22;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Common721, ERC721A} from "./Common721.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract S is ERC20 {
    constructor(address account, uint256 amount) ERC20("USDT", "USDT") {
        _mint(account, amount);
    }
}

interface RewardsToken {
    function mint(address, uint256) external;
}

contract Node is Common721 {
    using Math for uint256;

    using SafeERC20 for IERC20Metadata;

    uint256 public maxSell;

    uint256 public totalSell;

    uint256 public tokenPrice;

    address public tokenAddress;

    uint256 public grow;

    uint256 public growDivBy;

    address public preSigner;

    bytes32 public claimRoot;

    address public lmc;

    uint256 public phase;

    address public fundation;

    mapping(uint256 => uint256) public phaseBlockNumber;

    mapping(address => uint256) public preBuyers;

    mapping(address => uint256) public holders;

    mapping(address => uint256) public claimedNFT;

    mapping(address => uint256) public claimedLMC;

    event Buy(
        address indexed buyer,
        uint256 num,
        uint256 totalTokenNeed,
        address indexed tokenAddress
    );

    constructor() ERC721A("Littlemami Node", "LMN") {
        fundation = 0xB03167F37319F2C67Dd3062fc1482044205484d1;
        tokenAddress = 0xE3260C48D8ff9DB109CeC43f4b2Be1A1F3f74CFc;
        tokenPrice = 300 * 10 ** IERC20Metadata(tokenAddress).decimals();

        maxSell = 30000;
        grow = 1005;
        growDivBy = 1000;
        preSigner = address(0xB59Ad0d1156833531852a0537Eefc25795d73333);
        phase = 1;
        phaseBlockNumber[1] = block.number;
    }

    function preBuy(
        bytes calldata signature,
        uint256 maxNum,
        uint256 num
    ) external {
        require(phase == 1, "Node : Not pre open");
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, maxNum));
        bytes32 hash = MessageHashUtils.toEthSignedMessageHash(leaf);

        require(
            SignatureChecker.isValidSignatureNow(preSigner, hash, signature),
            "Node : Invalid signature"
        );

        require(
            preBuyers[msg.sender] + num <= maxNum,
            "Node : Out of pre max num"
        );
        _buy(num);
        preBuyers[msg.sender] += num;
    }

    function buy(uint256 num) external {
        require(phase != 1, "Node : Not open");
        _buy(num);
    }

    function adminBuy(address[] calldata addrs) external onlyOwner {
        for (uint256 i = 0; i < addrs.length; i++) {
            address recev = addrs[i];
            totalSell++;
            holders[recev]++;
            _setPrice();
            emit Buy(recev, 1, 0, tokenAddress);
        }
    }

    function _buy(uint256 num) private nonReentrant {
        require(totalSell + num <= maxSell, "Node : Out of max sell");
        uint256 totalTokenNeed;
        for (uint256 i = 0; i < num; i++) {
            totalTokenNeed += tokenPrice;
            totalSell++;
            _setPrice();
        }
        IERC20Metadata(tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            totalTokenNeed
        );

        holders[msg.sender] += num;

        emit Buy(
            msg.sender,
            num,
            totalTokenNeed / 10 ** IERC20Metadata(tokenAddress).decimals(),
            tokenAddress
        );
    }

    function claimNFT(uint256 num) external {
        require(maxSell == totalSell, "Node : Not end");
        require(
            claimedNFT[msg.sender] + num <= holders[msg.sender],
            "Node : Out of claim"
        );
        claimedNFT[msg.sender] += num;
        _mint(msg.sender, num);
    }

    function _setPrice() private {
        if (totalSell % 50 == 0) {
            uint256 tokenDecimals = IERC20Metadata(tokenAddress).decimals();
            tokenPrice = ((tokenPrice * grow) / growDivBy).ceilDiv(
                10 ** tokenDecimals
            );
            tokenPrice = tokenPrice * 10 ** tokenDecimals;
        }
        if (totalSell >= 3000 && phase == 2) {
            changePhase(3);
        }
    }

    function setToken(address token, uint256 price) external onlyOwner {
        tokenAddress = token;
        tokenPrice = price;
    }

    function endPrePhase() external onlyOwner {
        require(phase == 1, "Node : Not pre open");
        changePhase(2);
    }

    function changePhase(uint256 change) private {
        phase = change;
        phaseBlockNumber[change] = block.number;
    }

    function setPreRoot(address signer) external onlyOwner {
        preSigner = signer;
    }

    function setClaimRoot(bytes32 root) external onlyOwner {
        claimRoot = root;
    }

    function claimLMC(uint256 max, bytes32[] calldata proof) external {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, max));
        require(
            MerkleProof.verify(proof, claimRoot, leaf),
            "Node : Invalid proof"
        );

        uint256 claimAmt = max - claimedLMC[msg.sender];

        uint256 fee = (claimAmt * 5) / 100;

        claimAmt -= fee;

        RewardsToken(lmc).mint(msg.sender, fee);

        RewardsToken(lmc).mint(msg.sender, claimAmt);
    }
}
