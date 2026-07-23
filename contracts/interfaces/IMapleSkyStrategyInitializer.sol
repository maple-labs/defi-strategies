// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 *  @dev   Parameters required to initialize a Sky strategy.
 *         Initializer arguments are encoded as abi.encode(strategyManager) || abi.encode(params).
 *  @param fundsAsset              Address of the asset used for strategy funds.
 *  @param psm                     Address of the PSM contract.
 *  @param savingsUsds             Address of the savings USDS contract.
 *  @param strategyDelegateFeeRate Percentage of yield collected by the strategy delegate.
 *  @param strategyProtocolFeeRate Percentage of yield collected by the Maple treasury.
 *  @param referralCode            Referral code used when depositing into Sky.
 *  @param strategyMetadata        Optional metadata associated with the Sky strategy.
 */
struct SkyStrategyInitializerParams {
    address fundsAsset;
    address psm;
    address savingsUsds;
    uint32  strategyDelegateFeeRate;
    uint32  strategyProtocolFeeRate;
    uint16  referralCode;
    string  strategyMetadata;
}

/**
 *  @title Defines a contract used to initialize new Maple Sky strategies.
 */
interface IMapleSkyStrategyInitializer {

    /**
     *  @dev   Emitted when the Sky strategy proxy is initialized.
     *  @param strategyManager Address of the strategy manager contract.
     *  @param params          Sky strategy parameters set during initialization.
     */
    event Initialized(address indexed strategyManager, SkyStrategyInitializerParams params);

}
