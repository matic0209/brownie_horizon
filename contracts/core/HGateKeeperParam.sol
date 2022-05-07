pragma solidity >=0.4.21 <0.6.0;
pragma solidity >=0.4.21 <0.6.0;

import "./HInterfaces.sol";
import "../erc20/SafeERC20.sol";
import "../erc20/IERC20.sol";
import "../ystream/IYieldStream.sol";

library HGateKeeperParam{
  struct round_price_info{
    uint256 start_price;
    uint256 end_price;
  } //the start/end price of target token in a round.

  struct settle_round_param_info{
                      uint256 _round;
                       HDispatcherInterface dispatcher;
                       address target_token;
                       MinterInterfaceGK minter;
                       HLongTermInterface long_term;
                       HTokenAggregatorInterface aggr;
                       uint256[] sratios;
                       uint256 env_ratio_base;
                       address float_longterm_token;
                       address yield_interest_pool;
                       uint256 start_price;
                       uint256 end_price;
                       uint256 total_target_token;
                       uint256 total_target_token_next_round;
                       uint256 left;

  }
}
