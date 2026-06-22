// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleSkyStrategy } from "../../../contracts/interfaces/IMapleSkyStrategy.sol";

import { MapleSkyStrategy } from "../../../contracts/sky/MapleSkyStrategy.sol";

import { SkyTestBase } from "../../utils/SkyTestBase.sol";

contract SkyRecognizeLossFailureTests is SkyTestBase {

    function test_recognizeLoss_revert_functionPaused() external {
        globals.__setIsFunctionPaused(MapleSkyStrategy.recognizeLoss.selector, true);

        vm.prank(governor);
        vm.expectRevert("MSS:PAUSED");
        strategy.recognizeLoss();
    }

    function test_recognizeLoss_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(governor);
        vm.expectRevert("MSS:LOCKED");
        strategy.recognizeLoss();
    }

    function test_recognizeLoss_revert_notAdmin() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:NOT_ADMIN");
        strategy.recognizeLoss();
    }

    function test_recognizeLoss_revert_lossRecognized() external {
        vm.prank(governor);
        strategy.recognizeLoss();

        vm.prank(governor);
        vm.expectRevert("MSS:LOSS_RECOGNIZED");
        strategy.recognizeLoss();
    }

}

contract SkyRecognizeLossSuccessTests is SkyTestBase {

    function setUp() public override {
        super.setUp();

        psm.__setUsdsDepositExchangeRate(1e18);          // 1 USDC  -> 1 USDS
        psm.__setUsdsRedeemExchangeRate(1e18);           // 1 USDS  -> 1 USDC
        savingsUsds.__setSusdsDepositExchangeRate(1e18); // 1 USDS  -> 1 sUSDS
        savingsUsds.__setSusdsRedeemExchangeRate(1e18);  // 1 sUSDS -> 1 USDS
    }

    function test_recognizeLoss_success_governor() external {
        uint256 currentTotalAssets = 100e6;  // Strategy holds 100 sUSDS worth 100 assets.
        uint256 susdsBalance       = 100e18; // Strategy holds 100 sUSDS.

        setSkyStrategyState({
            lastRecordedTotalAssets_: currentTotalAssets,
            susdsBalance_:            susdsBalance
        });

        setPsmPocketLiquidity(currentTotalAssets);

        assertEq(strategy.isLossRecognized(), false);

        assertSkyStrategy({
            susdsBalance:            susdsBalance,
            lastRecordedTotalAssets: currentTotalAssets,
            assetsUnderManagement:   currentTotalAssets
        });

        assertEq(strategy.availableToWithdraw(), currentTotalAssets);

        vm.expectEmit();
        emit IMapleSkyStrategy.LossRecognized();

        vm.prank(governor);
        strategy.recognizeLoss();

        assertEq(strategy.isLossRecognized(), true);

        assertSkyStrategy({
            susdsBalance:            susdsBalance,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        assertEq(strategy.availableToWithdraw(), 0);
    }

    function test_recognizeLoss_success_operationalAdmin() external {
        uint256 currentTotalAssets = 100e6;  // Strategy holds 100 sUSDS worth 100 assets.
        uint256 susdsBalance       = 100e18; // Strategy holds 100 sUSDS.

        setSkyStrategyState({
            lastRecordedTotalAssets_: currentTotalAssets,
            susdsBalance_:            susdsBalance
        });

        setPsmPocketLiquidity(currentTotalAssets);

        assertEq(strategy.isLossRecognized(), false);

        assertSkyStrategy({
            susdsBalance:            susdsBalance,
            lastRecordedTotalAssets: currentTotalAssets,
            assetsUnderManagement:   currentTotalAssets
        });

        assertEq(strategy.availableToWithdraw(), currentTotalAssets);

        vm.expectEmit();
        emit IMapleSkyStrategy.LossRecognized();

        vm.prank(operationalAdmin);
        strategy.recognizeLoss();

        assertEq(strategy.isLossRecognized(), true);

        assertSkyStrategy({
            susdsBalance:            susdsBalance,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        assertEq(strategy.availableToWithdraw(), 0);
    }

    function test_recognizeLoss_success_viewsStayZeroAfterRawPositionGrows() external {
        uint256 currentTotalAssets = 100e6;  // Strategy holds 100 sUSDS worth 100 assets.
        uint256 susdsBalance       = 100e18; // Strategy holds 100 sUSDS.

        setSkyStrategyState({
            lastRecordedTotalAssets_: currentTotalAssets,
            susdsBalance_:            susdsBalance
        });

        vm.prank(governor);
        strategy.recognizeLoss();

        savingsUsds.__setSusdsRedeemExchangeRate(2e18); // Raw Sky position grows to 200 assets after final loss recognition.
        setPsmPocketLiquidity(200e6);

        assertSkyStrategy({
            susdsBalance:            susdsBalance,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        assertEq(strategy.availableToWithdraw(), 0);
    }

    function test_recognizeLoss_success_availableToWithdrawReturnsZeroWhenPsmBuyGemHalted() external {
        uint256 currentTotalAssets = 100e6;  // Strategy holds 100 sUSDS worth 100 assets.
        uint256 susdsBalance       = 100e18; // Strategy holds 100 sUSDS.

        setSkyStrategyState({
            lastRecordedTotalAssets_: currentTotalAssets,
            susdsBalance_:            susdsBalance
        });

        vm.prank(governor);
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

    function test_recognizeLoss_success_feeRateSetterDoesNotCollectFeesOrReviveAum() external {
        uint32 strategyProtocolFeeRate = 0.04e6; // New 4% protocol fee.

        uint256 currentTotalAssets = 100e6;  // Strategy holds 100 sUSDS worth 100 assets.
        uint256 susdsBalance       = 100e18; // Strategy holds 100 sUSDS.

        setSkyStrategyState({
            lastRecordedTotalAssets_: currentTotalAssets,
            susdsBalance_:            susdsBalance
        });

        vm.prank(governor);
        strategy.recognizeLoss();

        savingsUsds.__setSusdsRedeemExchangeRate(2e18); // Raw Sky position grows to 200 assets after final loss recognition.
        setPsmPocketLiquidity(200e6);

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyFeesCollected(0, 0);

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyProtocolFeeRateSet(strategyProtocolFeeRate);

        vm.prank(governor);
        strategy.setStrategyProtocolFeeRate(strategyProtocolFeeRate);

        assertEq(strategy.strategyProtocolFeeRate(), strategyProtocolFeeRate);

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        assertSkyStrategy({
            susdsBalance:            susdsBalance,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

}
