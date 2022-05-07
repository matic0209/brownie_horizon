pragma solidity >=0.4.21 <0.6.0;
import "./HToken.sol";
import "../ystream/IYieldStream.sol";
contract HLongTermInterface{
  function isRoundEnd(uint256 _period) public returns(bool);
  function getCurrentRound() public returns(uint256);
  function getRoundLength(uint256 _round) public view returns(uint256);
  function updatePeriodStatus() public returns(bool);
}
contract HTokenInterfaceGK{
  function mint(address addr, uint256 amount) public;
  function burnFrom(address addr, uint256 amount) public;
  function set_ratio_to_target(uint256 _balance) public;
  function set_extra(bytes32 _target, uint256 _value) public;
  function set_target(address _target) public;
  mapping (bytes32 => uint256) public extra;
  uint256 public ratio_to_target;
  function transferOwnership(address addr) public;
  function addTransferListener(address _addr) public;
  function removeTransferListener(address _addr) public;
}
contract HTokenAggregatorInterface{
  function mint(address gk, uint256 round, uint256 ratio, uint256 _type, uint256 amount, address recv) public;
  function burn(address gk, uint256 round, uint256 ratio, uint256 _type, uint256 amount, address recv) public;
  function balanceOf(address gk, uint256 round, uint256 ratio, uint256 _type, address recv) public view returns(uint256);
  function totalSupply(address gk, uint256 round, uint256 ratio, uint256 _type) public view returns(uint256);
  function getRatioTo(address gk, uint256 round, uint256 ratio, uint256 _type) public view returns(uint256);
  function setRatioTo(address gk, uint256 round, uint256 ratio, uint256 _type, uint256 ratio_to) public;

}
contract HDispatcherInterface{
  function getYieldStream(address _token_addr) public view returns (IYieldStream);
}
contract MinterInterfaceGK{
  function handle_bid_ratio(address addr, uint256 amount, uint256 ratio, uint256 round) public;
  function handle_withdraw(address addr, uint256 amount, uint256 ratio, uint256 round) public;
  function handle_cancel_withdraw(address addr, uint256 amount, uint256 ratio, uint256 round) public;
  function loop_prepare(uint256 fix_supply, uint256 float_supply, uint256 length, uint256 start_price, uint256 end_price) public;
  function handle_settle_round(uint256 ratio, uint256 ratio_to, uint256 intoken_ratio, uint256 lt_amount_in_ratio, uint256 nt) public;
  function handle_cancel_bid(address addr, uint256 amount, uint256 ratio, uint256 round) public;
}
