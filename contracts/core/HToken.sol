pragma solidity >=0.4.21 <0.6.0;
import "../utils/Ownable.sol";
import "../utils/SafeMath.sol";
import "../erc20/SafeERC20.sol";
import "../erc20/ERC20Impl.sol";
import "../TrustListTools.sol";

contract HToken is ERC20Base, Ownable{
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  address public target;
  uint256 public ratio_to_target;
  //uint256 public types; // 1 for in,2 for out, 3 for long term
  mapping (bytes32 => uint256) public extra;//record extra information of the token, including the round, type and ratio

  constructor(string memory _name, string memory _symbol, bool _transfersEnabled)
  ERC20Base(ERC20Base(address(0x0)), 0, _name, 18, _symbol, _transfersEnabled) public{}

  function reconstruct(string memory _name, string memory _symbol, bool _transfersEnabled) public onlyOwner{
    name = _name;
    symbol = _symbol;
    transfersEnabled = _transfersEnabled;
  }

  function mint(address addr, uint256 amount) onlyOwner public{
    _generateTokens(addr, amount);
  }
  function burnFrom(address addr, uint256 amount) onlyOwner public{
    _destroyTokens(addr, amount);
  }

  function set_extra(bytes32 _target, uint256 _value) onlyOwner public{
    extra[_target] = _value;
  }

  function set_target(address _target) onlyOwner public{
    target = _target;
  }

  function addTransferListener(address _addr) public onlyOwner{
    _addTransferListener(_addr);
  }
  function removeTransferListener(address _addr) public onlyOwner{
    _removeTransferListener(_addr);
  }

  event HTokenSetRatioToTarget(uint256 ratio_to);
  function set_ratio_to_target(uint256 _ratio_to) onlyOwner public{
    ratio_to_target = _ratio_to;
    emit HTokenSetRatioToTarget(_ratio_to);
  }
}

contract HTokenFactoryInterface{
  function createHToken(string memory _name, string memory _symbol, bool _transfersEnabled) public returns(address);
  function destroyHToken(address addr) public;
}

contract HTokenFactory is HTokenFactoryInterface{
  event NewHToken(address addr);
  event DestroyHToken(address addr);
  function createHToken(string memory _name, string memory _symbol, bool _transfersEnabled) public returns(address){
    HToken pt = new HToken(_name, _symbol, _transfersEnabled);
    pt.transferOwnership(msg.sender);
    emit NewHToken(address(pt));
    return address(pt);
  }
  function destroyHToken(address addr) public{
    //TODO, we choose do nothing here
    emit DestroyHToken(addr);
  }
}




