#!/usr/bin/python3
from brownie import  config, network, interface,accounts,HPeriodFactory,HTokenFactory,HGateKeeperFactory
from brownie.network.gas.strategies import GasNowStrategy

from scripts.helpful_scripts import (
    get_account,
    get_contract,
    LOCAL_BLOCKCHAIN_ENVIRONMENTS,
)
gas_strategy = "40 gwei"
def log(text, desc=''):
    print('\033[32m' + text + '\033[0m' + desc)

def horizon_mkdt():
    account = accounts[-1]

    log("address of account", str(account.address))

    start_block = 14477894;//2022-3-29 8 a.m


    period = 41710


    period_factory = HPeriodFactory("0xe4AbFc56AC8b8C98B986916E7EDfe2762408A419")
    token_factory = HTokenFactory("0xFC8D22071FD617066bB94c80A790C76f440453dC")
    gatekeeper_factory = HGateKeeperFactory("0x6c2da582218384dd956EB9ED49a892F2bA2D6340")


    print(crv.address)



    # tx = crv.updatePeriodStatus(
    #                         {"from": account_new, "gas_price": gas_strategy, "gas_limit": 6000000, "allow_revert": True})

    # tx.wait(1)


    tx = crv.withdrawInToken(479452,2, 360000000000000000000,
                            {"from": account, "gas_price": gas_strategy, "gas_limit": 6000000, "allow_revert": True})

    tx.wait(1)



def main():
    horizon_withdraw()
    #destroy_token("0x6c2da582218384dd956EB9ED49a892F2bA2D6340")

#     log("issue crv")

#    crv_issue()

#     # log("issue usdc")
#     usdc_issue()
#     deposit_crv_r()
#

#     # log("deposit crv")
#     #
#    earnReward()
    #crv_issue("0xe72979D7f270c17B50666A8E79AC88B43e121B0a")
    # deposit_crv()
#    deposit_usdc()
    # changeFeePool("0x6c2da582218384dd956EB9ED49a892F2bA2D6340")
    # changeHarvestFee(1000)





# # log("deposit usdc")
# #    deposit_usdc()


#     # log("deposit usdc")
#     withdraw_usdc()
