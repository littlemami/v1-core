// pragma solidity ^0.8.17;

// import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
// import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
// import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
// import "@openzeppelin/contracts/utils/math/Math.sol";
// import "@openzeppelin/contracts/proxy/Clones.sol";
// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// import "@openzeppelin/contracts/utils/Address.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// contract MamiBase {
//     uint256 public immutable base = 10 ** 18;

//     uint256 public immutable feeBase = 10000;

//     function getRemainAmount(
//         address _address,
//         address _erc721,
//         address _erc20
//     ) public view returns (uint256 erc721Amount, uint256 erc20Amount) {
//         erc721Amount = IERC721(_erc721).balanceOf(_address) * base;
//         erc20Amount = IERC20(_erc20).balanceOf(_address);
//     }

//     function pairFor(
//         address implementation,
//         address _erc721,
//         address _erc20,
//         address factory
//     ) public pure returns (address) {
//         bytes32 salt = keccak256(abi.encodePacked(_erc721, _erc20));
//         return
//             Clones.predictDeterministicAddress(implementation, salt, factory);
//     }

//     function getAmountsRemoveLiquidity(
//         uint256 _burnSupply,
//         uint256 _totalSupply,
//         uint256 _erc721Amount,
//         uint256 _erc20Amount
//     )
//         public
//         pure
//         returns (uint256 removeERC721Amount, uint256 removeERC20Amount)
//     {
//         removeERC721Amount = (_burnSupply * _erc721Amount) / _totalSupply;
//         removeERC20Amount = (_burnSupply * _erc20Amount) / _totalSupply;
//         if (removeERC721Amount % base > 0) {
//             removeERC20Amount =
//                 _erc20Amount -
//                 ((_erc721Amount - removeERC721Amount) *
//                     (_erc20Amount - removeERC20Amount)) /
//                 (_erc721Amount - (removeERC721Amount / base) * base);
//         }
//         removeERC721Amount = (removeERC721Amount / base) * base;
//     }
// }

// contract IWETH {
//     string public name = "Wrapped Ether";
//     string public symbol = "WETH";
//     uint8 public decimals = 18;

//     event Approval(address indexed src, address indexed guy, uint wad);
//     event Transfer(address indexed src, address indexed dst, uint wad);
//     event Deposit(address indexed dst, uint wad);
//     event Withdrawal(address indexed src, uint wad);

//     mapping(address => uint) public balanceOf;
//     mapping(address => mapping(address => uint)) public allowance;

//     function deposit() public payable {
//         balanceOf[msg.sender] += msg.value;
//         emit Deposit(msg.sender, msg.value);
//     }

//     function withdraw(uint wad) public {
//         require(balanceOf[msg.sender] >= wad);
//         balanceOf[msg.sender] -= wad;
//         payable(msg.sender).transfer(wad);
//         emit Withdrawal(msg.sender, wad);
//     }

//     function totalSupply() public view returns (uint) {
//         return address(this).balance;
//     }

//     function approve(address guy, uint wad) public returns (bool) {
//         allowance[msg.sender][guy] = wad;
//         emit Approval(msg.sender, guy, wad);
//         return true;
//     }

//     function transfer(address dst, uint wad) public returns (bool) {
//         return transferFrom(msg.sender, dst, wad);
//     }

//     function transferFrom(
//         address src,
//         address dst,
//         uint wad
//     ) public returns (bool) {
//         require(balanceOf[src] >= wad);

//         if (src != msg.sender) {
//             require(allowance[src][msg.sender] >= wad);
//             allowance[src][msg.sender] -= wad;
//         }

//         balanceOf[src] -= wad;
//         balanceOf[dst] += wad;

//         emit Transfer(src, dst, wad);

//         return true;
//     }
// }

// interface IMamiFactory {
//     function fee() external view returns (uint256);

//     function feeRecept() external view returns (address);
// }

// contract MamiPair is ERC20Burnable, ReentrancyGuard, MamiBase {
//     address public erc721;

//     address public erc20;

//     address public immutable factory;

//     uint256 private lastERC721Amount;

//     uint256 private lastERC20Amount;

//     using SafeERC20 for IERC20;

//     using Math for uint256;

//     modifier onlyFactory() {
//         require(factory == msg.sender, "Caller is not the factory");
//         _;
//     }

//     constructor() ERC20("", "") {
//         factory = msg.sender;
//     }

