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
     *  @dev    Returns the full asset-denominated impairment recorded for the strategy.
     *  @return impairedAssets Funds-asset amount of impairment recorded for the strategy.
     */
    function impairedAssets() external view returns (uint256 impairedAssets);

    /**
     *  @dev    Returns whether a final loss has been recognized for this strategy.
     *  @return isLossRecognized Whether the strategy is shut down after final loss recognition.
     */
    function isLossRecognized() external view returns (bool isLossRecognized);

    /**
     *  @dev    Returns the funds-asset equivalent of the Aave position recorded at the end of the most
     *          recent state-changing call. Used as the baseline against which yield (and therefore fees) accrue.
     *  @return lastRecordedTotalAssets Last recorded funds-asset equivalent of the strategy's Aave position.
     */
    function lastRecordedTotalAssets() external view returns (uint256 lastRecordedTotalAssets);

    /**
     *  @dev    Returns the referral code used when depositing into Aave.
     *  @return referralCode Referral code used when depositing into Aave.
     */
    function referralCode() external view returns (uint16 referralCode);

    /**
     *  @dev    Returns the percentage of yield collected by the strategy delegate.
     *          Defined with 6 decimals of precision (1e6 == 100%).
     *  @return strategyDelegateFeeRate Percentage of yield collected by the strategy delegate.
     */
    function strategyDelegateFeeRate() external view returns (uint32 strategyDelegateFeeRate);

    /**
     *  @dev    Returns the address of the strategy manager contract.
     *  @return strategyManager Address of the strategy manager.
     */
    function strategyManager() external view returns (address strategyManager);

    /**
     *  @dev    Returns the percentage of yield collected by the Maple treasury.
     *          Defined with 6 decimals of precision (1e6 == 100%).
     *  @return strategyProtocolFeeRate Percentage of yield collected by the Maple treasury.
     */
    function strategyProtocolFeeRate() external view returns (uint32 strategyProtocolFeeRate);

}
