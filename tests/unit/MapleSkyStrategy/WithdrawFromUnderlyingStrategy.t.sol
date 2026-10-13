// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MapleSkyStrategy } from "../../../contracts/sky/MapleSkyStrategy.sol";

import { IMapleSkyStrategy } from "../../../contracts/interfaces/IMapleSkyStrategy.sol";

import { SkyTestBase } from "../../utils/SkyTestBase.sol";

contract WithdrawFromUnderlyingStrategyFailureTests is SkyTestBase {

    function test_withdrawFromUnderlyingStrategy_revert_functionPaused() external {
        globals.__setIsFunctionPaused(MapleSkyStrategy.withdrawFromUnderlyingStrategy.selector, true);

        vm.prank(address(strategyManager));
        vm.expectRevert("MSS:PAUSED");
        strategy.withdrawFromUnderlyingStrategy(makeAddr("destination"), 1, "");
    }

    function test_withdrawFromUnderlyingStrategy_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(address(strategyManager));
        vm.expectRevert("MSS:LOCKED");
        strategy.withdrawFromUnderlyingStrategy(makeAddr("destination"), 1, "");
    }

    function test_withdrawFromUnderlyingStrategy_revert_notStrategyManager() external {
        vm.expectRevert("MSS:NOT_STRATEGY_MANAGER");
        strategy.withdrawFromUnderlyingStrategy(makeAddr("destination"), 1, "");
    }

    function test_withdrawFromUnderlyingStrategy_revert_lossRecognized() external {
        strategy.__setIsLossRecognized(true);

        vm.prank(address(strategyManager));
        vm.expectRevert("MSS:LOSS_RECOGNIZED");
        strategy.withdrawFromUnderlyingStrategy(address(this), 1, "");
    }

    function test_withdrawFromUnderlyingStrategy_revert_zeroDestination() external {
        vm.prank(address(strategyManager));
        vm.expectRevert("MSS:WFUS:ZERO_DESTINATION");
        strategy.withdrawFromUnderlyingStrategy(address(0), 1, "");
    }

    function test_withdrawFromUnderlyingStrategy_revert_zeroAssets() external {
        vm.prank(address(strategyManager));
        vm.expectRevert("MSS:WFUS:ZERO_ASSETS");
        strategy.withdrawFromUnderlyingStrategy(makeAddr("destination"), 0, "");
    }

    function test_withdrawFromUnderlyingStrategy_revert_usdsApproveFail() external {
        savingsUsds.__setSusdsRedeemExchangeRate(1e18);
        savingsUsds.__setBalanceOf(address(strategy), 1e18);
        usds.mint(address(savingsUsds), 1e18);

        usds.__setApproveReverts(address(psm), true);

        vm.prank(address(strategyManager));
        vm.expectRevert("MSS:HAW:USDS_APPROVE_FAIL");
        strategy.withdrawFromUnderlyingStrategy(makeAddr("destination"), 1, "");
    }

    function test_withdrawFromUnderlyingStrategy_revert_delegateTransferFailure() external {
        strategy.__setStrategyDelegateFeeRate(0.02e6);
        strategy.__setStrategyProtocolFeeRate(0);

        savingsUsds.__setSusdsRedeemExchangeRate(1e18);
        psm.__setUsdsRedeemExchangeRate(1e18);

        setSkyStrategyState({
            lastRecordedTotalAssets_: 100e6,
            susdsBalance_:            200e18
        });

        asset.__setTransferReverts(true);

        vm.prank(address(strategyManager));
        vm.expectRevert("MSS:HAW:DELEGATE_TRANSFER_FAIL");
        strategy.withdrawFromUnderlyingStrategy(makeAddr("destination"), 50e6, "");
    }

    function test_withdrawFromUnderlyingStrategy_revert_protocolTransferFailure() external {
        strategy.__setStrategyDelegateFeeRate(0);
        strategy.__setStrategyProtocolFeeRate(0.03e6);

        savingsUsds.__setSusdsRedeemExchangeRate(1e18);
        psm.__setUsdsRedeemExchangeRate(1e18);

        setSkyStrategyState({
            lastRecordedTotalAssets_: 100e6,
            susdsBalance_:            200e18
        });

        asset.__setTransferReverts(true);

        vm.prank(address(strategyManager));
        vm.expectRevert("MSS:HAW:PROTOCOL_TRANSFER_FAIL");
        strategy.withdrawFromUnderlyingStrategy(makeAddr("destination"), 50e6, "");
    }

    function test_withdrawFromUnderlyingStrategy_revert_assetTransferFailure() external {
        strategy.__setStrategyDelegateFeeRate(0);
        strategy.__setStrategyProtocolFeeRate(0);

        savingsUsds.__setSusdsRedeemExchangeRate(1e18);
        psm.__setUsdsRedeemExchangeRate(1e18);

        setSkyStrategyState({
            lastRecordedTotalAssets_: 100e6,
            susdsBalance_:            200e18
        });

        asset.__setTransferReverts(true);

        vm.prank(address(strategyManager));
        vm.expectRevert("MSS:HAW:ASSET_TRANSFER_FAIL");
        strategy.withdrawFromUnderlyingStrategy(makeAddr("destination"), 50e6, "");
    }

}

