// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 *  @title Defines the storage layout of a Maple Sky strategy.
 */
interface IMapleSkyStrategyStorage {

    /**
     *  @dev    Returns the address of the asset used for strategy funds.
     *  @return fundsAsset Address of the funds asset.
     */
    function fundsAsset() external view returns (address fundsAsset);

    /**
     *  @dev    Returns the address of the PSM contract.
     *  @return psm Address of the PSM.
     */
    function psm() external view returns (address psm);

    /**
     *  @dev    Returns the referral code used when depositing into Sky.
     *  @return referralCode Referral code used when depositing into Sky.
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

    /**
     *  @dev    Returns the address of the savings USDS contract.
     *  @return savingsUsds Address of savings USDS.
     */
    function savingsUsds() external view returns (address savingsUsds);

    /**
     *  @dev    Returns the address of the USDS contract.
     *  @return usds Address of USDS.
     */
    function usds() external view returns (address usds);

}
