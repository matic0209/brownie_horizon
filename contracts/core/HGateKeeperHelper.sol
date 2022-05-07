pragma solidity >=0.4.21 <0.6.0;

import "./HInterfaces.sol";
import "../erc20/SafeERC20.sol";
import "../erc20/IERC20.sol";
import "../ystream/IYieldStream.sol";
import "./HGateKeeperParam.sol";


library HGateKeeperHelper{

  using SafeMath for uint;
  using SafeERC20 for IERC20;
  event ThrowError(address gatekeeper, uint256 round, uint256 ratio);

  function _settle_round_for_one_ratio(HGateKeeperParam.settle_round_param_info storage info,
                        //mapping (uint256 => uint256) storage total_target_token_in_round,
                        mapping (bytes32 => uint256) storage target_token_amount_in_round_and_ratio,
                        mapping (bytes32 => uint256) storage long_term_token_amount_in_round_and_ratio,
                        uint256 i
      ) internal returns(uint256 s){
      // "hashs" and "hasht" corresponds to the index (hash) of the pair (_round, sratios[i]) and (_round + 1, sratios[i]),
      // the i-th ratio with current round, and the i-th ratio with the next round respectively.
      bytes32 hashs = keccak256(abi.encodePacked(info._round, info.sratios[i]));
      // "t" is actual amount of target token, invested for i-th ratio and current round,
      // including the value of longterm tokens and intokens.
      uint256 t = target_token_amount_in_round_and_ratio[hashs];
      // nt is the required interest for tokens invested for i-th ratio.
      // For example, if the i-th ratio is 5% and target token amount for this ratio is 10000,
      // start_price is 1e18, then nt = 500*1e18.
      uint256 nt = t.safeMul(info.start_price).safeMul(info.sratios[i]).safeDiv(info.env_ratio_base);
      /// require(info.long_term.get_long_term_token_with_ratio(info.sratios[i]) != address(0x0), "GK:Long term token not set");
      // simulate the distribution of total interest.
      // If the remaining interest can afford the required interest for i-th ratio,
      // then "nt" sets to be the require interest
      // Otherwise "nt" set to be the remain interest
      // So, "nt" is the actual received interest for i-th ratio.
      // The ramain interest ("left") decreases by "nt".
      if(nt > info.left){
        nt = info.left;
      }
      info.left = info.left.safeSub(nt);
      // now, set "t" to be the amount of target token (normalized to 1e18) distributed to i-th ratio and current round,
      // after the price of target token changing and the interests being distributed.
      // "t" times start price is the total price before,
      // then add "nt" is the total price after obtaining the distributed interest,
      // then div "end_price" to change the total price into the amount of target token, of new price
      t = t.safeMul(info.start_price).safeAdd(nt).safeDiv(info.end_price);

      // "ratio_to" computes the ratio of longterm token to target token, united in 1e18,
      // "long_term_token_amount_in_round_and_ratio[hashs]" records the amount of longterm tokens in i-th ratio and current round,
      // including all unexchanged intokens.
      // The default ratio is 1e18 if there is no longterm token.
      // "ratio_to" is a significant variable for updating all maintained values in "_updata_values()"
      uint256 ratio_to;
      if (long_term_token_amount_in_round_and_ratio[hashs] == 0){
        ratio_to = 1e18;
      }
      else{
        ratio_to = t.safeMul(1e18).safeDiv(long_term_token_amount_in_round_and_ratio[hashs]);
        if (ratio_to == 0) {ratio_to = 1e18; emit ThrowError(address(this), info._round, info.sratios[i]);}
      }
      //s = s.safeAdd(t);
      s = t;
      t = info.aggr.getRatioTo(address(this), 0, info.sratios[i], 3);

      //update minter info for this round
      
      if (info.minter != MinterInterfaceGK(0x0)){
        info.minter.handle_settle_round(
          info.sratios[i],
          t,
          uint256(1e36).safeDiv(ratio_to),
          long_term_token_amount_in_round_and_ratio[hashs],
          nt
        );
      }  
      
      // update the maintained values
      update_values(info, target_token_amount_in_round_and_ratio, long_term_token_amount_in_round_and_ratio, ratio_to, info.sratios[i]);
  }

  function _settle_round_for_tail(HGateKeeperParam.settle_round_param_info storage info,
                        //mapping (uint256 => uint256) storage total_target_token_in_round,
                        mapping (bytes32 => uint256) storage target_token_amount_in_round_and_ratio,
                        mapping (bytes32 => uint256) storage long_term_token_amount_in_round_and_ratio,
                        uint256 nt
                                 ) internal returns(uint256 s){

    //uint256 nt = left;
    // "left" now is the amount of target token should be allocated to floating.
    //left = total_target_token_in_round[info._round].safeSub(s);
    // handle for floating, similar to before.
    bytes32 hashs = keccak256(abi.encodePacked(info._round, uint256(0)));
    uint256 ratio_to;
    s = 0;
    if (long_term_token_amount_in_round_and_ratio[hashs] == 0){
      ratio_to = 1e18;
    }
    else{
      ratio_to = nt.safeMul(1e18).safeDiv(long_term_token_amount_in_round_and_ratio[hashs]);
      s = nt;
      if (ratio_to == 0) {ratio_to = 1e18; emit ThrowError(address(this), info._round, 0);}
      //s = s.safeAdd(left);
    }
    if (info.minter != MinterInterfaceGK(0x0)){
      info.minter.handle_settle_round(
        0,
        HTokenInterfaceGK(info.float_longterm_token).ratio_to_target(),
        uint256(1e36).safeDiv(ratio_to),
        long_term_token_amount_in_round_and_ratio[hashs],
        info.left
      );
    }
    update_values(info, target_token_amount_in_round_and_ratio, long_term_token_amount_in_round_and_ratio, ratio_to, 0);
}

  /// @dev This function is executed when the round (indexed by _round) is end.
  /// It does the settlement for current round with respect to the following things:
  /// 1.	It updates the value of all longterm tokens in target token, according to the price from yield stream in current round.
  /// It also sets the value of intokens and outtokens in the next round.
  /// 2.	It maintains the amount of longterm tokens (including unexchanged intokens) and target tokens in the next round.
  function settle_round(HGateKeeperParam.settle_round_param_info storage info,
                        //mapping (uint256 => uint256) storage total_target_token_in_round,
                        mapping (bytes32 => uint256) storage target_token_amount_in_round_and_ratio,
                        mapping (bytes32 => uint256) storage long_term_token_amount_in_round_and_ratio
                       ) public returns(uint256 settled_round){
    // get the price of target token from the yield stream. The unit is 1e18.
    if(info.end_price == 0){
      info.end_price = info.dispatcher.getYieldStream(info.target_token).getVirtualPrice();
    }
    /// "left" records the remaining interest in current round. The unit is 1e18.
    /// At the begining, it equals to the actual interest of all target tokens in current round.
    /// It then distributes to tokens invested for different ratio,
    // and decreases accordingly when it is consumed to fulfill interests.
    info.left = info.total_target_token.safeMul(info.end_price.safeSub(info.start_price));
    if (info.minter != MinterInterfaceGK(0x0)){
      info.minter.loop_prepare(
        info.total_target_token.safeSub(target_token_amount_in_round_and_ratio[keccak256(abi.encodePacked(info._round, uint256(0)))]),
        target_token_amount_in_round_and_ratio[keccak256(abi.encodePacked(info._round, uint256(0)))],
        info.long_term.getRoundLength(info._round),
        info.start_price,
        info.end_price
      );
    }
    uint256 s = 0;

    // The following FOR loop updates the value of all longterm tokens, for ratios from small to large.
    // It finally updates the value for floating.
    for(uint256 i = 0; i < info.sratios.length; i++){
      // "s" records the total amount of distributed target tokens.
      s = s.safeAdd(_settle_round_for_one_ratio(info, target_token_amount_in_round_and_ratio, long_term_token_amount_in_round_and_ratio, i));
    }
    {
      s = s.safeAdd(_settle_round_for_tail(info, target_token_amount_in_round_and_ratio, long_term_token_amount_in_round_and_ratio, info.total_target_token.safeSub(s)));
    }
    // for the case where there is no floating token,
    // the unallocated target tokens (if any) are transferred to our pool.
    if(s < info.total_target_token){
      s = info.total_target_token.safeSub(s);
      require(info.yield_interest_pool != address(0x0), "invalid yield interest pool");
      if (IERC20(info.target_token).balanceOf(address(this)) >= s){
        IERC20(info.target_token).safeTransfer(info.yield_interest_pool, s);
      }
      info.total_target_token_next_round = info.total_target_token_next_round.safeSub(s);
      //total_target_token_in_round[info._round + 1] =  total_target_token_in_round[info._round + 1].safeSub(s);
    }
    // update the variable "settled_round", means that "_round" is settled and "_round" + 1 should begin
    settled_round = info._round;
  }
  /// @dev the necessary update for maintained variables
  /// @param ratio the value of the i-th ratio (sratios[i])
  function update_values(
    HGateKeeperParam.settle_round_param_info storage info,
                        mapping (bytes32 => uint256) storage target_token_amount_in_round_and_ratio,
                        mapping (bytes32 => uint256) storage long_term_token_amount_in_round_and_ratio,
                        uint256 ratio_to, uint256 ratio) internal {
      uint256 in_target_amount;//how many newly-come target tokens for the next round.
      uint256 out_target_amount;//how many target tokens leave before the next round.
      uint256 in_long_term_amount;//how many newly-come longterm tokens for the next round.
      uint256 out_long_term_amount;//how many target tokens leave before the next round.

      //"hashs" and "hasht" are indexes the same as before
      bytes32 hashs = keccak256(abi.encodePacked(info._round, ratio));
      bytes32 hasht = keccak256(abi.encodePacked(info._round + 1, ratio));

      //set the ratio of the longterm token to target token.
      //recall that it is the definition of "ratio_to".
      //lt.set_ratio_to_target(ratio_to);
      if (ratio == 0){
        HTokenInterfaceGK(info.float_longterm_token).set_ratio_to_target(ratio_to);
      }
      else{
        info.aggr.setRatioTo(address(this), 0, ratio, 3, ratio_to);
      }
      
      //set the value of intoken in the next round, the ratio to longterm token.
      //since when the intoken is generated, its amount is 1:1 bind to target token,
      //so, the ratio of intoken to longterm token should be set to the reciprocal of "ratio_to".
      //HTokenInterfaceGK(info.long_term.hintokenAtPeriodWithRatio(info._round + 1, ratio)).set_ratio_to_target(uint256(1e36).safeDiv(ratio_to));
      in_target_amount = uint256(1e36).safeDiv(ratio_to);//temporarily use
      info.aggr.setRatioTo(address(this), info._round + 1, ratio, 1, in_target_amount);
      //since the amount of intoken is 1:1 to the target token,
      //the amount of newly-come target token equals to the total amount of intoken in the next round.
      //in_target_amount = info.long_term.totalInAtPeriodWithRatio(info._round + 1, ratio);
      in_target_amount = info.aggr.totalSupply(address(this), info._round + 1, ratio, 1);
      //compute the corresponding amount of newly-come longterm token.
      //since the ratio of intoken to longterm token has been set, compute it directly.
      //in_long_term_amount = info.long_term.totalInAtPeriodWithRatio(info._round + 1, ratio).safeMul(HTokenInterfaceGK(info.long_term.hintokenAtPeriodWithRatio(info._round + 1, ratio)).ratio_to_target()).safeDiv(1e18);
      in_long_term_amount = in_target_amount.safeMul(1e18).safeDiv(ratio_to); 
 
      //set the value of outtoken in the next round, the ratio to target token.
      //since when the outtoken is generated, its amount is 1:1 bind to long_term token at first,
      //the ratio of outtoken to target token should be set to "ratio_to".
      //HTokenInterfaceGK(info.long_term.houttokenAtPeriodWithRatio(info._round + 1, ratio)).set_ratio_to_target(ratio_to);
      info.aggr.setRatioTo(address(this), info._round + 1, ratio, 2, ratio_to);
      //compute the amount of target token that leaves. 
      //since the ratio of outtoken to target token has been set, compute it directly.
      out_target_amount = info.aggr.totalSupply(address(this), info._round + 1, ratio, 2).safeMul(ratio_to).safeDiv(1e18);
      //since the amount of outtoken is 1:1 to the longterm token at first,
      //the amount of longterm token that leaves equals to the total amount of intoken in the next round.
      out_long_term_amount = info.aggr.totalSupply(address(this), info._round + 1, ratio, 2);
   
      //update the amount of target token and long term token in the new round

      //compute the target token amount in i-th ratio for next round,
      //which means that this amount of target token joins in the game in i-th ratio and the next round.
      //It first computes the value of longterm token in target token after the price changing,
      //since the ratio_to is given.
      //It then adds the newly-come amount and subs the leave amount.
      target_token_amount_in_round_and_ratio[hasht] = long_term_token_amount_in_round_and_ratio[hashs].safeMul(ratio_to).safeDiv(1e18).safeAdd(in_target_amount).safeSub(out_target_amount);
      //The amount of total target token in the next round (to all ratios)
      //initially set to be the total target token amount in current round.
      if (ratio == info.sratios[0]) {
        //total_target_token_in_round[_round + 1] = total_target_token_in_round[_round];
        info.total_target_token_next_round = info.total_target_token;
      }
      //update the total target token amount in the next round,
      //by adding increment and subbing decrement for each ratio.
      info.total_target_token_next_round = info.total_target_token_next_round.safeAdd(in_target_amount).safeSub(out_target_amount);
      //total_target_token_in_round[_round + 1] =  total_target_token_in_round[_round + 1].safeAdd(in_target_amount).safeSub(out_target_amount);
      //update the longterm token amount in i-th ratio and the next round,
      //by taking the longterm token amount in i-th ratio and current round, and adding increment and subbing decrement.
      long_term_token_amount_in_round_and_ratio[hasht] = long_term_token_amount_in_round_and_ratio[hashs].safeAdd(in_long_term_amount).safeSub(out_long_term_amount);
      //Additional check: after update,
      //the amount of target token in i-th ratio and the next round,
      //should equal to the amount of longterm token in i-th ratio and the next round times ratio_to.
      //Due to the accuracy issue, we let the difference less than 10000(in 1e18).
      //(This should never happen)
      _abs_check(target_token_amount_in_round_and_ratio[hasht].safeMul(1e18), long_term_token_amount_in_round_and_ratio[hasht].safeMul(ratio_to));
  }

  function _abs_check(uint256 a, uint256 b) public pure{
    if (a >= b) {require (a.safeSub(b) <= 1e22, "GK: double check");}
    else {require (b.safeSub(a) <= 1e22, "GK: double check");}
  }
}
