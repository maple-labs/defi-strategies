// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleAaveV3Strategy } from "../../../contracts/interfaces/IMapleAaveV3Strategy.sol";

import { MapleAaveV3Strategy } from "../../../contracts/aaveV3/MapleAaveV3Strategy.sol";

import { AaveV3TestBase } from "../../utils/AaveV3TestBase.sol";

contract AaveV3RecoverPositionFailureTests is AaveV3TestBase {

    function test_recoverPosition_revert_functionPaused() external {
        globals.__setIsFunctionPaused(MapleAaveV3Strategy.recoverPosition.selector, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:PAUSED");
        strategy.recoverPosition();
    }

    function test_recoverPosition_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:LOCKED");
        strategy.recoverPosition();
    }

    function test_recoverPosition_revert_notAuthorized() external {
        vm.prank(governor);
        vm.expectRevert("MAV3S:NOT_AUTHORIZED");
        strategy.recoverPosition();
    }

    function test_recoverPosition_revert_lossNotRecognized() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:RP:LOSS_NOT_RECOGNIZED");
        strategy.recoverPosition();
    }

    function test_recoverPosition_revert_zeroBalance() external {
        strategy.__setIsLossRecognized(true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:RP:ZERO_BALANCE");
        strategy.recoverPosition();
    }

    function test_recoverPosition_revert_transferFailed() external {
        uint256 aaveTokenBalance = 100e6; // Strategy holds 100 aTokens after final loss recognition.

        strategy.__setIsLossRecognized(true);
        setStrategyATokenBalance(aaveTokenBalance);
        aaveToken.__setTransferReverts(true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:RP:TRANSFER_FAILED");
        strategy.recoverPosition();
    }

}

contract AaveV3RecoverPositionSuccessTests is AaveV3TestBase {

    function test_recoverPosition_success_strategyDelegate() external {
        uint256 aaveTokenBalance = 100e6; // Strategy holds 100 aTokens after final loss recognition.

        setStrategyATokenBalance(aaveTokenBalance);

        vm.prank(strategyDelegate);
        strategy.recognizeLoss();

        assertEq(aaveToken.balanceOf(mapleTreasury), 0);

        vm.expectEmit();
        emit IMapleAaveV3Strategy.PositionRecovered(aaveTokenBalance);

        vm.prank(strategyDelegate);
        strategy.recoverPosition();

        assertEq(strategy.isLossRecognized(),        true);
        assertEq(aaveToken.balanceOf(mapleTreasury), aaveTokenBalance);

        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

    function test_recoverPosition_success_operationalAdmin() external {
        uint256 aaveTokenBalance = 100e6; // Strategy holds 100 aTokens after final loss recognition.

        setStrategyATokenBalance(aaveTokenBalance);

        vm.prank(operationalAdmin);
        strategy.recognizeLoss();

        assertEq(aaveToken.balanceOf(mapleTreasury), 0);

        vm.expectEmit();
        emit IMapleAaveV3Strategy.PositionRecovered(aaveTokenBalance);

        vm.prank(operationalAdmin);
        strategy.recoverPosition();

        assertEq(strategy.isLossRecognized(),        true);
        assertEq(aaveToken.balanceOf(mapleTreasury), aaveTokenBalance);

        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

}
