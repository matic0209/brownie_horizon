pragma solidity >=0.4.21 <0.6.0;

import "../utils/Ownable.sol";
import "../utils/SafeMath.sol";
contract HEnv is Ownable{

  address public token_addr;

  address public fee_pool_addr;

  uint256 public ratio_base;
  uint256 public withdraw_fee_ratio;
  uint256 public cancel_fee_ratio;

  constructor(address _target_token) public{
    token_addr = _target_token;
    ratio_base = 100000000;
  }

  function changeFeePoolAddr(address _new) public onlyOwner{
    fee_pool_addr = _new;
  }

  function changeWithdrawFeeRatio(uint256 _ratio) public onlyOwner{
    require(_ratio < ratio_base, "ratio too large");
    withdraw_fee_ratio = _ratio;
  }

  function changeCancelFeeRatio(uint256 _ratio) public onlyOwner{
    require(_ratio < ratio_base, "ratio too large");
    cancel_fee_ratio = _ratio;
  }
}


contract HEnvFactory{
  event NewHEnv(address addr);
  function createHEnv(address _target_token) public returns (address){
    HEnv env = new HEnv(_target_token);
    env.transferOwnership(msg.sender);
    emit NewHEnv(address(env));
    return address(env);
  }
}