//     /**
//      * @dev Returns the name of the token.
//      */
//     function name() public view virtual override returns (string memory) {
//         return "Mami Liquidity Token";
//     }

//     /**
//      * @dev Returns the symbol of the token, usually a shorter version of the
//      * name.
//      */
//     function symbol() public view virtual override returns (string memory) {
//         return "Mami Liquidity Token";
//     }

//     function initialize(address _erc721, address _erc20) external onlyFactory {
//         erc721 = _erc721;
//         erc20 = _erc20;
//     }

//     function getPairRemainAmount()
//         public
//         view
//         returns (uint256 erc721Amount, uint256 erc20Amount)
//     {
//         return getRemainAmount(address(this), erc721, erc20);
//     }

//     function swap(
//         uint256 _erc20AmountOut,
//         uint256[] calldata _erc721TokenIdsOut,
//         address _to
//     ) external nonReentrant {
//         require(
//             _erc20AmountOut > 0 || _erc721TokenIdsOut.length > 0,
//             "Mami : Out must greater than zero."
//         );
//         if (_erc20AmountOut > 0) {
//             IERC20(erc20).safeTransfer(_to, _erc20AmountOut);
//         }
//         if (_erc721TokenIdsOut.length > 0) {
//             for (uint256 i = 0; i < _erc721TokenIdsOut.length; i++) {
//                 IERC721(erc721).transferFrom(
//                     address(this),
//                     _to,
//                     _erc721TokenIdsOut[i]
//                 );
//             }
//         }

//         (uint256 erc721Amount, uint256 erc20Amount) = getPairRemainAmount();

//         uint256 feeAmount = 0;
//         uint256 fee = IMamiFactory(factory).fee();
//         if (erc20Amount > lastERC20Amount) {
//             feeAmount = ((erc20Amount - lastERC20Amount) * fee);
//         } else {
//             feeAmount = ((lastERC20Amount - erc20Amount) * fee);
//         }

//         require(
//             erc721Amount * (feeBase * erc20Amount - feeAmount) >=
//                 feeBase * lastERC721Amount * lastERC20Amount,
//             "K"
//         );

//         address feeRecept = IMamiFactory(factory).feeRecept();
//         if (feeRecept != address(0)) {
//             feeAmount = feeAmount / feeBase;
//             IERC20(erc20).safeTransfer(_to, feeAmount);
//             erc20Amount = erc20Amount - feeAmount;
//         }

//         _sync(erc721Amount, erc20Amount);
//     }

//     function mint(address _to) external nonReentrant {
//         (uint256 erc721Amount, uint256 erc20Amount) = getPairRemainAmount();
//         uint256 liquidity = 0;
//         uint256 totalSupply = totalSupply();
//         if (totalSupply == 0) {
//             liquidity = (erc721Amount * erc20Amount).sqrt();
//         } else {
//             uint256 erc721AddAmount = erc721Amount - lastERC721Amount;
//             uint256 erc20AddAmount = erc20Amount - lastERC20Amount;
//             liquidity = Math.min(
//                 (erc721AddAmount * totalSupply) / erc721Amount,
//                 (erc20AddAmount * totalSupply) / erc20Amount
//             );
//         }
//         require(
//             liquidity > 0,
//             "Mami : Mint pair token must greater than zero."
//         );
//         _mint(_to, liquidity);
//         _sync(erc721Amount, erc20Amount);
//     }

//     function burn(
//         address _to,
//         uint256[] calldata _maxErc721TokenIdsOut
//     ) external nonReentrant returns (uint256, uint256) {
//         (uint256 erc721Amount, uint256 erc20Amount) = getPairRemainAmount();
//         uint256 burnSupply = balanceOf(address(this));

//         if (burnSupply > 0) {
//             (
//                 uint256 removeErc721Amount,
//                 uint256 removeErc20Amount
//             ) = getAmountsRemoveLiquidity(
//                     burnSupply,
//                     totalSupply(),
//                     erc721Amount,
//                     erc20Amount
//                 );
//             _burn(address(this), burnSupply);
//             require(_maxErc721TokenIdsOut.length >= removeErc721Amount / base);
//             for (uint256 i = 0; i < removeErc721Amount / base; i++) {
//                 IERC721(erc721).transferFrom(
//                     address(this),
//                     _to,
//                     _maxErc721TokenIdsOut[i]
//                 );
//             }

