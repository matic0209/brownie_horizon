pragma solidity >=0.4.21 <0.6.0;
import "../utils/Ownable.sol";
import "../TrustListTools.sol";

contract IContractPool{
  function get_contract(bytes32 key) public returns(address);

  function recycle_contract(bytes32 key, address addr) public returns(bool);
  function add_using_contract(bytes32 key, address addr) public returns(bool);
  function add_nouse_contract(bytes32 key, address addr) public returns(bool);
}

contract ContractPool is TrustListTools{

  mapping (bytes32 => address[]) public available_contracts;
  mapping (address => bytes32) public used_contracts;

  constructor(address _tlist) public{
  }

  function get_contract(bytes32 key) public
  is_trusted(msg.sender) returns(address){
    address[] storage s = available_contracts[key];
    if(s.length == 0){
      return address(0x0);
    }
    address r = s[s.length - 1];
    s.length = s.length - 1;
    used_contracts[r] = key;
    Ownable(r).transferOwnership(msg.sender);
    return r;
  }

  function recycle_contract(bytes32 key, address addr) public
  is_trusted(msg.sender) returns(bool){
    require(used_contracts[addr] == key, "cannot recycle");
    require(Ownable(addr).owner() == address(this), "incorrect owner");

    delete used_contracts[addr];
    available_contracts[key].push(addr);
    return true;
  }
  function add_using_contract(bytes32 key, address addr) public is_trusted(msg.sender)
  returns(bool){
    //! Sanity check may increase gas cost, so we ignore it
    used_contracts[addr] = key;
    return true;
  }
  function add_nouse_contract(bytes32 key, address addr) public is_trusted(msg.sender)
  returns(bool){
    require(used_contracts[addr] == bytes32(0x0), "already in use");
    require(Ownable(addr).owner() == address(this), "incorrect owner");
    available_contracts[key].push(addr);
    return true;
  }
}
