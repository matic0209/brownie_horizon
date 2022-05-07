pragma solidity >=0.4.21 <0.6.0;
import "../TrustListTools.sol";
import "../utils/SafeMath.sol";

contract HTokenAggregator is TrustListTools{
    using SafeMath for uint256;
    mapping (bytes32 => uint256) public balance;
    mapping (bytes32 => uint256) public total_supply;
    mapping (bytes32 => uint256) public ratio_to_target;

    mapping (uint256 => string) public types;
    constructor() public{
        types[1] = "horizon_in";
        types[2] = "horizon_out";
        types[3] = "horizon_long";
    }
    function mint(address gk, uint256 round, uint256 ratio, uint256 _type, uint256 amount, address recv) public is_trusted(msg.sender){
        bytes32 hash_ = keccak256(abi.encodePacked(gk, round, ratio, types[_type], recv));
        balance[hash_] = balance[hash_].safeAdd(amount);
        hash_ =  keccak256(abi.encodePacked(gk, round, ratio, types[_type]));
        total_supply[hash_] = total_supply[hash_].safeAdd(amount);
    }
    function burn(address gk, uint256 round, uint256 ratio, uint256 _type, uint256 amount, address recv) public is_trusted(msg.sender){
        bytes32 hash_ = keccak256(abi.encodePacked(gk, round, ratio, types[_type], recv));
        require(balance[hash_] >= amount, "not enough balance");
        balance[hash_] = balance[hash_].safeSub(amount);       
        hash_ =  keccak256(abi.encodePacked(gk, round, ratio, types[_type]));
        total_supply[hash_] = total_supply[hash_].safeSub(amount);
    }
    function balanceOf(address gk, uint256 round, uint256 ratio, uint256 _type, address recv) public view returns(uint256){
        bytes32 hash_ = keccak256(abi.encodePacked(gk, round, ratio, types[_type], recv));
        return balance[hash_];
    }
    function totalSupply(address gk, uint256 round, uint256 ratio, uint256 _type) public view returns(uint256){
        bytes32 hash_ = keccak256(abi.encodePacked(gk, round, ratio, types[_type]));
        return total_supply[hash_];
    }
    function getRatioTo(address gk, uint256 round, uint256 ratio, uint256 _type) public view returns(uint256){
        bytes32 hash_ = keccak256(abi.encodePacked(gk, round, ratio, types[_type]));
        return ratio_to_target[hash_];
    }
    function setRatioTo(address gk, uint256 round, uint256 ratio, uint256 _type, uint256 ratio_to) public is_trusted(msg.sender){
        bytes32 hash_ = keccak256(abi.encodePacked(gk, round, ratio, types[_type]));
        ratio_to_target[hash_] = ratio_to;
    }
}

contract HTokenAggregatorFactory{
  event NewHTokenAggregator(address addr);

  function createHTokenAggregator() public returns(address){
      HTokenAggregator dis = new HTokenAggregator();
      dis.transferOwnership(msg.sender);
      emit NewHTokenAggregator(address(dis));
      return address(dis);
  }
}
