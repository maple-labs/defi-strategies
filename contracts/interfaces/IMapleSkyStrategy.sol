// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleProxied } from "../../modules/proxy-factory/contracts/interfaces/IMapleProxied.sol";

import { IMapleSkyStrategyStorage } from "./IMapleSkyStrategyStorage.sol";

/**
 *  @title Defines a Maple Sky strategy.
 */
interface IMapleSkyStrategy is IMapleSkyStrategyStorage, IMapleProxied {

    /**************************************************************************************************************************************/
    /*** Events                                                                                                                         ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Emitted when the strategy delegate fee rate is set.
     *  @param strategyDelegateFeeRate Percentage of yield collected by the strategy delegate, defined with 6 decimals
     *                                 of precision (1e6 == 100%).
     */
    event StrategyDelegateFeeRateSet(uint32 strategyDelegateFeeRate);

    /**
     *  @dev   Emitted when funds asset is deployed into the underlying Sky strategy.
     *  @param strategyManager Address of the strategy manager that initiated the call.
     *  @param assetsIn        Amount of funds asset consumed from the strategy balance.
     *  @param sharesMinted    Amount of sUSDS shares received from the deposit.
     *  @param deployedAssets  Funds-asset equivalent currently redeemable from the newly minted shares.
     */
    event StrategyFunded(address indexed strategyManager, uint256 assetsIn, uint256 sharesMinted, uint256 deployedAssets);

    /**
     *  @dev   Emitted once per fee-accrual cycle when yield fees are withdrawn from the underlying Sky position.
     *  @param delegateFee Funds-asset amount paid to the strategy delegate.
     *  @param protocolFee Funds-asset amount paid to the Maple treasury.
     */
    event StrategyFeesCollected(uint256 delegateFee, uint256 protocolFee);

    /**
     *  @dev   Emitted when the strategy protocol fee rate is set.
     *  @param strategyProtocolFeeRate Percentage of yield collected by the Maple treasury, defined with 6 decimals
     *                                 of precision (1e6 == 100%).
     */
    event StrategyProtocolFeeRateSet(uint32 strategyProtocolFeeRate);

    /**
     *  @dev   Emitted when funds asset is withdrawn from the underlying Sky strategy to a destination.
     *  @param destination  Address that received the funds asset.
     *  @param sharesBurned Amount of sUSDS shares burned to satisfy the redemption.
     *  @param assetsOut    Amount of funds asset delivered to the destination.
     */
    event StrategyWithdrawal(address indexed destination, uint256 sharesBurned, uint256 assetsOut);

    /**************************************************************************************************************************************/
    /*** State-Changing Functions                                                                                                       ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev    Deploys funds asset already held by this contract into the Sky savings vault via the PSM.
     *          Callable only by the bound strategy manager. Accrues outstanding fees before depositing
     *          and refreshes the fee-accrual baseline to the post-deposit position.
     *  @param  assetsIn        Amount of funds asset to deploy. Must already be held by this contract.
     *  @param  data            Reserved for future strategy-specific calldata. Unused by the Sky strategy.
     *  @return deployedAssets  Funds-asset equivalent redeemable from the shares minted by this deposit,
     *                          net of the PSM `tout` fee that would apply on the inverse redemption.
     */
    function fundUnderlyingStrategy(uint256 assetsIn, bytes calldata data) external returns (uint256 deployedAssets);

    /**
     *  @dev   Sets the percentage of yield collected by the strategy delegate.
     *         Callable only by the strategy delegate.
     *         Accrues outstanding fees before updating the rate.
     *         The combined strategy delegate and protocol fee rates cannot exceed 1e6.
     *  @param strategyDelegateFeeRate Percentage of yield collected by the strategy delegate, defined with 6 decimals
     *                                 of precision (1e6 == 100%).
     */
    function setStrategyDelegateFeeRate(uint32 strategyDelegateFeeRate) external;

    /**
     *  @dev   Sets the percentage of yield collected by the Maple treasury.
     *         Callable only by protocol admins.
     *         Accrues outstanding fees before updating the rate.
     *         The combined strategy delegate and protocol fee rates cannot exceed 1e6.
     *  @param strategyProtocolFeeRate Percentage of yield collected by the Maple treasury, defined with 6 decimals
     *                                 of precision (1e6 == 100%).
     */
    function setStrategyProtocolFeeRate(uint32 strategyProtocolFeeRate) external;

    /**
     *  @dev   Redeems sUSDS shares back into funds asset via the PSM and delivers exactly `assets` to `destination`.
     *         Callable only by the bound strategy manager. Accrues outstanding fees before withdrawing
     *         and refreshes the fee-accrual baseline to the post-withdrawal position. The PSM `tout` fee
     *         is absorbed by the strategy's remaining sUSDS balance and socialized across shareholders.
     *  @param destination  Address that receives the withdrawn funds asset.
     *  @param assets       Amount of funds asset to deliver to the destination.
     *  @param data         Reserved for future strategy-specific calldata. Unused by the Sky strategy.
     */
    function withdrawFromUnderlyingStrategy(address destination, uint256 assets, bytes calldata data) external;

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev    Returns the funds-asset equivalent of the strategy's sUSDS position net of accrued yield fees.
     *  @return assetsUnderManagement Funds-asset equivalent currently attributable to the strategy manager.
     */
    function assetsUnderManagement() external view returns (uint256 assetsUnderManagement);

    /**
     *  @dev    Returns the address of the Maple Globals contract.
     *  @return globals Address of the Maple Globals contract.
     */
    function globals() external view returns (address globals);

    /**
     *  @dev    Returns the Maple treasury address that receives the protocol's share of accrued yield.
     *  @return mapleTreasury Address of the Maple treasury.
     */
    function mapleTreasury() external view returns (address mapleTreasury);

    /**
     *  @dev    Returns the address of the security admin.
     *  @return securityAdmin Address of the security admin.
     */
    function securityAdmin() external view returns (address securityAdmin);

    /**
     *  @dev    Returns the strategy delegate that receives the delegate's share of accrued yield for the
     *          bound strategy manager.
     *  @return strategyDelegate Address of the strategy delegate.
     */
    function strategyDelegate() external view returns (address strategyDelegate);

}