contract WithdrawFromUnderlyingStrategySuccessTests is SkyTestBase {

    address destination = makeAddr("destination");

    function setUp() public override {
        super.setUp();

        strategy.__setStrategyDelegateFeeRate(0);
        strategy.__setStrategyProtocolFeeRate(0);

        psm.__setUsdsDepositExchangeRate(1e18);
        psm.__setUsdsRedeemExchangeRate(1e18);
        savingsUsds.__setSusdsDepositExchangeRate(1e18);
        savingsUsds.__setSusdsRedeemExchangeRate(1e18);
    }

    function test_withdrawFromUnderlyingStrategy_success_partialWithdrawal_noYield() external {
        /**********************************************************************************************************************************/
        /*** Step 1: Pre-seed strategy state                                                                                            ***/
        /**********************************************************************************************************************************/

        uint256 susdsBalanceBeforeWithdraw = 100e18;
        uint256 lastRecordedBeforeWithdraw = 100e6;

        setSkyStrategyState({
            lastRecordedTotalAssets_: lastRecordedBeforeWithdraw,
            susdsBalance_:            susdsBalanceBeforeWithdraw
        });

        assertSkyStrategy({
            susdsBalance:            susdsBalanceBeforeWithdraw,
            lastRecordedTotalAssets: lastRecordedBeforeWithdraw,
            assetsUnderManagement:   lastRecordedBeforeWithdraw
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        assertEq(asset.balanceOf(destination), 0);

        /**********************************************************************************************************************************/
        /*** Step 2: Execute and assert                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 withdrawAssets                    = 40e6;
        uint256 expectedSharesBurned              = 40e18;
        uint256 expectedSusdsBalanceAfterWithdraw = 60e18;
        uint256 expectedLastRecordedAfterWithdraw = 60e6;

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyWithdrawal(destination, expectedSharesBurned, withdrawAssets);

        vm.prank(address(strategyManager));
        strategy.withdrawFromUnderlyingStrategy(destination, withdrawAssets, "");

        assertSkyStrategy({
            susdsBalance:            expectedSusdsBalanceAfterWithdraw,
            lastRecordedTotalAssets: expectedLastRecordedAfterWithdraw,
            assetsUnderManagement:   expectedLastRecordedAfterWithdraw
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        assertEq(asset.balanceOf(destination), withdrawAssets);
    }

    function test_withdrawFromUnderlyingStrategy_success_fullWithdrawal_noYield() external {
        /**********************************************************************************************************************************/
        /*** Step 1: Pre-seed strategy state                                                                                            ***/
        /**********************************************************************************************************************************/

        uint256 susdsBalanceBeforeWithdraw = 100e18;
        uint256 lastRecordedBeforeWithdraw = 100e6;

        setSkyStrategyState({
            lastRecordedTotalAssets_: lastRecordedBeforeWithdraw,
            susdsBalance_:            susdsBalanceBeforeWithdraw
        });

        assertSkyStrategy({
            susdsBalance:            susdsBalanceBeforeWithdraw,
            lastRecordedTotalAssets: lastRecordedBeforeWithdraw,
            assetsUnderManagement:   lastRecordedBeforeWithdraw
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        assertEq(asset.balanceOf(destination), 0);

        /**********************************************************************************************************************************/
        /*** Step 2: Execute and assert                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 withdrawAssets       = 100e6;
        uint256 expectedSharesBurned = 100e18;

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyWithdrawal(destination, expectedSharesBurned, withdrawAssets);

        vm.prank(address(strategyManager));
        strategy.withdrawFromUnderlyingStrategy(destination, withdrawAssets, "");

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        assertEq(asset.balanceOf(destination), withdrawAssets);
    }

    function test_withdrawFromUnderlyingStrategy_success_partialWithdrawal_usdsHasRedemptionFee() external {
        /**********************************************************************************************************************************/
        /*** Step 1: Pre-seed strategy state                                                                                            ***/
        /**********************************************************************************************************************************/

        psm.__setTout(0.25e18); // PSM tout = 0.25 (20% USDS redemption fee)
        psm.__setUsdsRedeemExchangeRate(1.25e18); // 1 + tout (mock buyGem doesn't apply tout itself)

        uint256 susdsBalanceBeforeWithdraw = 100e18; // 100 sUSDS
        uint256 lastRecordedBeforeWithdraw = 80e6; // 100 USDS / 1.25 = 80 USDC AUM net of tout

        setSkyStrategyState({
            lastRecordedTotalAssets_: lastRecordedBeforeWithdraw,
            susdsBalance_:            susdsBalanceBeforeWithdraw
        });

        assertSkyStrategy({
            susdsBalance:            susdsBalanceBeforeWithdraw,
            lastRecordedTotalAssets: lastRecordedBeforeWithdraw,
            assetsUnderManagement:   lastRecordedBeforeWithdraw
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        assertEq(asset.balanceOf(destination), 0);

        /**********************************************************************************************************************************/
        /*** Step 2: Execute and assert                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 withdrawAssets                    = 20e6;
        uint256 expectedSharesBurned              = 25e18; // 20 USDC × 1.25 tout multiplier = 25 USDS / 1.0 sUSDS rate
        uint256 expectedSusdsBalanceAfterWithdraw = 75e18; // 100 (existing) - 25 (burnt: 20 USDC × 1.25 tout multiplier = 25 USDS)
        uint256 expectedLastRecordedAfterWithdraw = 60e6; // 75 USDS / 1.25 = 60 USDC AUM net of tout

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyWithdrawal(destination, expectedSharesBurned, withdrawAssets);

        vm.prank(address(strategyManager));
        strategy.withdrawFromUnderlyingStrategy(destination, withdrawAssets, "");

        assertSkyStrategy({
            susdsBalance:            expectedSusdsBalanceAfterWithdraw,
            lastRecordedTotalAssets: expectedLastRecordedAfterWithdraw,
            assetsUnderManagement:   expectedLastRecordedAfterWithdraw
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        assertEq(asset.balanceOf(destination), withdrawAssets);
    }

    function test_withdrawFromUnderlyingStrategy_success_partialWithdrawal_susdsHasRedemptionFee() external {
        /**********************************************************************************************************************************/
        /*** Step 1: Pre-seed strategy state                                                                                            ***/
        /**********************************************************************************************************************************/

        savingsUsds.__setSusdsRedeemExchangeRate(0.8e18); // sUSDS redemption fee: 20%

        uint256 susdsBalanceBeforeWithdraw = 200e18; // 200 sUSDS
        uint256 lastRecordedBeforeWithdraw = 160e6; // 200 sUSDS × 0.8 = 160 USDS = 160 USDC AUM

        setSkyStrategyState({
            lastRecordedTotalAssets_: lastRecordedBeforeWithdraw,
            susdsBalance_:            susdsBalanceBeforeWithdraw
        });

        assertSkyStrategy({
            susdsBalance:            susdsBalanceBeforeWithdraw,
            lastRecordedTotalAssets: lastRecordedBeforeWithdraw,
            assetsUnderManagement:   lastRecordedBeforeWithdraw
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        assertEq(asset.balanceOf(destination), 0);

        /**********************************************************************************************************************************/
        /*** Step 2: Execute and assert                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 withdrawAssets                    = 40e6;
        uint256 expectedSharesBurned              = 50e18; // 40 USDS / 0.8 sUSDS rate
        uint256 expectedSusdsBalanceAfterWithdraw = 150e18; // 200 (existing) - 50 (burnt: 40 USDS / 0.8 rate)
        uint256 expectedLastRecordedAfterWithdraw = 120e6; // 150 sUSDS × 0.8 = 120 USDS = 120 USDC AUM

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyWithdrawal(destination, expectedSharesBurned, withdrawAssets);

        vm.prank(address(strategyManager));
        strategy.withdrawFromUnderlyingStrategy(destination, withdrawAssets, "");

        assertSkyStrategy({
            susdsBalance:            expectedSusdsBalanceAfterWithdraw,
            lastRecordedTotalAssets: expectedLastRecordedAfterWithdraw,
            assetsUnderManagement:   expectedLastRecordedAfterWithdraw
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        assertEq(asset.balanceOf(destination), withdrawAssets);
    }

    function test_withdrawFromUnderlyingStrategy_success_partialWithdrawal_susdsRedemptionFeeStacksWithUsdsRedemptionFee() external {
        /**********************************************************************************************************************************/
        /*** Step 1: Pre-seed strategy state                                                                                            ***/
        /**********************************************************************************************************************************/

        savingsUsds.__setSusdsRedeemExchangeRate(0.6e18); // sUSDS redemption fee: 40%
        psm.__setTout(0.2e18); // PSM tout = 0.2 (~16.67% USDS redemption fee)
        psm.__setUsdsRedeemExchangeRate(1.2e18); // 1 + tout (mock buyGem doesn't apply tout itself)

        uint256 susdsBalanceBeforeWithdraw = 200e18; // 200 sUSDS
        uint256 lastRecordedBeforeWithdraw = 100e6; // 200 × 0.6 = 120 USDS / 1.2 = 100 USDC AUM (both fees)

        setSkyStrategyState({
            lastRecordedTotalAssets_: lastRecordedBeforeWithdraw,
            susdsBalance_:            susdsBalanceBeforeWithdraw
        });

        assertSkyStrategy({
            susdsBalance:            susdsBalanceBeforeWithdraw,
            lastRecordedTotalAssets: lastRecordedBeforeWithdraw,
            assetsUnderManagement:   lastRecordedBeforeWithdraw
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        assertEq(asset.balanceOf(destination), 0);

        /**********************************************************************************************************************************/
        /*** Step 2: Execute and assert                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 withdrawAssets                    = 40e6;
        uint256 expectedSharesBurned              = 80e18; // 40 USDC × 1.2 tout multiplier = 48 USDS / 0.6 sUSDS rate
        uint256 expectedSusdsBalanceAfterWithdraw = 120e18; // 200 (existing) - 80 (burnt: 40 × 1.2 / 0.6 = 80)
        uint256 expectedLastRecordedAfterWithdraw = 60e6; // 120 × 0.6 = 72 USDS / 1.2 = 60 USDC AUM

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyWithdrawal(destination, expectedSharesBurned, withdrawAssets);

        vm.prank(address(strategyManager));
        strategy.withdrawFromUnderlyingStrategy(destination, withdrawAssets, "");

        assertSkyStrategy({
            susdsBalance:            expectedSusdsBalanceAfterWithdraw,
            lastRecordedTotalAssets: expectedLastRecordedAfterWithdraw,
            assetsUnderManagement:   expectedLastRecordedAfterWithdraw
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        assertEq(asset.balanceOf(destination), withdrawAssets);
    }

    function test_withdrawFromUnderlyingStrategy_success_partialWithdrawal_susdsHasLoss() external {
        /**********************************************************************************************************************************/
        /*** Step 1: Pre-seed strategy state                                                                                            ***/
        /**********************************************************************************************************************************/

        savingsUsds.__setSusdsRedeemExchangeRate(0.8e18); // sUSDS dropped 20% post-funding

        uint256 susdsBalanceBeforeWithdraw = 100e18; // 100 sUSDS
        uint256 lastRecordedBeforeWithdraw = 100e6; // baseline from funding (when rate was 1.0)
        uint256 currentAumBeforeWithdraw   = 80e6; // 100 sUSDS × 0.8 = 80 USDS = 80 USDC (loss-gate → no fees)

        setSkyStrategyState({
            lastRecordedTotalAssets_: lastRecordedBeforeWithdraw,
            susdsBalance_:            susdsBalanceBeforeWithdraw
        });

        assertSkyStrategy({
            susdsBalance:            susdsBalanceBeforeWithdraw,
            lastRecordedTotalAssets: lastRecordedBeforeWithdraw,
            assetsUnderManagement:   currentAumBeforeWithdraw
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        assertEq(asset.balanceOf(destination), 0);

        /**********************************************************************************************************************************/
        /*** Step 2: Execute and assert                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 withdrawAssets                    = 20e6;
        uint256 expectedSharesBurned              = 25e18; // 20 USDS / 0.8 sUSDS rate
        uint256 expectedSusdsBalanceAfterWithdraw = 75e18; // 100 (existing) - 25 (burnt: 20 USDS / 0.8 rate)
        uint256 expectedLastRecordedAfterWithdraw = 60e6; // 75 sUSDS × 0.8 = 60 USDS = 60 USDC (baseline catches up post-loss)

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyWithdrawal(destination, expectedSharesBurned, withdrawAssets);

        vm.prank(address(strategyManager));
        strategy.withdrawFromUnderlyingStrategy(destination, withdrawAssets, "");

        assertSkyStrategy({
            susdsBalance:            expectedSusdsBalanceAfterWithdraw,
            lastRecordedTotalAssets: expectedLastRecordedAfterWithdraw,
            assetsUnderManagement:   expectedLastRecordedAfterWithdraw
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        assertEq(asset.balanceOf(destination), withdrawAssets);
    }

    function test_withdrawFromUnderlyingStrategy_success_partialWithdrawal_strategyHasYield_withProtocolFees() external {
        /**********************************************************************************************************************************/
        /*** Step 1: Pre-seed strategy state                                                                                            ***/
        /**********************************************************************************************************************************/

        strategy.__setStrategyDelegateFeeRate(0.02e6); // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6); // 3% protocol fee
        savingsUsds.__setSusdsRedeemExchangeRate(2e18); // 1 sUSDS = 2 USDS (100% yield)

        uint256 susdsBalanceBeforeWithdraw = 100e18; // 100 sUSDS
        uint256 lastRecordedBeforeWithdraw = 100e6; // baseline from funding (when rate was 1.0)
        uint256 currentAumBeforeWithdraw   = 195e6; // 200 currentTotal - 5 (2 + 3 accrued fees on 100 yield)

        setSkyStrategyState({
            lastRecordedTotalAssets_: lastRecordedBeforeWithdraw,
            susdsBalance_:            susdsBalanceBeforeWithdraw
        });

        assertSkyStrategy({
            susdsBalance:            susdsBalanceBeforeWithdraw,
            lastRecordedTotalAssets: lastRecordedBeforeWithdraw,
            assetsUnderManagement:   currentAumBeforeWithdraw
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        assertEq(asset.balanceOf(destination), 0);

        /**********************************************************************************************************************************/
        /*** Step 2: Execute and assert                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 withdrawAssets                    = 50e6;
        uint256 expectedDelegateFee               = 2e6; // 100 yield × 2%
        uint256 expectedProtocolFee               = 3e6; // 100 yield × 3%
        uint256 expectedSharesBurned              = 27.5e18; // (50 withdrawn + 5 fees) USDS / 2.0 sUSDS rate
        uint256 expectedSusdsBalanceAfterWithdraw = 72.5e18; // 100 (existing) - 2.5 (burnt for 5 USDC fees) - 25 (burnt for 50 USDC)
        uint256 expectedLastRecordedAfterWithdraw = 145e6; // 72.5 sUSDS × 2.0 = 145 USDS = 145 USDC

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyFeesCollected(expectedDelegateFee, expectedProtocolFee);

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyWithdrawal(destination, expectedSharesBurned, withdrawAssets);

        vm.prank(address(strategyManager));
        strategy.withdrawFromUnderlyingStrategy(destination, withdrawAssets, "");

        assertSkyStrategy({
            susdsBalance:            expectedSusdsBalanceAfterWithdraw,
            lastRecordedTotalAssets: expectedLastRecordedAfterWithdraw,
            assetsUnderManagement:   expectedLastRecordedAfterWithdraw
        });

        assertCollectedFees({
            delegateFee: expectedDelegateFee,
            protocolFee: expectedProtocolFee
        });

        assertEq(asset.balanceOf(destination), withdrawAssets);
    }

    function test_withdrawFromUnderlyingStrategy_success_partialWithdrawal_usdsRedemptionFeeDecreased_phantomYield() external {
        /**********************************************************************************************************************************/
        /*** Step 1: Pre-seed strategy state                                                                                            ***/
        /**********************************************************************************************************************************/

        strategy.__setStrategyDelegateFeeRate(0.02e6); // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6); // 3% protocol fee

        uint256 susdsBalanceBeforeWithdraw = 1000e18; // 1000 sUSDS
        uint256 lastRecordedBeforeWithdraw = 800e6; // funded at PSM tout = 0.25 / 20% USDS redemption fee (1000 USDS / 1.25 = 800)
        uint256 currentAumBeforeWithdraw   = 990e6; // tout dropped to 0 → 1000 currentTotal - 10 (4 + 6 fees on 200 phantom yield)

        setSkyStrategyState({
            lastRecordedTotalAssets_: lastRecordedBeforeWithdraw,
            susdsBalance_:            susdsBalanceBeforeWithdraw
        });

        assertSkyStrategy({
            susdsBalance:            susdsBalanceBeforeWithdraw,
            lastRecordedTotalAssets: lastRecordedBeforeWithdraw,
            assetsUnderManagement:   currentAumBeforeWithdraw
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        assertEq(asset.balanceOf(destination), 0);

        /**********************************************************************************************************************************/
        /*** Step 2: Execute and assert                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 withdrawAssets                    = 200e6;
        uint256 expectedDelegateFee               = 4e6; // 200 phantom yield × 2%
        uint256 expectedProtocolFee               = 6e6; // 200 phantom yield × 3%
        uint256 expectedSharesBurned              = 210e18; // (200 withdrawn + 10 fees) USDS / 1.0 sUSDS rate
        uint256 expectedSusdsBalanceAfterWithdraw = 790e18; // 1000 (existing) - 10 (burnt for fees) - 200 (burnt for user withdraw)
        uint256 expectedLastRecordedAfterWithdraw = 790e6; // 790 sUSDS × 1.0 = 790 USDS = 790 USDC

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyFeesCollected(expectedDelegateFee, expectedProtocolFee);

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyWithdrawal(destination, expectedSharesBurned, withdrawAssets);

        vm.prank(address(strategyManager));
        strategy.withdrawFromUnderlyingStrategy(destination, withdrawAssets, "");

        assertSkyStrategy({
            susdsBalance:            expectedSusdsBalanceAfterWithdraw,
            lastRecordedTotalAssets: expectedLastRecordedAfterWithdraw,
            assetsUnderManagement:   expectedLastRecordedAfterWithdraw
        });

        assertCollectedFees({
            delegateFee: expectedDelegateFee,
            protocolFee: expectedProtocolFee
        });

        assertEq(asset.balanceOf(destination), withdrawAssets);
    }

    function test_withdrawFromUnderlyingStrategy_success_multipleSequentialWithdrawals() external {
        /**********************************************************************************************************************************/
        /*** Step 1: Pre-seed strategy state                                                                                            ***/
        /**********************************************************************************************************************************/

        uint256 susdsBalanceBeforeFirstWithdraw = 100e18; // 100 sUSDS
        uint256 lastRecordedBeforeFirstWithdraw = 100e6; // 100 USDC AUM at 1:1 rate, no fees

        setSkyStrategyState({
            lastRecordedTotalAssets_: lastRecordedBeforeFirstWithdraw,
            susdsBalance_:            susdsBalanceBeforeFirstWithdraw
        });

        assertSkyStrategy({
            susdsBalance:            susdsBalanceBeforeFirstWithdraw,
            lastRecordedTotalAssets: lastRecordedBeforeFirstWithdraw,
            assetsUnderManagement:   lastRecordedBeforeFirstWithdraw
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        assertEq(asset.balanceOf(destination), 0);

        /**********************************************************************************************************************************/
        /*** Step 2: Execute first withdrawal                                                                                           ***/
        /**********************************************************************************************************************************/

        uint256 firstWithdrawAssets            = 40e6;
        uint256 firstWithdrawSharesBurned      = 40e18;
        uint256 susdsBalanceAfterFirstWithdraw = 60e18; // 100 - 40
        uint256 lastRecordedAfterFirstWithdraw = 60e6; // 60 sUSDS × 1.0 = 60 USDC

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyWithdrawal(destination, firstWithdrawSharesBurned, firstWithdrawAssets);

        vm.prank(address(strategyManager));
        strategy.withdrawFromUnderlyingStrategy(destination, firstWithdrawAssets, "");

        assertSkyStrategy({
            susdsBalance:            susdsBalanceAfterFirstWithdraw,
            lastRecordedTotalAssets: lastRecordedAfterFirstWithdraw,
            assetsUnderManagement:   lastRecordedAfterFirstWithdraw
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        assertEq(asset.balanceOf(destination), firstWithdrawAssets);

        /**********************************************************************************************************************************/
        /*** Step 3: Execute second withdrawal                                                                                          ***/
        /**********************************************************************************************************************************/

        uint256 secondWithdrawAssets            = 20e6;
        uint256 secondWithdrawSharesBurned      = 20e18;
        uint256 susdsBalanceAfterSecondWithdraw = 40e18; // 60 - 20
        uint256 lastRecordedAfterSecondWithdraw = 40e6; // 40 sUSDS × 1.0 = 40 USDC

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyWithdrawal(destination, secondWithdrawSharesBurned, secondWithdrawAssets);

        vm.prank(address(strategyManager));
        strategy.withdrawFromUnderlyingStrategy(destination, secondWithdrawAssets, "");

        assertSkyStrategy({
            susdsBalance:            susdsBalanceAfterSecondWithdraw,
            lastRecordedTotalAssets: lastRecordedAfterSecondWithdraw,
            assetsUnderManagement:   lastRecordedAfterSecondWithdraw
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        assertEq(asset.balanceOf(destination), firstWithdrawAssets + secondWithdrawAssets);
    }

    function test_withdrawFromUnderlyingStrategy_success_fullWithdrawal_strategyHasYield_withProtocolFees_usdsHasRedemptionFee() external {
        /**********************************************************************************************************************************/
        /*** Step 1: Pre-seed strategy state                                                                                            ***/
        /**********************************************************************************************************************************/

        strategy.__setStrategyDelegateFeeRate(0.02e6); // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6); // 3% protocol fee

        psm.__setTout(0.25e18); // PSM tout = 0.25 (20% USDS redemption fee)
        psm.__setUsdsRedeemExchangeRate(1.25e18); // 1 + tout (mock buyGem doesn't apply tout itself)
        savingsUsds.__setSusdsRedeemExchangeRate(2e18); // 1 sUSDS = 2 USDS (100% yield)

        uint256 susdsBalanceBeforeWithdraw = 250e18; // 250 sUSDS
        uint256 lastRecordedBeforeWithdraw = 200e6; // funded at tout = 0.25, rate = 1.0 (250 sUSDS × 1.0 / 1.25 = 200 USDC)
        uint256 currentAumBeforeWithdraw   = 390e6; // (250 × 2.0) / 1.25 = 400 currentTotal - 10 (4 + 6 fees on 200 yield)

        setSkyStrategyState({
            lastRecordedTotalAssets_: lastRecordedBeforeWithdraw,
            susdsBalance_:            susdsBalanceBeforeWithdraw
        });

        assertSkyStrategy({
            susdsBalance:            susdsBalanceBeforeWithdraw,
            lastRecordedTotalAssets: lastRecordedBeforeWithdraw,
            assetsUnderManagement:   currentAumBeforeWithdraw
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        assertEq(asset.balanceOf(destination), 0);

        /**********************************************************************************************************************************/
        /*** Step 2: Execute and assert                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 withdrawAssets       = 390e6;
        uint256 expectedDelegateFee  = 4e6; // 200 yield × 2%
        uint256 expectedProtocolFee  = 6e6; // 200 yield × 3%
        uint256 expectedSharesBurned = 250e18; // (390 withdrawn + 10 fees) USDC × 1.25 tout multiplier = 500 USDS / 2.0 sUSDS rate

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyFeesCollected(expectedDelegateFee, expectedProtocolFee);

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyWithdrawal(destination, expectedSharesBurned, withdrawAssets);

        vm.prank(address(strategyManager));
        strategy.withdrawFromUnderlyingStrategy(destination, withdrawAssets, "");

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        assertCollectedFees({
            delegateFee: expectedDelegateFee,
            protocolFee: expectedProtocolFee
        });

        assertEq(asset.balanceOf(destination), withdrawAssets);
    }

}
