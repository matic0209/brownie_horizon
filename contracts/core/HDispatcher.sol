pragma solidity >=0.4.21 <0.6.0;
import "../utils/Ownable.sol";
import "../ystream/IYieldStream.sol";
import "../utils/Ownable.sol";
import "../erc20/SafeERC20.sol";

contract HDispatcher is Ownable{

  using SafeERC20 for IERC20;
  mapping (address => IYieldStream) public current_streams;

  constructor() public{}

  event YieldStreamChanged(address token_addr, address old_stream, address new_stream);

  function resetYieldStream(address _token_addr, address _yield_stream) public onlyOwner{
    address old = address(current_streams[_token_addr]);
    current_streams[_token_addr] = IYieldStream(_yield_stream);
    emit YieldStreamChanged(_token_addr, old, _yield_stream);
  }

  function getYieldStream(address _token_addr) public view returns (IYieldStream){
    return current_streams[_token_addr];
  }
}

contract HDispatcherFactory{
  event NewHDispatcher(address addr);

  function createHDispatcher() public returns(address){
      HDispatcher dis = new HDispatcher();
      dis.transferOwnership(msg.sender);
      emit NewHDispatcher(address(dis));
      return address(dis);
  }
}
