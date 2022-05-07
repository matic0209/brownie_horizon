pragma solidity >=0.4.21 <0.6.0;
import "../utils/Ownable.sol";
//import "../utils/SafeMath.sol";
//import "../erc20/SafeERC20.sol";
import "../erc20/IERC20.sol";
import "../ystream/IYieldStream.sol";
import "./HEnv.sol";
import "./HToken.sol";
import "./HGateKeeperHelper.sol";
import "./HGateKeeperParam.sol";
import "./HInterfaces.sol";

/// @notice Gatekeeper contains all user interfaces and updating values of tokens
contract HGateKeeper is Ownable{
  using SafeERC20 for IERC20;
  using SafeMath for uint256;
  using HGateKeeperHelper for HGateKeeperParam.settle_round_param_info;// mapping(uint256=>uint256) ;

  HDispatcherInterface public dispatcher;//the contracts to get the yield strem
  address public target_token;//the target token, e.g. yycurve
  HEnv public env;//the contract of environment variables, mainly the fee ratios

  HLongTermInterface public long_term;//the contract that maintain the period and generate/destroy all tokens.
  address public yield_interest_pool;//the pool that additional target tokens.
  HTokenAggregatorInterface public aggr;

  address public float_longterm_token;

  MinterInterfaceGK public minter;

  uint256 public settled_round;//the index of the round that has been settled
  uint256 public max_amount;//the max amount that a wallet allowd to bid.


  mapping (uint256 => HGateKeeperParam.round_price_info) public round_prices;//price info of all rounds

  mapping (bytes32 => uint256) target_token_amount_in_round_and_ratio;//amount of target token invested in a given round and ratio
  mapping (bytes32 => uint256) long_term_token_amount_in_round_and_ratio;//amount of longterm token in a given round and ratio
  mapping (uint256 => uint256) total_target_token_in_round;//amount of total target token invested in a round

  /// @dev Constructor to create a gatekeeper
  /// @param _token_addr Address of the target token, such as yUSD or yvUSDC
  /// @param _env Address of env, to get fee ratios
  /// @param _dispatcher Address of the dispatcher, to get yield stream
  /// @param _long_term Address of the Hlongterm contract, to generate/destroy in/out-tokens.
  constructor(address _token_addr, address _env, address _dispatcher, address _long_term, address _float_token, address _aggr) public{
    target_token = _token_addr;
    env = HEnv(_env);
    dispatcher = HDispatcherInterface(_dispatcher);
    long_term = HLongTermInterface(_long_term);
    settled_round = 0;
    aggr = HTokenAggregatorInterface(_aggr);
    float_longterm_token = _float_token;
  }

  event ChangeMaxAmount(uint256 old, uint256 _new);
  function set_max_amount(uint _amount) public onlyOwner{
    uint256 old = max_amount;
    max_amount = _amount;
    emit ChangeMaxAmount(old, max_amount);
  }

  event HorizonBid(address from, uint256 amount, uint256 share, uint256 round, uint256 ratio);
  /// @dev User invests terget tokens to the contract to take part in the game in the next round and further rounds.
  /// User gets intokens with respect to the next round.
  /// @param _amount The amount of target token that the user invests
  /// @param _ratio The ratio that the user chooses.
  function bidRatio(uint256 _amount, uint256 _ratio) public{
    require(_ratio == 0 || isSupportRatio(_ratio), "not support ratio");    
    _check_round();

    require(IERC20(target_token).allowance(msg.sender, address(this)) >= _amount, "not enough allowance");
    uint _before = IERC20(target_token).balanceOf(address(this));
    IERC20(target_token).safeTransferFrom(msg.sender, address(this), _amount);
    uint256 _after = IERC20(target_token).balanceOf(address(this));
    _amount = _after.safeSub(_before); // Additional check for deflationary tokens

    uint256 decimal = dispatcher.getYieldStream(target_token).getDecimal();
    require(decimal <= 1e18, "decimal too large");
    uint256 shares = _amount.safeMul(1e18).safeDiv(decimal);//turn into 1e18 decimal

    if(max_amount > 0){
      require(shares <= max_amount, "too large amount");
      require(aggr.balanceOf(address(this), settled_round + 2, _ratio, 1, msg.sender).safeAdd(shares) <= max_amount, "Please use another wallet");
    }
    aggr.mint(address(this), settled_round + 2, _ratio, 1, shares, msg.sender);
    //HTokenInterfaceGK(in_addr).mint(msg.sender, shares);

    if (minter != MinterInterfaceGK(0x0)){
      MinterInterfaceGK(minter).handle_bid_ratio(msg.sender, shares, _ratio, settled_round + 2);
    }
    emit HorizonBid(msg.sender, _amount, shares, settled_round + 2, _ratio);
  }

  function bidFloating(uint256 _amount) public{
    bidRatio(_amount, 0);
  }
  event CancelBid(address from, uint256 amount, uint256 fee, uint256 round, uint256 ratio);
  function cancelBid(uint256 amount, uint256 _ratio) public{
    //user can only cancel bid for the next round (during the current round period)
    require(_ratio == 0 || isSupportRatio(_ratio), "not support ratio");
    _check_round();

    //HTokenInterfaceGK(_in_token_addr).burnFrom(msg.sender, amount);
    aggr.burn(address(this), settled_round + 2, _ratio, 1, amount, msg.sender);
    
    uint256 decimal = dispatcher.getYieldStream(target_token).getDecimal();

    uint256 target_amount = amount.safeMul(decimal).safeDiv(1e18);

    if (minter != MinterInterfaceGK(0x0)){
      MinterInterfaceGK(minter).handle_cancel_bid(msg.sender, amount, _ratio, settled_round + 2);
    }

    if(env.cancel_fee_ratio() != 0 && env.fee_pool_addr() != address(0x0)){
      uint256 fee = target_amount.safeMul(env.cancel_fee_ratio()).safeDiv(env.ratio_base());
      uint256 recv = target_amount.safeSub(fee);
      IERC20(target_token).safeTransfer(msg.sender, recv);
      IERC20(target_token).safeTransfer(env.fee_pool_addr(), fee);
      emit CancelBid(msg.sender, recv, fee, settled_round + 2, _ratio);
    }else{
      IERC20(target_token).safeTransfer(msg.sender, target_amount);
      emit CancelBid(msg.sender, target_amount, 0, settled_round + 2, _ratio);
    }
  }
   /*
  function changeBid(address _in_token_addr, uint256 _new_amount, uint256 _new_ratio) public{
    cancelBid(_in_token_addr);
    bidRatio(_new_amount, _new_ratio);
  }*/

  event HorizonWithdrawLongTermToken(address from, uint256 amount, uint256 round, uint256 ratio);
  /// @dev User changes longterm tokens to outtokens with respect to the next round,
  /// meaning that he quits the game by the next round.
  /// @param _amount The amount of longterm token that the user wants to withdraw.
  function withdrawLongTerm(uint256 ratio, uint256 _amount) public{
    _check_round();
    uint256 total_amount;
    if (ratio == 0){
      require(IERC20(float_longterm_token).balanceOf(msg.sender) >= _amount, "GK:not enough balance");
      HTokenInterfaceGK(float_longterm_token).burnFrom(msg.sender, _amount);
    }
    else{
      total_amount = aggr.balanceOf(address(this), 0, ratio, 3, msg.sender);
      aggr.burn(address(this), 0, ratio, 3, _amount, msg.sender);
    }
    aggr.mint(address(this), settled_round + 2, ratio, 2, _amount, msg.sender);
    //HTokenInterfaceGK(out_addr).mint(msg.sender, _amount);
    if (minter != MinterInterfaceGK(0x0)){
      MinterInterfaceGK(minter).handle_withdraw(msg.sender, _amount, ratio, settled_round + 2);
    }

    emit HorizonWithdrawLongTermToken(msg.sender, _amount, settled_round + 2, ratio);
  }


  function withdrawInToken(uint256 ratio, uint256 round, uint256 _amount) public{
    require(ratio == 0 || isSupportRatio(ratio), "not support ratio");
    _check_round();
    require(settled_round + 1 >= round, "GK: round not sealed");

    uint256 amount = aggr.balanceOf(address(this), round, ratio, 1, msg.sender);

    require(_amount <= amount, "GK: not enough intoken balance");
    aggr.burn(address(this), round, ratio, 1, _amount, msg.sender);

    uint256 ratio_to = aggr.getRatioTo(address(this), round, ratio, 1);
    uint256 lt_amount = _amount.safeMul(ratio_to).safeDiv(1e18);

    emit HorizonExchangeToLongTermToken(msg.sender, _amount, lt_amount, round, ratio);

    aggr.mint(address(this), settled_round + 2, ratio, 2, lt_amount, msg.sender);    
    if (minter != MinterInterfaceGK(0x0)){
      MinterInterfaceGK(minter).handle_withdraw(msg.sender, lt_amount, ratio, settled_round + 2);
    }

    emit HorizonWithdrawLongTermToken(msg.sender, lt_amount, settled_round + 2, ratio);
  }
  event HorizonCancelWithdraw(address from, uint256 amount, uint256 ratio, uint256 round);
  /// @dev User cancel his/her withdraw operation,
  /// changing all outtokens back to longterm token.
  function cancelWithdraw(uint256 _ratio, uint256 _amount) public{
    require(_ratio == 0 || isSupportRatio(_ratio), "not support ratio");
    _check_round();
    aggr.burn(address(this), settled_round + 2, _ratio, 2, _amount, msg.sender);
    
    if (_ratio == 0){
      HTokenInterfaceGK(float_longterm_token).mint(msg.sender, _amount);
    }
    else
    {
      aggr.mint(address(this), 0, _ratio, 3, _amount, msg.sender);
    }
    if (minter != MinterInterfaceGK(0x0)){
      MinterInterfaceGK(minter).handle_cancel_withdraw(msg.sender, _amount, _ratio, settled_round + 2);
    }

    emit HorizonCancelWithdraw(msg.sender, _amount, _ratio, settled_round + 2);
  }

  event HorizonClaim(address from, uint256 out_amount, uint256 amount, uint256 fee, uint256 round, uint256 ratio);
  /// @dev User withdraws outtokens to get target tokens.
  /// @param _amount The amount of outtoken.
  function claim(uint256 round, uint256 ratio, uint256 _amount) public {
    require(ratio == 0 || isSupportRatio(ratio), "not support ratio");
    _check_round();

    require(settled_round + 1 >= round, "GK: period not end");

    uint256 decimal = dispatcher.getYieldStream(target_token).getDecimal();
    uint256 ratio_to = aggr.getRatioTo(address(this), round, ratio, 2);
    uint256 t = _amount.safeMul(ratio_to).safeMul(decimal).safeDiv(1e36);//turn into target decimal

    aggr.burn(address(this), round, ratio, 2, _amount, msg.sender);

    if(env.withdraw_fee_ratio() != 0 && env.fee_pool_addr() != address(0x0)){
      uint256 fee = t.safeMul(env.withdraw_fee_ratio()).safeDiv(env.ratio_base());
      uint256 recv = t.safeSub(fee);
      IERC20(target_token).safeTransfer(msg.sender, recv);
      IERC20(target_token).safeTransfer(env.fee_pool_addr(), fee);
      emit HorizonClaim(msg.sender, _amount, recv, fee, round, ratio);
    }else{
      IERC20(target_token).safeTransfer(msg.sender, t);
      emit HorizonClaim(msg.sender, _amount, t, 0, round, ratio);
    }
  }

  event HorizonExchangeToLongTermToken(address from, uint256 amount_in, uint256 amount_long, uint256 round, uint256 ratio);
  /// @dev User changes all intokens to long-term tokens,
  /// so that the user can withdraw to outtoken or transfer in secondary markets.
  function exchangeToLongTermToken(uint256 round, uint256 ratio) public{
    //require(ratio == 0 || isSupportRatio(ratio), "not support ratio");
    require(ratio == 0, "not support ratio");
    _check_round();
    require(settled_round + 1 >= round, "GK: round not sealed");

    uint256 amount = aggr.balanceOf(address(this), round, ratio, 1, msg.sender);
    require(amount > 0, "GK: no in token balance");

    aggr.burn(address(this), round, ratio, 1, amount, msg.sender);

    uint256 ratio_to = aggr.getRatioTo(address(this), round, ratio, 1);

    uint256 rec = amount.safeMul(ratio_to).safeDiv(1e18);
    
    if (ratio == 0){
      HTokenInterfaceGK(float_longterm_token).mint(msg.sender, rec);
    }
    else{
      aggr.mint(address(this), 0, ratio, 3, rec, msg.sender);
    }
    emit HorizonExchangeToLongTermToken(msg.sender, amount, rec, round, ratio);
  }

  /// @dev To check whether the current round should end.
  /// If so, do settlement for the current round and begin a new round.
  HGateKeeperParam.settle_round_param_info info;
  function _check_round() internal{
    long_term.updatePeriodStatus();
    uint256 new_period = long_term.getCurrentRound();
    if(round_prices[new_period].start_price == 0){
      round_prices[new_period].start_price = dispatcher.getYieldStream(target_token).getVirtualPrice();
    }
    if(long_term.isRoundEnd(settled_round + 1)){
      /*HGateKeeperParam.settle_round_param_info memory info*/ info = HGateKeeperParam.settle_round_param_info({
                      _round:settled_round+1,
                       dispatcher:dispatcher,
                       target_token:target_token,
                       minter:minter,
                       long_term:long_term,
                       aggr:aggr,
                       sratios:sratios,
                       env_ratio_base:env.ratio_base(),
                       float_longterm_token:float_longterm_token,
                       yield_interest_pool:yield_interest_pool,
                       start_price:round_prices[settled_round+1].start_price,
                       end_price:round_prices[settled_round+1].end_price,
                       total_target_token:total_target_token_in_round[settled_round+1],
                       total_target_token_next_round:total_target_token_in_round[settled_round+2],
                       left: 0
      });
      settled_round =
        info.settle_round(target_token_amount_in_round_and_ratio, long_term_token_amount_in_round_and_ratio);
      total_target_token_in_round[settled_round + 1] = total_target_token_in_round[settled_round + 1].safeAdd(info.total_target_token_next_round);
    }
  }

  mapping (uint256 => bool) public support_ratios;
  uint256[] public sratios;

  event SupportRatiosChanged(uint256[] rs);
  function resetSupportRatios(uint256[] memory rs) public onlyOwner{
    for(uint i = 0; i < sratios.length; i++){
      delete support_ratios[sratios[i]];
    }
    delete sratios;
    for(uint i = 0; i < rs.length; i++){
      if(i > 0){
        require(rs[i] > rs[i-1], "should be ascend");
      }
      sratios.push(rs[i]);
      support_ratios[rs[i]] = true;
    }
    emit SupportRatiosChanged(sratios);
  }

  function isSupportRatio(uint256 r) public view returns(bool){
    for(uint i = 0; i < sratios.length; i++){
      if(sratios[i] == r){
        return true;
      }
    }
    return false;
  }
  function updatePeriodStatus() public{
    _check_round();
  }


  event ChangeYieldInterestPool(address old, address _new);
  function changeYieldPool(address _pool) onlyOwner public{
    require(_pool != address(0x0), "invalid pool");
    address old = yield_interest_pool;
    yield_interest_pool = _pool;
    emit ChangeYieldInterestPool(old, _pool);
  }
  event SetMinter(address addr);
  function set_minter(address addr) onlyOwner public{
    minter = MinterInterfaceGK(addr);
    emit SetMinter(addr);
  }
  
  function add_transfer_listener_to(address _listener) onlyOwner public{
    HTokenInterfaceGK(float_longterm_token).addTransferListener(_listener);
  }
  function remove_transfer_listener_to(address _listener) onlyOwner public{
    HTokenInterfaceGK(float_longterm_token).removeTransferListener(_listener);
  }
}

contract HGateKeeperFactory is Ownable{
  event NewGateKeeper(address addr);

  function createGateKeeperForPeriod(address _env_addr, address _dispatcher, address _long_term, address _float_token, address _aggr) public returns(address){
    HEnv e = HEnv(_env_addr);
    HGateKeeper gk = new HGateKeeper(e.token_addr(), _env_addr, _dispatcher, _long_term, _float_token, _aggr);
    gk.transferOwnership(msg.sender);
    emit NewGateKeeper(address(gk));
    return address(gk);
  }
}

