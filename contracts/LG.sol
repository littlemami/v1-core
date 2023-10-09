pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

contract LG is ERC20Burnable, AccessControlEnumerable {
    bytes32 public constant MINT_ROLE = bytes32(uint256(1));

    constructor() ERC20("Littlemami game coin", "LG") {
        _setupRole(AccessControl.DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINT_ROLE, _msgSender());
    }

    function mint(
        address _account,
        uint256 _amount
    ) external onlyRole(MINT_ROLE) {
        _mint(_account, _amount);
    }
}
