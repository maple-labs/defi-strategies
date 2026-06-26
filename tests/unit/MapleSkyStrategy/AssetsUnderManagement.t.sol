// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { SkyTestBase } from "../../utils/SkyTestBase.sol";

contract SkyAssetsUnderManagementTests is SkyTestBase {

    function setUp() public override {
        super.setUp();

        psm.__setUsdsDepositExchangeRate(1e18);          // 1 USDC  -> 1 USDS
        psm.__setUsdsRedeemExchangeRate(1e18);           // 1 USDS  -> 1 USDC
        savingsUsds.__setSusdsDepositExchangeRate(1e18); // 1 USDS  -> 1 sUSDS
        savingsUsds.__setSusdsRedeemExchangeRate(1e18);  // 1 sUSDS -> 1 USDS
        strategy.__setStrategyDelegateFeeRate(0);        // 0% delegate fee
        strategy.__setStrategyProtocolFeeRate(0);        // 0% protocol fee

        // the strategy has no AUM
        assertEq(strategy.assetsUnderManagement(), 0);
    }

    function test_assetsUnderManagement_success_noAccruedFees() external {
        strategy.__setLastRecordedTotalAssets(100e6);
        savingsUsds.__setBalanceOf(address(strategy), 100e18);

        // 100 sUSDS is 100 assets
        assertEq(strategy.assetsUnderManagement(), 100e6);
    }

    function test_assetsUnderManagement_success_directTransfer() external {
        usds.mint(address(this), 100e18);
        usds.approve(address(savingsUsds), 100e18);

        savingsUsds.deposit(100e18, address(this), 0);
        savingsUsds.transfer(address(strategy), 100e18);

        // direct sUSDS transfer still counts as AUM because AUM reads the strategy's sUSDS balance
        assertEq(strategy.assetsUnderManagement(), 100e6);
    }

    function test_assetsUnderManagement_success_strategyHasYield() external {
        strategy.__setStrategyDelegateFeeRate(0.02e6); // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6); // 3% protocol fee

        strategy.__setLastRecordedTotalAssets(100e6);
        savingsUsds.__setBalanceOf(address(strategy), 100e18);

        // before yield 100 sUSDS equals the 100 asset
        assertEq(strategy.assetsUnderManagement(), 100e6);

        savingsUsds.__setSusdsRedeemExchangeRate(2e18); // 1 sUSDS = 2 USDS (100% yield)

        // 100 sUSDS now redeems for 200 assets, and 5% total fees on 100 yield leaves 195 AUM
        assertEq(strategy.assetsUnderManagement(), 195e6);
    }

    function test_assetsUnderManagement_success_strategyHasYieldAndUsdsRedemptionFee() external {
        strategy.__setStrategyDelegateFeeRate(0.02e6); // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6); // 3% protocol fee

        strategy.__setLastRecordedTotalAssets(100e6);
        savingsUsds.__setBalanceOf(address(strategy), 100e18);

        // before yield 100 sUSDS equals the 100 asset
        assertEq(strategy.assetsUnderManagement(), 100e6);

        savingsUsds.__setSusdsRedeemExchangeRate(2e18); // 1 sUSDS = 2 USDS (100% yield)

        // before the PSM fee, 100 yield less 5% total fees leaves 195 AUM
        assertEq(strategy.assetsUnderManagement(), 195e6);

        psm.__setTout(0.25e18); // USDS redemption fee: 20%

        // the USDS redemption fee leaves 160 assets, and 5% total fees on 60 yield leaves 157 AUM
        assertEq(strategy.assetsUnderManagement(), 157e6);
    }

    function test_assetsUnderManagement_success_strategyHasLoss() external {
        strategy.__setLastRecordedTotalAssets(100e6);
        savingsUsds.__setBalanceOf(address(strategy), 100e18);

        // before the loss, the position equals 100 assets
        assertEq(strategy.assetsUnderManagement(), 100e6);

        savingsUsds.__setSusdsRedeemExchangeRate(0.5e18); // 1 sUSDS = 0.5 USDS (50% loss)

        // a 50% redeem rate makes 100 sUSDS worth 50 assets
        assertEq(strategy.assetsUnderManagement(), 50e6);
    }

    function test_assetsUnderManagement_success_strategyHasLossWithFeeRates() external {
        strategy.__setStrategyDelegateFeeRate(0.02e6); // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6); // 3% protocol fee

        strategy.__setLastRecordedTotalAssets(100e6);
        savingsUsds.__setBalanceOf(address(strategy), 100e18);

        // before the loss, the position equals 100 assets
        assertEq(strategy.assetsUnderManagement(), 100e6);

        savingsUsds.__setSusdsRedeemExchangeRate(0.5e18); // 1 sUSDS = 0.5 USDS (50% loss)

        // fee rates do not reduce AUM during a loss because there is no yield to charge
        assertEq(strategy.assetsUnderManagement(), 50e6);
    }

    function test_assetsUnderManagement_success_usdsRedemptionFeeLossWithFeeRates() external {
        strategy.__setStrategyDelegateFeeRate(0.02e6); // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6); // 3% protocol fee

        strategy.__setLastRecordedTotalAssets(100e6);
        savingsUsds.__setBalanceOf(address(strategy), 100e18);

        // before the PSM fee, the position equals 100 assets
        assertEq(strategy.assetsUnderManagement(), 100e6);

        psm.__setTout(0.25e18); // USDS redemption fee: 20%

        // the USDS redemption fee lowers AUM to 80 assets, so fee rates do not apply
        assertEq(strategy.assetsUnderManagement(), 80e6);
    }

    function test_assetsUnderManagement_success_usdsRedemptionFeeWithStrategyLoss() external {
        strategy.__setLastRecordedTotalAssets(100e6);
        savingsUsds.__setBalanceOf(address(strategy), 100e18);

        // before the loss and PSM fee, the position equals the 100 asset
        assertEq(strategy.assetsUnderManagement(), 100e6);

        savingsUsds.__setSusdsRedeemExchangeRate(0.5e18); // 1 sUSDS = 0.5 USDS (50% loss)

        // the 50% sUSDS redeem rate cuts the position to 50 assets before the PSM fee
        assertEq(strategy.assetsUnderManagement(), 50e6);

        psm.__setTout(0.25e18); // USDS redemption fee: 20%

        // the USDS redemption fee reduces 50 assets to 40 assets
        assertEq(strategy.assetsUnderManagement(), 40e6);
    }

    function test_assetsUnderManagement_success_totalLoss() external {
        strategy.__setLastRecordedTotalAssets(100e6);
        savingsUsds.__setBalanceOf(address(strategy), 100e18);

        // before the total loss, the position equals the 100 asset
        assertEq(strategy.assetsUnderManagement(), 100e6);

        savingsUsds.__setSusdsRedeemExchangeRate(0); // 1 sUSDS = 0 USDS (100% loss)

        // 0% redeem rate means the sUSDS position has no recoverable asset value
        assertEq(strategy.assetsUnderManagement(), 0);
    }

    function test_assetsUnderManagement_success_lossRecognizedReturnsZeroAfterRawPositionGrows() external {
        uint256 currentTotalAssets = 100e6;  // Strategy holds 100 sUSDS worth 100 assets.
        uint256 susdsBalance       = 100e18; // Strategy holds 100 sUSDS.

        setSkyStrategyState({
            lastRecordedTotalAssets_: currentTotalAssets,
            susdsBalance_:            susdsBalance
        });

        assertSkyStrategy({
            susdsBalance:            susdsBalance,
            lastRecordedTotalAssets: currentTotalAssets,
            assetsUnderManagement:   currentTotalAssets
        });

        vm.prank(governor);
        strategy.recognizeLoss();

        savingsUsds.__setSusdsRedeemExchangeRate(2e18); // Raw Sky position grows to 200 assets after final loss recognition.

        assertSkyStrategy({
            susdsBalance:            susdsBalance,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

    function test_assetsUnderManagement_success_usdsRedemptionFee() external {
        strategy.__setLastRecordedTotalAssets(100e6);
        savingsUsds.__setBalanceOf(address(strategy), 100e18);

        // before the PSM fee 100 sUSDS equals 100 assets
        assertEq(strategy.assetsUnderManagement(), 100e6);

        psm.__setTout(0.25e18); // USDS redemption fee: 20%

        // the USDS redemption fee reduces 100 assets to 80 assets
        assertEq(strategy.assetsUnderManagement(), 80e6);
    }

    function test_assetsUnderManagement_success_psmHaltedUsesFallbackTout() external {
        psm.__setTout(type(uint256).max); // Sky halts `buyGem` with a max tout

        strategy.__setLastRecordedTotalAssets(100e6);
        savingsUsds.__setBalanceOf(address(strategy), 100e18);

        // AUM stays live during the halt and a zero fallback tout values the position at par
        assertEq(strategy.assetsUnderManagement(), 100e6);
    }

    function test_assetsUnderManagement_success_psmHaltedFallbackToutRedemptionFee() external {
        psm.__setTout(type(uint256).max); // Sky halts `buyGem` with a max tout

        strategy.__setFallbackTout(0.25e18); // USDS redemption fee: 20%

        strategy.__setLastRecordedTotalAssets(100e6);
        savingsUsds.__setBalanceOf(address(strategy), 100e18);

        // the fallback tout reduces the halted position to 80 assets, matching a live tout of 0.25e18
        assertEq(strategy.assetsUnderManagement(), 80e6);
    }

    function test_assetsUnderManagement_success_psmHaltedFallbackToutWithYield() external {
        strategy.__setStrategyDelegateFeeRate(0.02e6); // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6); // 3% protocol fee

        psm.__setTout(type(uint256).max); // Sky halts `buyGem` with a max tout

        strategy.__setLastRecordedTotalAssets(100e6);
        savingsUsds.__setBalanceOf(address(strategy), 100e18);

        savingsUsds.__setSusdsRedeemExchangeRate(2e18); // 1 sUSDS = 2 USDS (100% yield)

        // yield is still valued during the halt and 5% total fees on 100 yield leaves 195 AUM
        assertEq(strategy.assetsUnderManagement(), 195e6);
    }

    function test_assetsUnderManagement_success_psmHaltedFallbackToutWithYieldAndFees() external {
        strategy.__setStrategyDelegateFeeRate(0.02e6); // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6); // 3% protocol fee

        psm.__setTout(type(uint256).max); // Sky halts `buyGem` with a max tout

        strategy.__setFallbackTout(0.25e18); // USDS redemption fee: 20%

        strategy.__setLastRecordedTotalAssets(100e6);
        savingsUsds.__setBalanceOf(address(strategy), 100e18);

        savingsUsds.__setSusdsRedeemExchangeRate(2e18); // 1 sUSDS = 2 USDS (100% yield)

        // the fallback tout discounts the 200 USDS position to 160 assets, and 5% fees on 60 yield leaves 157 AUM
        assertEq(strategy.assetsUnderManagement(), 157e6);
    }

    function test_assetsUnderManagement_success_subtractsBothFeeShares() external {
        strategy.__setStrategyDelegateFeeRate(0.4e6); // 40% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.6e6); // 60% protocol fee

        strategy.__setLastRecordedTotalAssets(100e6);
        savingsUsds.__setBalanceOf(address(strategy), 100e18);

        // before yield, the position equals the 100 asset and there are no fees to subtract
        assertEq(strategy.assetsUnderManagement(), 100e6);

        savingsUsds.__setSusdsRedeemExchangeRate(2e18); // 1 sUSDS = 2 USDS (100% yield)

        // 100 assets of yield is fully consumed by 40% delegate and 60% protocol fees
        assertEq(strategy.assetsUnderManagement(), 100e6);
    }

    function test_assetsUnderManagement_success_maxDelegateFeeRate() external {
        strategy.__setStrategyDelegateFeeRate(1e6); // 100% delegate fee

        savingsUsds.__setBalanceOf(address(strategy), 100e18);

        // all 100 assets are yield and the delegate fee consumes it
        assertEq(strategy.assetsUnderManagement(), 0);
    }

    function test_assetsUnderManagement_success_maxProtocolFeeRate() external {
        strategy.__setStrategyProtocolFeeRate(1e6); // 100% protocol fee

        savingsUsds.__setBalanceOf(address(strategy), 100e18);

        // all 100 assets are yield and the protocol fee consumes it
        assertEq(strategy.assetsUnderManagement(), 0);
    }

    function test_assetsUnderManagement_success_maxSplitFeeRate() external {
        strategy.__setStrategyDelegateFeeRate(0.4e6); // 40% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.6e6); // 60% protocol fee

        savingsUsds.__setBalanceOf(address(strategy), 100e18);

        // all 100 assets are yield and the combined fee consumes it
        assertEq(strategy.assetsUnderManagement(), 0);
    }

}
