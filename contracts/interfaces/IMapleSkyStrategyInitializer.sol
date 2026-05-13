// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 *  @title Defines a contract used to initialize new Maple Sky strategies.
 */
interface IMapleSkyStrategyInitializer {

    /**
     *  @dev   Parameters required to initialize a Sky strategy.
     *  @param strategyManager         Address of the strategy manager contract.
     *  @param fundsAsset              Address of the asset used for strategy funds.
     *  @param psm                     Address of the PSM contract.
     *  @param savingsUsds             Address of the savings USDS contract.
     *  @param strategyDelegateFeeRate Percentage of yield collected by the strategy delegate.
     *  @param strategyProtocolFeeRate Percentage of yield collected by the Maple treasury.
     *  @param referralCode            Referral code used when depositing into Sky.
     */
    struct Parameters {
        address strategyManager;
        address fundsAsset;
        address psm;
        address savingsUsds;
        uint32  strategyDelegateFeeRate;
        uint32  strategyProtocolFeeRate;
        uint16  referralCode;
    }

    /**
     *  @dev   Emitted when the Sky strategy proxy is initialized.
     *  @param params Sky strategy parameters set during initialization.
     */
    event Initialized(Parameters params);

}