//             IERC20(erc20).safeTransfer(_to, removeErc20Amount);
//             _sync(
//                 erc721Amount - removeErc721Amount,
//                 erc20Amount - removeErc20Amount
//             );
//             return (removeErc721Amount, removeErc20Amount);
//         } else {
//             return (0, 0);
//         }
//     }

//     function sync() external {
//         (uint256 erc721Amount, uint256 erc20Amount) = getPairRemainAmount();
//         _sync(erc721Amount, erc20Amount);
//     }

//     function _sync(
//         uint256 _erc721Amount,
//         uint256 _erc20Amount
//     ) private nonReentrant {
//         lastERC721Amount = _erc721Amount;
//         lastERC20Amount = _erc20Amount;
//     }

//     /**
//      * @dev See {IERC721Receiver-onERC721Received}.
//      */
//     function onERC721Received(
//         address,
//         address,
//         uint256,
//         bytes calldata
//     ) external pure returns (bytes4) {
//         return IERC721Receiver.onERC721Received.selector;
//     }
// }

// contract MamiFactory is Ownable, IMamiFactory {
//     address public implementation;

//     uint256 public totalPair;

//     uint256 public fee;

//     address public feeRecept;

//     mapping(address => address[]) public ownerPairs;

//     event CreatePair(
//         address indexed _erc721,
//         address indexed _erc20,
//         address indexed _pair,
//         uint256
//     );

//     constructor() public {
//         implementation = address(new MamiPair());
//         fee = 30;
//     }

//     function setFeeRecept(address _feeRecept) external onlyOwner {
//         feeRecept = _feeRecept;
//     }

//     function setFee(uint256 _fee) external onlyOwner {
//         fee = _fee;
//     }

//     function getOwnerPairsLength(
//         address _owner
//     ) external view returns (uint256) {
//         return ownerPairs[_owner].length;
//     }

//     function addOwnerPairs(address _owner, address _pair) external {
//         ownerPairs[_owner].push(_pair);
//     }

//     function createPair(
//         address _erc721,
//         address _erc20
//     ) external returns (address) {
//         bytes32 salt = keccak256(abi.encodePacked(_erc721, _erc20));
//         address pair = Clones.cloneDeterministic(implementation, salt);
//         MamiPair(pair).initialize(_erc721, _erc20);
//         emit CreatePair(_erc721, _erc20, pair, totalPair++);
//         return pair;
//     }
// }

// contract MamiRouter is MamiBase {
//     using SafeERC20 for IERC20;

//     address public factory;

//     address public implementation;

//     address public weth;

//     using Address for address;

//     constructor() {
//         factory = address(new MamiFactory());
//         implementation = MamiFactory(factory).implementation();
//         MamiFactory(factory).setFeeRecept(msg.sender);
//         MamiFactory(factory).transferOwnership(msg.sender);
//         weth = address(new IWETH());
//     }

//     receive() external payable {
//         require(msg.sender == weth); // only accept ETH via fallback from the WETH contract
//     }

//     /**
//      * @dev See {IERC721Receiver-onERC721Received}.
//      */
//     function onERC721Received(
//         address,
//         address,
//         uint256,
//         bytes calldata
//     ) external pure returns (bytes4) {
//         return IERC721Receiver.onERC721Received.selector;
//     }

//     function getAmountOut(
//         uint256 _remain0,
//         uint256 _remain1,
//         uint256 _inAmount0
//     ) public view returns (uint256) {
//         uint256 fee = IMamiFactory(factory).fee();
//         return
//             ((_remain1 * _inAmount0) * (feeBase - fee)) /
//             (_remain0 + _inAmount0) /
//             feeBase;
//     }

//     function getAmountIn(
//         uint256 _remain0,
//         uint256 _remain1,
//         uint256 _outAmount0
//     ) public view returns (uint256) {
//         uint256 fee = IMamiFactory(factory).fee();
//         return
//             1 +
//             (_outAmount0 * _remain1 * feeBase) /
//             (_remain0 - _outAmount0) /
//             (feeBase - fee);
//     }

//     function pairFor(
//         address _erc721,
//         address _erc20
//     ) public view returns (address) {
//         return pairFor(implementation, _erc721, _erc20, factory);
//     }

//     function getPairRemainAmount(
//         address _erc721,
//         address _erc20
//     ) external view returns (uint256 erc721Amount, uint256 erc20Amount) {
//         address pair = pairFor(_erc721, _erc20);
//         return getRemainAmount(pair, _erc721, _erc20);
//     }

