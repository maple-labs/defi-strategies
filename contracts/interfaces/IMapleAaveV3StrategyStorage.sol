// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 *  @title Defines the storage layout of a Maple Aave V3 strategy.
 */
interface IMapleAaveV3StrategyStorage {

    /**
     *  @dev    Returns the address of the Aave V3 pool.
     *  @return aavePool Address of the Aave V3 pool.
     */
    function aavePool() external view returns (address aavePool);

    /**
     *  @dev    Returns the address of the Aave token.
     *  @return aaveToken Address of the Aave token.
     */
    function aaveToken() external view returns (address aaveToken);

    /**
     *  @dev    Returns the address of the asset used for strategy funds.
     *  @return fundsAsset Address of the funds asset.
     */
    function fundsAsset() external view returns (address fundsAsset);

    /**
     *  @dev    Returns the address of the strategy manager contract.
     *  @return strategyManager Address of the strategy manager.
     */
    function strategyManager() external view returns (address strategyManager);

}
