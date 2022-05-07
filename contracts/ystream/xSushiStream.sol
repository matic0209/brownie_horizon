pragma solidity >=0.4.21 <0.6.0;
import "../erc20/IERC20.sol";
import "../utils/SafeMath.sol";

import "./IYieldStream.sol";


contract xSushiInterface is IERC20{
  IERC20 public sushi;
}

contract xSushiStream is IYieldStream{
  using SafeMath for uint256;
  xSushiInterface public xsushi;

  constructor() public{
    name = "xSushi yield stream";
    xsushi = xSushiInterface(address(0x8798249c2E607446EfB7Ad49eC89dD1865Ff4272));
  }


  function target_token() public view returns(address){
    return address(xsushi);
  }

  function getVirtualPrice() public view returns(uint256){
    if(xsushi.totalSupply() == 0){
      return 0;
    }

    return xsushi.sushi().balanceOf(address(xsushi)).safeMul(1e18).safeDiv(xsushi.totalSupply());
  }

  function getDecimal() public pure returns(uint256){
    return 1e18;
  }

  function getPriceDecimal() public pure returns(uint256){
    return 1e18;
  }
}
