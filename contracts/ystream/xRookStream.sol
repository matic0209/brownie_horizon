pragma solidity >=0.4.21 <0.6.0;
import "../erc20/IERC20.sol";
import "../utils/SafeMath.sol";

import "./IYieldStream.sol";


contract IRookPool{
  function totalValueLocked(address _token) public view returns (uint256);
}

contract xRookStream is IYieldStream{
  using SafeMath for uint256;
  address rook;
  address xrook;
  IRookPool lp;

  constructor() public{
    name = "xRook yield stream";
    rook = address(0xfA5047c9c78B8877af97BDcb85Db743fD7313d4a);
    xrook = address(0x8aC32F0a635a0896a8428A9c31fBf1AB06ecf489);
    lp = IRookPool(address(0x4F868C1aa37fCf307ab38D215382e88FCA6275E2));
  }

  function target_token() public view returns(address){
    return xrook;
  }

  function getVirtualPrice() public view returns(uint256){
    if(IERC20(xrook).totalSupply() == 0){
      return 0;
    }
    return lp.totalValueLocked(rook).safeMul(1e18).safeDiv(IERC20(xrook).totalSupply());
  }

  function getDecimal() public pure returns(uint256){
    return 1e18;
  }

  function getPriceDecimal() public pure returns(uint256){
    return 1e18;
  }
}
