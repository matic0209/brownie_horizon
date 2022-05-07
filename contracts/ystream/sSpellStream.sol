pragma solidity >=0.4.21 <0.6.0;
import "../erc20/IERC20.sol";
import "../utils/SafeMath.sol";

import "./IYieldStream.sol";


contract sSpellInterface is IERC20{
  IERC20 public token;
}

contract sSpellStream is IYieldStream{
  using SafeMath for uint256;
  sSpellInterface public sSpell;

  constructor() public{
    name = "sSpell yield stream";
    sSpell = sSpellInterface(address(0x26FA3fFFB6EfE8c1E69103aCb4044C26B9A106a9));
  }


  function target_token() public view returns(address){
    return address(sSpell);
  }

  function getVirtualPrice() public view returns(uint256){
    if(sSpell.totalSupply() == 0){
      return 0;
    }

    return sSpell.token().balanceOf(address(sSpell)).safeMul(1e18).safeDiv(sSpell.totalSupply());
  }

  function getDecimal() public pure returns(uint256){
    return 1e18;
  }

  function getPriceDecimal() public pure returns(uint256){
    return 1e18;
  }
}
