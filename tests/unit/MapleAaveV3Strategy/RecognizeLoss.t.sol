// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleAaveV3Strategy } from "../../../contracts/interfaces/IMapleAaveV3Strategy.sol";

import { MapleAaveV3Strategy } from "../../../contracts/aaveV3/MapleAaveV3Strategy.sol";

import { AaveV3TestBase } from "../../utils/AaveV3TestBase.sol";

contract AaveV3RecognizeLossFailureTests is AaveV3TestBase {

    function test_recognizeLoss_revert_functionPaused() external {
        globals.__setIsFunctionPaused(MapleAaveV3Strategy.recognizeLoss.selector, true);

        vm.prank(governor);
        vm.expectRevert("MAV3S:PAUSED");
        strategy.recognizeLoss();
    }

    function test_recognizeLoss_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(governor);
        vm.expectRevert("MAV3S:LOCKED");
        strategy.recognizeLoss();
    }

    function test_recognizeLoss_revert_notAdmin() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:NOT_ADMIN");
        strategy.recognizeLoss();
    }

    function test_recognizeLoss_revert_lossRecognized() external {
        vm.prank(governor);
        strategy.recognizeLoss();

        vm.prank(governor);
        vm.expectRevert("MAV3S:LOSS_RECOGNIZED");
        strategy.recognizeLoss();
    }

}

contract AaveV3RecognizeLossSuccessTests is AaveV3TestBase {

    function test_recognizeLoss_success_governor() external {
        uint256 currentTotalAssets = 100e6; // Strategy holds 100 aTokens worth 100 assets.
        uint256 aaveTokenBalance   = 100e6; // Strategy holds 100 aTokens.
        uint256 unrealizedLosses   = 20e6;  // Strategy has 20 assets of unrealized losses recorded.

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: currentTotalAssets,
            aaveTokenBalance_:        aaveTokenBalance
        });

        setAaveV3Liquidity(currentTotalAssets);
        strategy.__setImpairedAssets(unrealizedLosses);

        assertEq(strategy.isLossRecognized(), false);
        assertEq(strategy.impairedAssets(),   unrealizedLosses);
        assertEq(strategy.unrealizedLosses(), unrealizedLosses);

        assertAaveV3Strategy({
            aaveTokenBalance:        aaveTokenBalance,
            lastRecordedTotalAssets: currentTotalAssets,
            assetsUnderManagement:   currentTotalAssets
        });

        assertEq(strategy.availableToWithdraw(), currentTotalAssets);

        vm.expectEmit();
        emit IMapleAaveV3Strategy.LossRecognized();

        vm.prank(governor);
        strategy.recognizeLoss();

        assertEq(strategy.isLossRecognized(), true);
        assertEq(strategy.impairedAssets(),   0);
        assertEq(strategy.unrealizedLosses(), 0);

        assertAaveV3Strategy({
            aaveTokenBalance:        aaveTokenBalance,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        assertEq(strategy.availableToWithdraw(), 0);
    }

    function test_recognizeLoss_success_operationalAdmin() external {
        uint256 currentTotalAssets = 100e6; // Strategy holds 100 aTokens worth 100 assets.
        uint256 aaveTokenBalance   = 100e6; // Strategy holds 100 aTokens.
        uint256 unrealizedLosses   = 20e6;  // Strategy has 20 assets of unrealized losses recorded.

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: currentTotalAssets,
            aaveTokenBalance_:        aaveTokenBalance
        });

        setAaveV3Liquidity(currentTotalAssets);
        strategy.__setImpairedAssets(unrealizedLosses);

        assertEq(strategy.isLossRecognized(), false);
        assertEq(strategy.impairedAssets(),   unrealizedLosses);
        assertEq(strategy.unrealizedLosses(), unrealizedLosses);

        assertAaveV3Strategy({
            aaveTokenBalance:        aaveTokenBalance,
            lastRecordedTotalAssets: currentTotalAssets,
            assetsUnderManagement:   currentTotalAssets
        });

        assertEq(strategy.availableToWithdraw(), currentTotalAssets);

        vm.expectEmit();
        emit IMapleAaveV3Strategy.LossRecognized();

        vm.prank(operationalAdmin);
        strategy.recognizeLoss();

        assertEq(strategy.isLossRecognized(), true);
        assertEq(strategy.impairedAssets(),   0);
        assertEq(strategy.unrealizedLosses(), 0);

        assertAaveV3Strategy({
            aaveTokenBalance:        aaveTokenBalance,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        assertEq(strategy.availableToWithdraw(), 0);
    }

}
