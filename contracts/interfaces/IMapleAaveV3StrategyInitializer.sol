// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 *  @title Defines a contract used to initialize new Maple Aave V3 strategies.
 */
interface IMapleAaveV3StrategyInitializer {

    /**
     *  @dev   Parameters required to initialize an Aave V3 strategy.
     *  @param strategyManager Address of the strategy manager contract.
     *  @param fundsAsset      Address of the asset used for strategy funds.
     *  @param aavePool        Address of the Aave V3 pool.
     *  @param aaveToken       Address of the Aave token.
     */
    struct Parameters {
        address strategyManager;
        address fundsAsset;
        address aavePool;
        address aaveToken;
    }

    /**
     *  @dev   Emitted when the Aave V3 strategy proxy is initialized.
     *  @param params Aave V3 strategy parameters set during initialization.
     */
    event Initialized(Parameters params);

}