//     function getPairBalanceOf(
//         address _erc721,
//         address _erc20,
//         address _owner
//     ) external view returns (uint256) {
//         address pair = pairFor(_erc721, _erc20);
//         return MamiPair(pair).balanceOf(_owner);
//     }

//     function getPairTotalSupply(
//         address _erc721,
//         address _erc20
//     ) external view returns (uint256) {
//         address pair = pairFor(_erc721, _erc20);
//         return MamiPair(pair).totalSupply();
//     }

//     function addLiquidity(
//         address _erc721,
//         address _erc20,
//         uint256 _erc20In,
//         uint256[] calldata _erc721TokenIdsIn,
//         address _to
//     ) external {
//         address pair = pairFor(_erc721, _erc20);
//         if (!pair.isContract()) {
//             MamiFactory(factory).createPair(_erc721, _erc20);
//         }
//         IERC20(_erc20).safeTransferFrom(msg.sender, pair, _erc20In);
//         for (uint256 i = 0; i < _erc721TokenIdsIn.length; i++) {
//             IERC721(_erc721).transferFrom(
//                 msg.sender,
//                 pair,
//                 _erc721TokenIdsIn[i]
//             );
//         }
//         MamiPair(pair).mint(_to);
//         MamiFactory(factory).addOwnerPairs(msg.sender, pair);
//     }

//     function addLiquidityETH(
//         address _erc721,
//         uint256[] calldata _erc721TokenIdsIn,
//         address _to
//     ) external payable {
//         address pair = pairFor(_erc721, weth);
//         if (!pair.isContract()) {
//             MamiFactory(factory).createPair(_erc721, weth);
//         }
//         uint256 erc20In = msg.value;
//         IWETH(weth).deposit{value: erc20In}();
//         IWETH(weth).transfer(pair, erc20In);
//         for (uint256 i = 0; i < _erc721TokenIdsIn.length; i++) {
//             IERC721(_erc721).transferFrom(
//                 msg.sender,
//                 pair,
//                 _erc721TokenIdsIn[i]
//             );
//         }
//         MamiPair(pair).mint(_to);
//         MamiFactory(factory).addOwnerPairs(msg.sender, pair);
//     }

//     function removeLiquidity(
//         address _erc721,
//         address _erc20,
//         uint256 _liquidity,
//         uint256[] calldata _maxErc721TokenIdsOut,
//         address _to
//     ) public returns (uint256 removeErc721Amount, uint256 removeErc20Amount) {
//         address pair = pairFor(_erc721, _erc20);
//         require(pair.isContract(), "Mami : Pair has not been created yet.");
//         MamiPair(pair).transferFrom(msg.sender, pair, _liquidity);
//         return MamiPair(pair).burn(_to, _maxErc721TokenIdsOut);
//     }

//     function removeLiquidityETH(
//         address _erc721,
//         uint256 _liquidity,
//         uint256[] calldata _maxErc721TokenIdsOut,
//         address _to
//     ) external {
//         (
//             uint256 removeErc721Amount,
//             uint256 removeErc20Amount
//         ) = removeLiquidity(
//                 _erc721,
//                 weth,
//                 _liquidity,
//                 _maxErc721TokenIdsOut,
//                 address(this)
//             );
//         IWETH(weth).withdraw(removeErc20Amount);
//         (bool success, ) = _to.call{value: removeErc20Amount}("");
//         require(success, "Transfer failed.");
//         for (uint256 i = 0; i < removeErc721Amount / base; i++) {
//             IERC721(_erc721).transferFrom(
//                 address(this),
//                 _to,
//                 _maxErc721TokenIdsOut[i]
//             );
//         }
//     }

//     function swapERC20ForExactERC721(
//         address _erc721,
//         address _erc20,
//         uint256[] calldata _erc721TokenIdsOut,
//         uint256 _maxErc20In,
//         address _to
//     ) external {
//         address pair = pairFor(_erc721, _erc20);
//         require(pair.isContract(), "Mami : Pair has not been created yet.");
//         require(
//             _erc721TokenIdsOut.length > 0,
//             "Mami : The outflow quantity of erc721 must greater than zero."
//         );
//         (uint256 erc721Amount, uint256 erc20Amount) = getRemainAmount(
//             pair,
//             _erc721,
//             _erc20
//         );
//         uint256 erc20In = getAmountIn(
//             erc721Amount,
//             erc20Amount,
//             _erc721TokenIdsOut.length * base
//         );
//         require(
//             erc20In <= _maxErc20In,
//             "Mami : The inflow quantity of erc20 is greater than the maxErc20In."
//         );
//         IERC20(_erc20).safeTransferFrom(msg.sender, pair, erc20In);
//         MamiPair(pair).swap(0, _erc721TokenIdsOut, _to);
//     }

