pragma solidity >=0.4.21 <0.6.0;

import "./IYieldStream.sol";

contract yvUSDCInterface{
  function pricePerShare() public view returns(uint256);
}

contract yvUSDCStream is IYieldStream{

  yvUSDCInterface yvUSDC;
  constructor() public{
    name = "yvUSDC yield stream";
    yvUSDC = yvUSDCInterface(0xa354F35829Ae975e850e23e9615b11Da1B3dC4DE);
  }

  function target_token() public view returns(address){
    return address(0xa354F35829Ae975e850e23e9615b11Da1B3dC4DE);
  }

  function getVirtualPrice() public view returns(uint256){
    return yvUSDC.pricePerShare()*uint256(1e12);
  }
  function getDecimal() public pure returns(uint256){
    return 1e6;
  }

  function getPriceDecimal() public pure returns(uint256){
    return 1e18;
  }
}
