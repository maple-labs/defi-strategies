// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { AaveV3TestBase } from "../../utils/AaveV3TestBase.sol";

contract AaveV3AvailableToWithdrawTests is AaveV3TestBase {

    function test_availableToWithdraw_success_zeroPosition() external view {
        /**********************************************************************************************************************************/
        /*** Step 1: Assert initial state                                                                                               ***/
        /**********************************************************************************************************************************/

        uint256 aaveTokenBalance        = 0;
        uint256 lastRecordedTotalAssets = 0;
        uint256 aaveLiquidity           = 0;
        uint256 assetsUnderManagement   = 0;

        assertAaveV3Strategy({
            aaveTokenBalance:        aaveTokenBalance,
            lastRecordedTotalAssets: lastRecordedTotalAssets,
            assetsUnderManagement:   assetsUnderManagement
        });

        assertAaveV3Liquidity(aaveLiquidity);

        /**********************************************************************************************************************************/
        /*** Step 2: Assert available liquidity                                                                                         ***/
        /**********************************************************************************************************************************/

        uint256 expectedAvailableToWithdraw = 0;

        assertEq(strategy.availableToWithdraw(), expectedAvailableToWithdraw);
    }

    function test_availableToWithdraw_success_fullLiquidity_returnsAumNetOfFees() external {
        /**********************************************************************************************************************************/
        /*** Step 1: Pre-seed strategy state                                                                                            ***/
        /**********************************************************************************************************************************/

        strategy.__setStrategyDelegateFeeRate(0.02e6);  // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6);  // 3% protocol fee

        uint256 lastRecordedTotalAssets = 100e6;
        uint256 yieldAccrued            = 100e6;
        uint256 aaveTokenBalance        = lastRecordedTotalAssets + yieldAccrued;
        uint256 expectedDelegateFee     = 2e6;    // 2% of 100e6 yield.
        uint256 expectedProtocolFee     = 3e6;    // 3% of 100e6 yield.
        uint256 assetsUnderManagement   = 195e6;  // 200e6 Aave balance - 2e6 delegate fee - 3e6 protocol fee.
        uint256 aaveLiquidity           = 300e6;  // Aave has more liquidity than the strategy's 200e6 aToken balance.

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: lastRecordedTotalAssets,
            aaveTokenBalance_:        aaveTokenBalance
        });

        setAaveV3Liquidity(aaveLiquidity);

        assertAaveV3Strategy({
            aaveTokenBalance:        aaveTokenBalance,
            lastRecordedTotalAssets: lastRecordedTotalAssets,
            assetsUnderManagement:   assetsUnderManagement
        });

        assertAaveV3Liquidity(aaveLiquidity);

        /**********************************************************************************************************************************/
        /*** Step 2: Assert available liquidity                                                                                         ***/
        /**********************************************************************************************************************************/

        uint256 grossAvailable              = aaveTokenBalance;  // min(200e6 strategy balance, 300e6 Aave liquidity).
        uint256 expectedAvailableToWithdraw = grossAvailable - expectedDelegateFee - expectedProtocolFee;

        assertEq(strategy.availableToWithdraw(), expectedAvailableToWithdraw);
    }

    function test_availableToWithdraw_success_partialLiquidity_returnsLiquidityNetOfFees() external {
        /**********************************************************************************************************************************/
        /*** Step 1: Pre-seed strategy state                                                                                            ***/
        /**********************************************************************************************************************************/

        strategy.__setStrategyDelegateFeeRate(0.02e6);  // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6);  // 3% protocol fee

        uint256 lastRecordedTotalAssets = 100e6;
        uint256 yieldAccrued            = 100e6;
        uint256 aaveTokenBalance        = lastRecordedTotalAssets + yieldAccrued;
        uint256 expectedDelegateFee     = 2e6;    // 2% of 100e6 yield.
        uint256 expectedProtocolFee     = 3e6;    // 3% of 100e6 yield.
        uint256 assetsUnderManagement   = 195e6;  // 200e6 Aave balance - 2e6 delegate fee - 3e6 protocol fee.
        uint256 aaveLiquidity           = 80e6;   // Aave liquidity is the limiting side.

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: lastRecordedTotalAssets,
            aaveTokenBalance_:        aaveTokenBalance
        });

        setAaveV3Liquidity(aaveLiquidity);

        assertAaveV3Strategy({
            aaveTokenBalance:        aaveTokenBalance,
            lastRecordedTotalAssets: lastRecordedTotalAssets,
            assetsUnderManagement:   assetsUnderManagement
        });

        assertAaveV3Liquidity(aaveLiquidity);

        /**********************************************************************************************************************************/
        /*** Step 2: Assert available liquidity                                                                                         ***/
        /**********************************************************************************************************************************/

        uint256 grossAvailable              = aaveLiquidity;  // min(200e6 strategy balance, 80e6 Aave liquidity).
        uint256 expectedAvailableToWithdraw = grossAvailable - expectedDelegateFee - expectedProtocolFee;

        assertEq(strategy.availableToWithdraw(), expectedAvailableToWithdraw);
    }

    function test_availableToWithdraw_success_usesVirtualLiquidityIgnoresDonatedUnderlying() external {
        /**********************************************************************************************************************************/
        /*** Step 1: Pre-seed strategy state                                                                                            ***/
        /**********************************************************************************************************************************/

        strategy.__setStrategyDelegateFeeRate(0.02e6);  // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6);  // 3% protocol fee

        uint256 lastRecordedTotalAssets = 100e6;
        uint256 yieldAccrued            = 100e6;
        uint256 aaveTokenBalance        = lastRecordedTotalAssets + yieldAccrued;
        uint256 expectedDelegateFee     = 2e6;     // 2% of 100e6 yield.
        uint256 expectedProtocolFee     = 3e6;     // 3% of 100e6 yield.
        uint256 assetsUnderManagement   = 195e6;   // 200e6 Aave balance - 2e6 delegate fee - 3e6 protocol fee.
        uint256 aaveLiquidity           = 80e6;    // Virtual liquidity is the limiting side.
        uint256 donatedUnderlying       = 1_000e6; // Raw aToken underlying balance should not increase withdrawable liquidity.

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: lastRecordedTotalAssets,
            aaveTokenBalance_:        aaveTokenBalance
        });

        setAaveV3Liquidity(aaveLiquidity);

        asset.mint(address(aaveToken), donatedUnderlying);

        assertAaveV3Strategy({
            aaveTokenBalance:        aaveTokenBalance,
            lastRecordedTotalAssets: lastRecordedTotalAssets,
            assetsUnderManagement:   assetsUnderManagement
        });

        assertAaveV3Liquidity(aaveLiquidity);
        assertEq(asset.balanceOf(address(aaveToken)), aaveLiquidity + donatedUnderlying);

        /**********************************************************************************************************************************/
        /*** Step 2: Assert available liquidity                                                                                         ***/
        /**********************************************************************************************************************************/

        uint256 grossAvailable              = aaveLiquidity;  // min(200e6 strategy balance, 80e6 virtual Aave liquidity).
        uint256 expectedAvailableToWithdraw = grossAvailable - expectedDelegateFee - expectedProtocolFee;

        assertEq(strategy.availableToWithdraw(), expectedAvailableToWithdraw);
    }

    function test_availableToWithdraw_success_liquidityEqualToAccruedFees() external {
        /**********************************************************************************************************************************/
        /*** Step 1: Pre-seed strategy state                                                                                            ***/
        /**********************************************************************************************************************************/

        strategy.__setStrategyDelegateFeeRate(0.02e6);  // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6);  // 3% protocol fee

        uint256 lastRecordedTotalAssets = 100e6;
        uint256 yieldAccrued            = 100e6;
        uint256 aaveTokenBalance        = lastRecordedTotalAssets + yieldAccrued;
        uint256 expectedDelegateFee     = 2e6;    // 2% of 100e6 yield.
        uint256 expectedProtocolFee     = 3e6;    // 3% of 100e6 yield.
        uint256 assetsUnderManagement   = 195e6;  // 200e6 Aave balance - 5e6 total accrued fees.
        uint256 totalAccruedFees        = expectedDelegateFee + expectedProtocolFee;
        uint256 aaveLiquidity           = totalAccruedFees;

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: lastRecordedTotalAssets,
            aaveTokenBalance_:        aaveTokenBalance
        });

        setAaveV3Liquidity(aaveLiquidity);

        assertAaveV3Strategy({
            aaveTokenBalance:        aaveTokenBalance,
            lastRecordedTotalAssets: lastRecordedTotalAssets,
            assetsUnderManagement:   assetsUnderManagement
        });

        assertAaveV3Liquidity(aaveLiquidity);

        /**********************************************************************************************************************************/
        /*** Step 2: Assert available liquidity                                                                                         ***/
        /**********************************************************************************************************************************/

        uint256 grossAvailable              = aaveLiquidity;  // min(200e6 strategy balance, 5e6 Aave liquidity).
        uint256 expectedAvailableToWithdraw = 0;              // 5e6 gross available - 5e6 total accrued fees.

        assertEq(grossAvailable, totalAccruedFees);
        assertEq(strategy.availableToWithdraw(), expectedAvailableToWithdraw);
    }

    function test_availableToWithdraw_success_liquidityLessThanAccruedFees() external {
        /**********************************************************************************************************************************/
        /*** Step 1: Pre-seed strategy state                                                                                            ***/
        /**********************************************************************************************************************************/

        strategy.__setStrategyDelegateFeeRate(0.02e6);  // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6);  // 3% protocol fee

        uint256 lastRecordedTotalAssets = 100e6;
        uint256 yieldAccrued            = 100e6;
        uint256 aaveTokenBalance        = lastRecordedTotalAssets + yieldAccrued;
        uint256 expectedDelegateFee     = 2e6;    // 2% of 100e6 yield.
        uint256 expectedProtocolFee     = 3e6;    // 3% of 100e6 yield.
        uint256 assetsUnderManagement   = 195e6;  // 200e6 Aave balance - 5e6 total accrued fees.
        uint256 aaveLiquidity           = 4e6;    // Less than the 5e6 total accrued fees.
        uint256 totalAccruedFees        = expectedDelegateFee + expectedProtocolFee;

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: lastRecordedTotalAssets,
            aaveTokenBalance_:        aaveTokenBalance
        });

        setAaveV3Liquidity(aaveLiquidity);

        assertAaveV3Strategy({
            aaveTokenBalance:        aaveTokenBalance,
            lastRecordedTotalAssets: lastRecordedTotalAssets,
            assetsUnderManagement:   assetsUnderManagement
        });

        assertAaveV3Liquidity(aaveLiquidity);

        /**********************************************************************************************************************************/
        /*** Step 2: Assert available liquidity                                                                                         ***/
        /**********************************************************************************************************************************/

        uint256 grossAvailable              = aaveLiquidity;  // min(200e6 strategy balance, 4e6 Aave liquidity).
        uint256 expectedAvailableToWithdraw = 0;              // Gross available is less than total accrued fees.

        assertLt(grossAvailable, totalAccruedFees);
        assertEq(strategy.availableToWithdraw(), expectedAvailableToWithdraw);
    }

    function test_availableToWithdraw_success_noYieldAndLossReturnMinimumOfPositionAndLiquidity() external {
        /**********************************************************************************************************************************/
        /*** Step 1: Pre-seed no-yield strategy state                                                                                   ***/
        /**********************************************************************************************************************************/

        strategy.__setStrategyDelegateFeeRate(0.02e6);  // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6);  // 3% protocol fee

        uint256 noYieldLastRecordedTotalAssets = 100e6;
        uint256 noYieldAaveTokenBalance        = 100e6;
        uint256 noYieldAssetsUnderManagement   = 100e6;  // No yield means no accrued fees.
        uint256 noYieldAaveLiquidity           = 60e6;   // Aave liquidity is the limiting side.

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: noYieldLastRecordedTotalAssets,
            aaveTokenBalance_:        noYieldAaveTokenBalance
        });

        setAaveV3Liquidity(noYieldAaveLiquidity);

        assertAaveV3Strategy({
            aaveTokenBalance:        noYieldAaveTokenBalance,
            lastRecordedTotalAssets: noYieldLastRecordedTotalAssets,
            assetsUnderManagement:   noYieldAssetsUnderManagement
        });

        assertAaveV3Liquidity(noYieldAaveLiquidity);

        /**********************************************************************************************************************************/
        /*** Step 2: Assert no-yield available liquidity                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 noYieldGrossAvailable              = noYieldAaveLiquidity;  // min(100e6 strategy balance, 60e6 Aave liquidity).
        uint256 noYieldExpectedAvailableToWithdraw = noYieldGrossAvailable;

        assertEq(strategy.availableToWithdraw(), noYieldExpectedAvailableToWithdraw);

        /**********************************************************************************************************************************/
        /*** Step 3: Pre-seed loss strategy state                                                                                       ***/
        /**********************************************************************************************************************************/

        uint256 lossLastRecordedTotalAssets = 100e6;
        uint256 lossAaveTokenBalance        = 80e6;
        uint256 lossAssetsUnderManagement   = 80e6;  // Losses do not accrue fees.
        uint256 lossAaveLiquidity           = 50e6;  // Aave liquidity is the limiting side.

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: lossLastRecordedTotalAssets,
            aaveTokenBalance_:        lossAaveTokenBalance
        });

        setAaveV3Liquidity(lossAaveLiquidity);

        assertAaveV3Strategy({
            aaveTokenBalance:        lossAaveTokenBalance,
            lastRecordedTotalAssets: lossLastRecordedTotalAssets,
            assetsUnderManagement:   lossAssetsUnderManagement
        });

        assertAaveV3Liquidity(lossAaveLiquidity);

        /**********************************************************************************************************************************/
        /*** Step 4: Assert loss available liquidity                                                                                     ***/
        /**********************************************************************************************************************************/

        uint256 lossGrossAvailable              = lossAaveLiquidity;  // min(80e6 strategy balance, 50e6 Aave liquidity).
        uint256 lossExpectedAvailableToWithdraw = lossGrossAvailable;

        assertEq(strategy.availableToWithdraw(), lossExpectedAvailableToWithdraw);
    }

    function test_availableToWithdraw_success_maxFeeRateReturnsZero() external {
        /**********************************************************************************************************************************/
        /*** Step 1: Pre-seed strategy state                                                                                            ***/
        /**********************************************************************************************************************************/

        strategy.__setStrategyDelegateFeeRate(0.4e6);  // 40% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.6e6);  // 60% protocol fee

        uint256 lastRecordedTotalAssets = 0;
        uint256 yieldAccrued            = 100e6;
        uint256 aaveTokenBalance        = yieldAccrued;
        uint256 expectedDelegateFee     = 40e6;   // 40% of 100e6 yield.
        uint256 expectedProtocolFee     = 60e6;   // 60% of 100e6 yield.
        uint256 aaveLiquidity           = 100e6;  // Aave can cover the full 100e6 strategy balance.
        uint256 assetsUnderManagement   = 0;      // 100e6 Aave balance - 100e6 total accrued fees.

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: lastRecordedTotalAssets,
            aaveTokenBalance_:        aaveTokenBalance
        });

        setAaveV3Liquidity(aaveLiquidity);

        assertAaveV3Strategy({
            aaveTokenBalance:        aaveTokenBalance,
            lastRecordedTotalAssets: lastRecordedTotalAssets,
            assetsUnderManagement:   assetsUnderManagement
        });

        assertAaveV3Liquidity(aaveLiquidity);

        /**********************************************************************************************************************************/
        /*** Step 2: Assert available liquidity                                                                                         ***/
        /**********************************************************************************************************************************/

        uint256 grossAvailable              = aaveTokenBalance;  // min(100e6 strategy balance, 100e6 Aave liquidity).
        uint256 expectedAvailableToWithdraw = 0;                 // Gross available is fully consumed by fees.

        assertEq(grossAvailable, expectedDelegateFee + expectedProtocolFee);
        assertEq(strategy.availableToWithdraw(), expectedAvailableToWithdraw);
    }

}
