// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleSkyStrategy } from "../../../contracts/interfaces/IMapleSkyStrategy.sol";

import { MapleSkyStrategy } from "../../../contracts/sky/MapleSkyStrategy.sol";

import { SkyTestBase } from "../../utils/SkyTestBase.sol";

contract SkyRecoverPositionFailureTests is SkyTestBase {

    function test_recoverPosition_revert_functionPaused() external {
        globals.__setIsFunctionPaused(MapleSkyStrategy.recoverPosition.selector, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:PAUSED");
        strategy.recoverPosition();
    }

    function test_recoverPosition_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:LOCKED");
        strategy.recoverPosition();
    }

    function test_recoverPosition_revert_notAuthorized() external {
        vm.prank(governor);
        vm.expectRevert("MSS:NOT_AUTHORIZED");
        strategy.recoverPosition();
    }

    function test_recoverPosition_revert_lossNotRecognized() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:RP:LOSS_NOT_RECOGNIZED");
        strategy.recoverPosition();
    }

    function test_recoverPosition_revert_zeroBalance() external {
        strategy.__setIsLossRecognized(true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:RP:ZERO_BALANCE");
        strategy.recoverPosition();
    }

    function test_recoverPosition_revert_transferFailed() external {
        uint256 susdsBalance = 100e18; // Strategy holds 100 sUSDS after final loss recognition.

        strategy.__setIsLossRecognized(true);
        savingsUsds.__setBalanceOf(address(strategy), susdsBalance);
        savingsUsds.__setTransferReverts(true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:RP:TRANSFER_FAILED");
        strategy.recoverPosition();
    }

}

contract SkyRecoverPositionSuccessTests is SkyTestBase {

    function test_recoverPosition_success_strategyDelegate() external {
        uint256 susdsBalance = 100e18; // Strategy holds 100 sUSDS after final loss recognition.

        savingsUsds.__setBalanceOf(address(strategy), susdsBalance);

        vm.prank(strategyDelegate);
        strategy.recognizeLoss();

        assertEq(savingsUsds.balanceOf(mapleTreasury), 0);

        vm.expectEmit();
        emit IMapleSkyStrategy.PositionRecovered(susdsBalance);

        vm.prank(strategyDelegate);
        strategy.recoverPosition();

        assertEq(strategy.isLossRecognized(),          true);
        assertEq(savingsUsds.balanceOf(mapleTreasury), susdsBalance);

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

    function test_recoverPosition_success_operationalAdmin() external {
        uint256 susdsBalance = 100e18; // Strategy holds 100 sUSDS after final loss recognition.

        savingsUsds.__setBalanceOf(address(strategy), susdsBalance);

        vm.prank(operationalAdmin);
        strategy.recognizeLoss();

        assertEq(savingsUsds.balanceOf(mapleTreasury), 0);

        vm.expectEmit();
        emit IMapleSkyStrategy.PositionRecovered(susdsBalance);

        vm.prank(operationalAdmin);
        strategy.recoverPosition();

        assertEq(strategy.isLossRecognized(),          true);
        assertEq(savingsUsds.balanceOf(mapleTreasury), susdsBalance);

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

}