//     function swapExactERC721ForERC20(
//         address _erc721,
//         address _erc20,
//         uint256[] calldata _erc721TokenIdsIn,
//         uint256 _minErc20Out,
//         address _to
//     ) external {
//         address pair = pairFor(_erc721, _erc20);
//         require(pair.isContract(), "Mami : Pair has not been created yet.");
//         require(
//             _erc721TokenIdsIn.length > 0,
//             "Mami : The inflow quantity of erc721 must greater than zero."
//         );
//         (uint256 erc721Amount, uint256 erc20Amount) = getRemainAmount(
//             pair,
//             _erc721,
//             _erc20
//         );
//         uint256 erc20Out = getAmountOut(
//             erc721Amount,
//             erc20Amount,
//             _erc721TokenIdsIn.length * base
//         );
//         require(
//             _minErc20Out <= erc20Out,
//             "Mami : The outflow of erc20 is less than the minErc20Out."
//         );

//         for (uint256 i = 0; i < _erc721TokenIdsIn.length; i++) {
//             IERC721(_erc721).transferFrom(
//                 msg.sender,
//                 pair,
//                 _erc721TokenIdsIn[i]
//             );
//         }

//         MamiPair(pair).swap(erc20Out, new uint256[](0), _to);
//     }

//     function swapETHForExactERC721(
//         address _erc721,
//         uint256[] calldata _erc721TokenIdsOut,
//         address _to
//     ) external payable {
//         address pair = pairFor(_erc721, weth);
//         require(pair.isContract(), "Mami : Pair has not been created yet.");
//         require(
//             _erc721TokenIdsOut.length > 0,
//             "Mami : The outflow quantity of erc721 must greater than zero."
//         );
//         (uint256 erc721Amount, uint256 erc20Amount) = getRemainAmount(
//             pair,
//             _erc721,
//             weth
//         );
//         uint256 erc20In = getAmountIn(
//             erc721Amount,
//             erc20Amount,
//             _erc721TokenIdsOut.length * base
//         );
//         require(
//             erc20In <= msg.value,
//             "Mami : The inflow quantity of erc20 is greater than the maxErc20In."
//         );
//         IWETH(weth).deposit{value: erc20In}();
//         IWETH(weth).transfer(pair, erc20In);
//         if (msg.value > erc20In) {
//             (bool success, ) = msg.sender.call{value: msg.value - erc20In}("");
//             require(success, "Transfer failed.");
//         }
//         MamiPair(pair).swap(0, _erc721TokenIdsOut, _to);
//     }

//     function swapExactERC721ForETH(
//         address _erc721,
//         uint256[] calldata _erc721TokenIdsIn,
//         uint256 _minErc20Out,
//         address payable _to
//     ) external {
//         address pair = pairFor(_erc721, weth);
//         require(pair.isContract(), "Mami : Pair has not been created yet.");
//         require(
//             _erc721TokenIdsIn.length > 0,
//             "Mami : The inflow quantity of erc721 must greater than zero."
//         );
//         (uint256 erc721Amount, uint256 erc20Amount) = getRemainAmount(
//             pair,
//             _erc721,
//             weth
//         );
//         uint256 erc20Out = getAmountOut(
//             erc721Amount,
//             erc20Amount,
//             _erc721TokenIdsIn.length * base
//         );
//         require(
//             _minErc20Out <= erc20Out,
//             "Mami : The outflow of erc20 is less than the minErc20Out."
//         );

//         for (uint256 i = 0; i < _erc721TokenIdsIn.length; i++) {
//             IERC721(_erc721).transferFrom(
//                 msg.sender,
//                 pair,
//                 _erc721TokenIdsIn[i]
//             );
//         }

//         MamiPair(pair).swap(erc20Out, new uint256[](0), address(this));
//         IWETH(weth).withdraw(erc20Out);
//         (bool success, ) = _to.call{value: erc20Out}("");
//         require(success, "Transfer failed.");
//     }
// }
