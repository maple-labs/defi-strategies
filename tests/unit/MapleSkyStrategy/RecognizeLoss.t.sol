// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleSkyStrategy } from "../../../contracts/interfaces/IMapleSkyStrategy.sol";

import { MapleSkyStrategy } from "../../../contracts/sky/MapleSkyStrategy.sol";

import { SkyTestBase } from "../../utils/SkyTestBase.sol";

contract SkyRecognizeLossFailureTests is SkyTestBase {

    function test_recognizeLoss_revert_functionPaused() external {
        globals.__setIsFunctionPaused(MapleSkyStrategy.recognizeLoss.selector, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:PAUSED");
        strategy.recognizeLoss();
    }

    function test_recognizeLoss_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:LOCKED");
        strategy.recognizeLoss();
    }

    function test_recognizeLoss_revert_notAuthorized() external {
        vm.prank(governor);
        vm.expectRevert("MSS:NOT_AUTHORIZED");
        strategy.recognizeLoss();
    }

    function test_recognizeLoss_revert_lossRecognized() external {
        vm.prank(strategyDelegate);
        strategy.recognizeLoss();

        vm.prank(strategyDelegate);
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

    function test_recognizeLoss_success_strategyDelegate() external {
        uint256 currentTotalAssets = 100e6;  // Strategy holds 100 sUSDS worth 100 assets.
        uint256 susdsBalance       = 100e18; // Strategy holds 100 sUSDS.
        uint256 unrealizedLosses   = 20e6;   // Strategy has 20 assets of unrealized losses recorded.

        setSkyStrategyState({
            lastRecordedTotalAssets_: currentTotalAssets,
            susdsBalance_:            susdsBalance
        });

        setPsmPocketLiquidity(currentTotalAssets);
        strategy.__setImpairedAssets(unrealizedLosses);

        assertEq(strategy.isLossRecognized(), false);
        assertEq(strategy.impairedAssets(),   unrealizedLosses);
        assertEq(strategy.unrealizedLosses(), unrealizedLosses);

        assertSkyStrategy({
            susdsBalance:            susdsBalance,
            lastRecordedTotalAssets: currentTotalAssets,
            assetsUnderManagement:   currentTotalAssets
        });

        assertEq(strategy.availableToWithdraw(), currentTotalAssets);

        vm.expectEmit();
        emit IMapleSkyStrategy.LossRecognized();

        vm.prank(strategyDelegate);
        strategy.recognizeLoss();

        assertEq(strategy.isLossRecognized(), true);
        assertEq(strategy.impairedAssets(),   0);
        assertEq(strategy.unrealizedLosses(), 0);

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
        uint256 unrealizedLosses   = 20e6;   // Strategy has 20 assets of unrealized losses recorded.

        setSkyStrategyState({
            lastRecordedTotalAssets_: currentTotalAssets,
            susdsBalance_:            susdsBalance
        });

        setPsmPocketLiquidity(currentTotalAssets);
        strategy.__setImpairedAssets(unrealizedLosses);

        assertEq(strategy.isLossRecognized(), false);
        assertEq(strategy.impairedAssets(),   unrealizedLosses);
        assertEq(strategy.unrealizedLosses(), unrealizedLosses);

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
        assertEq(strategy.impairedAssets(),   0);
        assertEq(strategy.unrealizedLosses(), 0);

        assertSkyStrategy({
            susdsBalance:            susdsBalance,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        assertEq(strategy.availableToWithdraw(), 0);
    }

}
