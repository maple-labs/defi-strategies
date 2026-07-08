// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleAaveV3Strategy } from "../../../contracts/interfaces/IMapleAaveV3Strategy.sol";

import { AaveV3TestBase } from "../../utils/AaveV3TestBase.sol";

contract AaveV3SetUseVirtualUnderlyingBalanceFailureTests is AaveV3TestBase {

    function test_setUseVirtualUnderlyingBalance_revert_functionPaused() external {
        globals.__setIsFunctionPaused(IMapleAaveV3Strategy.setUseVirtualUnderlyingBalance.selector, true);

        vm.prank(governor);
        vm.expectRevert("MAV3S:PAUSED");
        strategy.setUseVirtualUnderlyingBalance(false);
    }

    function test_setUseVirtualUnderlyingBalance_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(governor);
        vm.expectRevert("MAV3S:LOCKED");
        strategy.setUseVirtualUnderlyingBalance(false);
    }

    function test_setUseVirtualUnderlyingBalance_revert_notAdmin() external {
        vm.expectRevert("MAV3S:NOT_ADMIN");
        strategy.setUseVirtualUnderlyingBalance(false);
    }

    function test_setUseVirtualUnderlyingBalance_revert_noChange() external {
        vm.prank(governor);
        vm.expectRevert("MAV3S:SUVUB:NO_CHANGE");
        strategy.setUseVirtualUnderlyingBalance(true);
    }

}

contract AaveV3SetUseVirtualUnderlyingBalanceSuccessTests is AaveV3TestBase {

    function test_setUseVirtualUnderlyingBalance_success_governor() external {
        assertEq(strategy.useVirtualUnderlyingBalance(), true);

        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        vm.expectEmit();
        emit IMapleAaveV3Strategy.UseVirtualUnderlyingBalanceSet(false);

        vm.prank(governor);
        strategy.setUseVirtualUnderlyingBalance(false);

        assertEq(strategy.useVirtualUnderlyingBalance(), false);

        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

    function test_setUseVirtualUnderlyingBalance_success_operationalAdmin() external {
        assertEq(strategy.useVirtualUnderlyingBalance(), true);

        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        vm.expectEmit();
        emit IMapleAaveV3Strategy.UseVirtualUnderlyingBalanceSet(false);

        vm.prank(operationalAdmin);
        strategy.setUseVirtualUnderlyingBalance(false);

        assertEq(strategy.useVirtualUnderlyingBalance(), false);

        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

    function test_setUseVirtualUnderlyingBalance_success_roundTrip() external {
        assertEq(strategy.useVirtualUnderlyingBalance(), true);

        vm.expectEmit();
        emit IMapleAaveV3Strategy.UseVirtualUnderlyingBalanceSet(false);

        vm.prank(governor);
        strategy.setUseVirtualUnderlyingBalance(false);

        assertEq(strategy.useVirtualUnderlyingBalance(), false);

        vm.expectEmit();
        emit IMapleAaveV3Strategy.UseVirtualUnderlyingBalanceSet(true);

        vm.prank(governor);
        strategy.setUseVirtualUnderlyingBalance(true);

        assertEq(strategy.useVirtualUnderlyingBalance(), true);

        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

}
