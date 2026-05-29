// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleProxied } from "../../modules/proxy-factory/contracts/interfaces/IMapleProxied.sol";

import { IMapleAaveV3StrategyStorage } from "./IMapleAaveV3StrategyStorage.sol";

/**
 *  @title Defines a Maple Aave V3 strategy.
 */
interface IMapleAaveV3Strategy is IMapleAaveV3StrategyStorage, IMapleProxied {

    /**************************************************************************************************************************************/
    /*** Events                                                                                                                         ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Emitted when funds asset is deployed into the underlying Aave strategy.
     *  @param strategyManager Address of the strategy manager that initiated the call.
     *  @param assetsIn        Amount of funds asset consumed from the strategy balance.
     *  @param deployedAssets  Funds-asset amount deployed into Aave.
     */
    event StrategyFunded(address indexed strategyManager, uint256 assetsIn, uint256 deployedAssets);

    /**
     *  @dev   Emitted once per fee-accrual cycle when yield fees are withdrawn from the underlying Aave position.
     *  @param delegateFee Funds-asset amount paid to the strategy delegate.
     *  @param protocolFee Funds-asset amount paid to the Maple treasury.
     */
    event StrategyFeesCollected(uint256 delegateFee, uint256 protocolFee);

    /**************************************************************************************************************************************/
    /*** State-Changing Functions                                                                                                       ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev    Deploys funds asset already held by this contract into Aave.
     *          Callable only by the bound strategy manager. Accrues outstanding fees before depositing
     *          and refreshes the fee-accrual baseline to the post-deposit position.
     *  @param  assetsIn       Amount of funds asset to deploy. Must already be held by this contract.
     *  @param  data           Reserved for future strategy-specific calldata. Unused by the Aave strategy.
     *  @return deployedAssets Funds-asset amount deployed into Aave.
     */
    function fundUnderlyingStrategy(uint256 assetsIn, bytes calldata data) external returns (uint256 deployedAssets);

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev    Returns the funds-asset equivalent of the strategy's Aave position net of accrued yield fees.
     *  @return assetsUnderManagement Funds-asset equivalent currently attributable to the strategy manager.
     */
    function assetsUnderManagement() external view returns (uint256 assetsUnderManagement);

    /**
     *  @dev    Returns the address of the Maple Globals contract.
     *  @return globals Address of the Maple Globals contract.
     */
    function globals() external view returns (address globals);

    /**
     *  @dev    Returns the Maple treasury address.
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
