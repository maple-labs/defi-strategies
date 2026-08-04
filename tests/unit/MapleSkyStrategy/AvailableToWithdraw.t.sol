// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { SkyTestBase } from "../../utils/SkyTestBase.sol";

contract SkyAvailableToWithdrawTests is SkyTestBase {

    function setUp() public override {
        super.setUp();

        psm.__setUsdsDepositExchangeRate(1e18);          // 1 USDC  -> 1 USDS
        psm.__setUsdsRedeemExchangeRate(1e18);           // 1 USDS  -> 1 USDC
        savingsUsds.__setSusdsDepositExchangeRate(1e18); // 1 USDS  -> 1 sUSDS
        savingsUsds.__setSusdsRedeemExchangeRate(1e18);  // 1 sUSDS -> 1 USDS
        strategy.__setStrategyDelegateFeeRate(0);        // 0% delegate fee
        strategy.__setStrategyProtocolFeeRate(0);        // 0% protocol fee
    }

    function test_availableToWithdraw_success_psmBuyGemHalted() external {
        psm.__setTout(type(uint256).max);

        strategy.__setFallbackTout(0.25e18);

        setSkyStrategyState({
            lastRecordedTotalAssets_: 0,
            susdsBalance_:            100e18
        });

        setPsmPocketLiquidity(100e6);

        assertEq(strategy.availableToWithdraw(), 0);
    }

    function test_availableToWithdraw_success_zeroPosition() external {
        setPsmPocketLiquidity(100e6);

        assertEq(strategy.availableToWithdraw(), 0);
    }

    function test_availableToWithdraw_success_fullLiquidity_returnsAumNetOfFees() external {
        strategy.__setStrategyDelegateFeeRate(0.02e6);  // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6);  // 3% protocol fee

        savingsUsds.__setSusdsRedeemExchangeRate(2e18);  // 1 sUSDS = 2 USDS (100% yield)

        uint256 lastRecordedTotalAssets = 100e6;
        uint256 susdsBalance            = 100e18;
        uint256 assetsUnderManagement   = 195e6;  // 200e6 current assets - 2e6 delegate fee - 3e6 protocol fee.
        uint256 psmPocketLiquidity      = 300e6;  // PSM pocket liquidity is above the 200e6 strategy position.

        setSkyStrategyState({
            lastRecordedTotalAssets_: lastRecordedTotalAssets,
            susdsBalance_:            susdsBalance
        });

        setPsmPocketLiquidity(psmPocketLiquidity);

        assertEq(strategy.availableToWithdraw(), assetsUnderManagement);
    }

    function test_availableToWithdraw_success_psmPocketLiquidityIsLimiting() external {
        strategy.__setStrategyDelegateFeeRate(0.02e6);  // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6);  // 3% protocol fee

        savingsUsds.__setSusdsRedeemExchangeRate(2e18);  // 1 sUSDS = 2 USDS (100% yield)

        uint256 lastRecordedTotalAssets = 100e6;
        uint256 susdsBalance            = 100e18;
        uint256 psmPocketLiquidity      = 80e6;  // PSM pocket liquidity is the limiting side.
        uint256 expectedAvailable       = 75e6;  // 80e6 gross available - 2e6 delegate fee - 3e6 protocol fee.

        setSkyStrategyState({
            lastRecordedTotalAssets_: lastRecordedTotalAssets,
            susdsBalance_:            susdsBalance
        });

        setPsmPocketLiquidity(psmPocketLiquidity);

        assertEq(strategy.availableToWithdraw(), expectedAvailable);
    }

    function test_availableToWithdraw_success_psmToutConversionIsRespected() external {
        psm.__setTout(0.25e18);  // USDS redemption fee: 20%.

        uint256 lastRecordedTotalAssets = 80e6;
        uint256 susdsBalance            = 100e18;
        uint256 psmPocketLiquidity      = 100e6;
        uint256 expectedAvailable       = 80e6;  // _gemForUsds(100e18) with tout 0.25e18.

        setSkyStrategyState({
            lastRecordedTotalAssets_: lastRecordedTotalAssets,
            susdsBalance_:            susdsBalance
        });

        setPsmPocketLiquidity(psmPocketLiquidity);

        assertEq(strategy.availableToWithdraw(), expectedAvailable);
    }

    function test_availableToWithdraw_success_liquidityEqualToAccruedFees() external {
        strategy.__setStrategyDelegateFeeRate(0.02e6);  // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6);  // 3% protocol fee

        savingsUsds.__setSusdsRedeemExchangeRate(2e18);  // 1 sUSDS = 2 USDS (100% yield)

        uint256 lastRecordedTotalAssets = 100e6;
        uint256 susdsBalance            = 100e18;
        uint256 psmPocketLiquidity      = 5e6;  // Matches total accrued fees.

        setSkyStrategyState({
            lastRecordedTotalAssets_: lastRecordedTotalAssets,
            susdsBalance_:            susdsBalance
        });

        setPsmPocketLiquidity(psmPocketLiquidity);

        assertEq(strategy.availableToWithdraw(), 0);
    }

    function test_availableToWithdraw_success_liquidityLessThanAccruedFees() external {
        strategy.__setStrategyDelegateFeeRate(0.02e6);  // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6);  // 3% protocol fee

        savingsUsds.__setSusdsRedeemExchangeRate(2e18);  // 1 sUSDS = 2 USDS (100% yield)

        uint256 lastRecordedTotalAssets = 100e6;
        uint256 susdsBalance            = 100e18;
        uint256 psmPocketLiquidity      = 4e6;  // Less than the 5e6 total accrued fees.

        setSkyStrategyState({
            lastRecordedTotalAssets_: lastRecordedTotalAssets,
            susdsBalance_:            susdsBalance
        });

        setPsmPocketLiquidity(psmPocketLiquidity);

        assertEq(strategy.availableToWithdraw(), 0);
    }

    function test_availableToWithdraw_success_noYieldReturnsMinimumOfCaps() external {
        strategy.__setStrategyDelegateFeeRate(0.02e6);  // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6);  // 3% protocol fee

        uint256 lastRecordedTotalAssets = 100e6;
        uint256 susdsBalance            = 100e18;
        uint256 psmPocketLiquidity      = 60e6;  // PSM pocket liquidity is the limiting side.

        setSkyStrategyState({
            lastRecordedTotalAssets_: lastRecordedTotalAssets,
            susdsBalance_:            susdsBalance
        });

        setPsmPocketLiquidity(psmPocketLiquidity);

        assertEq(strategy.availableToWithdraw(), psmPocketLiquidity);
    }

    function test_availableToWithdraw_success_lossReturnsMinimumOfCaps() external {
        strategy.__setStrategyDelegateFeeRate(0.02e6);  // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6);  // 3% protocol fee

        savingsUsds.__setSusdsRedeemExchangeRate(0.5e18);  // 1 sUSDS = 0.5 USDS (50% loss)

        uint256 lastRecordedTotalAssets = 100e6;
        uint256 susdsBalance            = 100e18;
        uint256 psmPocketLiquidity      = 40e6;  // PSM pocket liquidity is the limiting side.

        setSkyStrategyState({
            lastRecordedTotalAssets_: lastRecordedTotalAssets,
            susdsBalance_:            susdsBalance
        });

        setPsmPocketLiquidity(psmPocketLiquidity);

        assertEq(strategy.availableToWithdraw(), psmPocketLiquidity);
    }

    function test_availableToWithdraw_success_lossRecognizedReturnsZeroAfterRawPositionAndLiquidityGrow() external {
        uint256 currentTotalAssets = 100e6;  // Strategy holds 100 sUSDS worth 100 assets.
        uint256 susdsBalance       = 100e18; // Strategy holds 100 sUSDS.
        uint256 psmPocketLiquidity = 100e6;  // PSM pocket liquidity can cover the full 100e6 strategy position.

        setSkyStrategyState({
            lastRecordedTotalAssets_: currentTotalAssets,
            susdsBalance_:            susdsBalance
        });

        setPsmPocketLiquidity(psmPocketLiquidity);

        assertSkyStrategy({
            susdsBalance:            susdsBalance,
            lastRecordedTotalAssets: currentTotalAssets,
            assetsUnderManagement:   currentTotalAssets
        });

        assertEq(asset.balanceOf(psmPocket), psmPocketLiquidity);

        vm.prank(strategyDelegate);
        strategy.recognizeLoss();

        savingsUsds.__setSusdsRedeemExchangeRate(2e18); // Raw Sky position grows to 200 assets after final loss recognition.

        uint256 increasedPsmPocketLiquidity = 200e6; // PSM pocket liquidity also grows after final loss recognition.

        setPsmPocketLiquidity(increasedPsmPocketLiquidity);

        assertSkyStrategy({
            susdsBalance:            susdsBalance,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        assertEq(asset.balanceOf(psmPocket), increasedPsmPocketLiquidity);
        assertEq(strategy.availableToWithdraw(), 0);
    }

    function test_availableToWithdraw_success_lossRecognizedReturnsZeroWhenPsmBuyGemHalted() external {
        uint256 currentTotalAssets = 100e6;  // Strategy holds 100 sUSDS worth 100 assets.
        uint256 susdsBalance       = 100e18; // Strategy holds 100 sUSDS.

        setSkyStrategyState({
            lastRecordedTotalAssets_: currentTotalAssets,
            susdsBalance_:            susdsBalance
        });

        vm.prank(strategyDelegate);
        strategy.recognizeLoss();

        // Sky's PSM uses type(uint256).max `tout` to halt the `buyGem` path.
        psm.__setTout(type(uint256).max);

        assertSkyStrategy({
            susdsBalance:            susdsBalance,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        assertEq(strategy.availableToWithdraw(), 0);
    }

    function test_availableToWithdraw_success_maxFeeRateReturnsZero() external {
        strategy.__setStrategyDelegateFeeRate(0.4e6);  // 40% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.6e6);  // 60% protocol fee

        uint256 susdsBalance       = 100e18;
        uint256 psmPocketLiquidity = 100e6;

        setSkyStrategyState({
            lastRecordedTotalAssets_: 0,
            susdsBalance_:            susdsBalance
        });

        setPsmPocketLiquidity(psmPocketLiquidity);

        assertEq(strategy.availableToWithdraw(), 0);
    }

}
