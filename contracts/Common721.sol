pragma solidity 0.8.22;

import {ERC721AQueryable, ERC721A, IERC721A} from "erc721a/contracts/extensions/ERC721AQueryable.sol";
import {Common} from "./Common.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

abstract contract Common721 is ERC721AQueryable, Common {
    uint256 public maxSupply;

    string public defaultURI;

    string public baseURI;

    mapping(uint256 => bool) public blackList;

    using Strings for uint256;

    function adminMint(address _address, uint256 _num) external onlyOwner {
        require(totalSupply() + _num <= maxSupply, "Must lower than maxSupply");
        _mint(_address, _num);
    }

    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual override {
        for (uint256 i = startTokenId; i < startTokenId + quantity; i++) {
            require(!blackList[i], "In blacklist");
        }
    }

    function setBlackList(
        uint256[] calldata _blackList,
        bool _status
    ) external onlyOwner {
        for (uint256 i = 0; i < _blackList.length; i++) {
            blackList[_blackList[i]] = _status;
        }
    }

    function setBaseURI(string memory _baseURI) public onlyOwner {
        baseURI = _baseURI;
    }

    function setDefaultURI(string memory _defaultURI) public onlyOwner {
        defaultURI = _defaultURI;
    }

    function tokenURI(
        uint256 _tokenId
    ) public view override(ERC721A, IERC721A) returns (string memory) {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory imageURI = bytes(baseURI).length > 0
            ? string(abi.encodePacked(baseURI, _tokenId.toString()))
            : defaultURI;

        return imageURI;
    }
}
