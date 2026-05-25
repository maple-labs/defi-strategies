// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 *  @title Defines a contract used to initialize new Maple Aave V3 strategies.
 */
interface IMapleAaveV3StrategyInitializer {

    /**
     *  @dev   Parameters required to initialize an Aave V3 strategy.
     *  @param strategyManager         Address of the strategy manager contract.
     *  @param aaveToken               Address of the Aave token.
     *  @param strategyDelegateFeeRate Percentage of yield collected by the strategy delegate.
     *  @param strategyProtocolFeeRate Percentage of yield collected by the Maple treasury.
     *  @param referralCode            Referral code used when depositing into Aave.
     */
    struct Parameters {
        address strategyManager;
        address aaveToken;
        uint32  strategyDelegateFeeRate;
        uint32  strategyProtocolFeeRate;
        uint16  referralCode;
    }

    /**
     *  @dev   Emitted when the Aave V3 strategy proxy is initialized.
     *  @param params Aave V3 strategy parameters set during initialization.
     */
    event Initialized(Parameters params);

}
