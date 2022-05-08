#!/usr/bin/python3
from brownie import (
    ERC20Base,
    HDispatcher,
    HEnv,
    HEnvFactory,
    HGateKeeper,
    HGateKeeperFactory,
    HPeriod,
    HPeriodFactory,
    HToken,
    HTokenAggregator,
    HTokenFactory,
    SafeMath,
    TrustList,
    accounts,
    xRookStream,
)

gas_strategy = "40 gwei"


def log(text, desc=""):
    print("\033[32m" + text + "\033[0m" + desc)


"""
"""


def xrook_stream():
    account = accounts[-1]
    SafeMath.at("0x071108Ad85d7a766B41E0f5e5195537A8FC8E74D")

    stream = xRookStream.deploy(
        {
            "from": account,
            "gas_price": gas_strategy,
            "gas_limit": 6000000,
            "allow_revert": True,
        }
    )
    stream.tx.wait(1)
    return stream


def env_xrook(stream):
    account = accounts[-1]
    log("address of account", str(account.address))

    envfactory = HEnvFactory.at("0x7A9CBE3AA00dC37205f31E46e65e6D28c1737408")
    log("envfactory address", str(envfactory.address))

    stream = xRookStream.at(stream.address)
    stream_token = stream.target_token()
    tx = envfactory.createHEnv(
        stream_token,
        {
            "from": account,
            "gas_price": gas_strategy,
            "gas_limit": 6000000,
            "allow_revert": True,
        },
    )
    tx.wait(1)
    env = HEnv.at(tx.return_value)

    log("env contract address", str(env.address))

    owner = "0x1Ed79CEbC592044fF1e63A7a96dB944DB50e302D"
    env.changeFeePoolAddr(
        owner,
        {
            "from": account,
            "gas_price": gas_strategy,
            "gas_limit": 6000000,
            "allow_revert": True,
        },
    )

    env.changeWithdrawFeeRatio(
        10000,
        {
            "from": account,
            "gas_price": gas_strategy,
            "gas_limit": 6000000,
            "allow_revert": True,
        },
    )
    return env, stream_token, stream


def horizon_mkdt(env, stream_token, stream):
    account = accounts[-1]
    log("address of account", str(account.address))

    start_block = 14477894

    period = 41710

    str_add = "0xe4AbFc56AC8b8C98B986916E7EDfe2762408A419"
    period_factory = HPeriodFactory.at(str_add)
    str_add = "0xFC8D22071FD617066bB94c80A790C76f440453dC"
    token_factory = HTokenFactory.at(str_add)
    gatekeeper_factory = HGateKeeperFactory.at(
        "0x8Bbb989ba1E62038E43c04Fb7a54c9C58C058C81"
    )

    tx = period_factory.createHPeriod(
        start_block,
        period,
        {
            "from": account,
            "gas_price": gas_strategy,
            "gas_limit": 6000000,
            "allow_revert": True,
        },
    )
    tx.wait(1)
    longterm = HPeriod.at(tx.return_value)
    log("longterm contract address", str(longterm.address))

    tx = token_factory.createHToken(
        "horizon_xRook_1week",
        "HFxRook1",
        True,
        {
            "from": account,
            "gas_price": gas_strategy,
            "gas_limit": 6000000,
            "allow_revert": True,
        },
    )
    tx.wait(1)
    float_token = HToken.at(tx.return_value)
    log("token contract address", str(float_token.address))

    dispatcher = HDispatcher.at("0x4775D2B1A3f582b3153e8B78a5C5337036D35f54")
    log("dispatcher address", str(dispatcher.address))

    dispatcher.resetYieldStream(
        stream_token,
        stream.address,
        {
            "from": account,
            "gas_price": gas_strategy,
            "gas_limit": 6000000,
            "allow_revert": True,
        },
    )

    aggr = HTokenAggregator.at("0x890c899cd0812F54F33269A41eFA6c041Da35cf3")
    log("aggr new address", str(aggr.address))

    tx = gatekeeper_factory.createGateKeeperForPeriod(
        env,
        dispatcher,
        longterm.address,
        float_token.address,
        aggr,
        {
            "from": account,
            "gas_price": gas_strategy,
            "gas_limit": 6000000,
            "allow_revert": True,
        },
    )
    tx.wait(1)
    gatekeeper = HGateKeeper.at(tx.return_value)
    log("gatekeeper contract address", str(gatekeeper.address))

    ratios = [
        95890,
        153424,
        210958,
        268493,
        326027,
        383561,
        441095,
        498630,
        556164,
        613698,
        671232,
        728767,
    ]
    gatekeeper.resetSupportRatios(
        ratios,
        {
            "from": account,
            "gas_price": gas_strategy,
            "gas_limit": 6000000,
            "allow_revert": True,
        },
    )

    fee_pool_addr = "0x1Ed79CEbC592044fF1e63A7a96dB944DB50e302D"
    gatekeeper.changeYieldPool(
        fee_pool_addr,
        {
            "from": account,
            "gas_price": gas_strategy,
            "gas_limit": 6000000,
            "allow_revert": True,
        },
    )

    longterm.transferOwnership(
        gatekeeper.address,
        {
            "from": account,
            "gas_price": gas_strategy,
            "gas_limit": 6000000,
            "allow_revert": True,
        },
    )

    float_token.transferOwnership(
        gatekeeper.address,
        {
            "from": account,
            "gas_price": gas_strategy,
            "gas_limit": 6000000,
            "allow_revert": True,
        },
    )

    aggr_tlist = TrustList.at("0x00c4528C1e8e84d4C57A203573Ef07eE63aDd59A")
    aggr_tlist.add_trusted(
        gatekeeper.address,
        {
            "from": account,
            "gas_price": gas_strategy,
            "gas_limit": 6000000,
            "allow_revert": True,
        },
    )
    return gatekeeper


def deposit(gatekeeper):
    account = accounts[-2]
    log("address of account", str(account.address))
    xrook = ERC20Base.at("0x8aC32F0a635a0896a8428A9c31fBf1AB06ecf489")
    tx = xrook.approve(
        gatekeeper.address,
        1000000000000000000000000000000000000000,
        {
            "from": account,
            "gas_price": gas_strategy,
            "gas_limit": 3000000,
            "allow_revert": True,
        },
    )
    tx.wait(1)

    tx = gatekeeper.bidFloating(
        8165670269296418632511,
        {
            "from": account,
            "gas_price": gas_strategy,
            "gas_limit": 3000000,
            "allow_revert": True,
        },
    )
    tx.wait(1)


def main():
    env, stream_token, stream = env_xrook(xrook_stream())
    gatekeeper = horizon_mkdt(env, stream_token, stream)
    deposit(gatekeeper)
    gatekeeper.start({"from": accounts[-1]})
