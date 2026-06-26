// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleAaveV3Strategy } from "../../../contracts/interfaces/IMapleAaveV3Strategy.sol";

import { MapleAaveV3Strategy } from "../../../contracts/aaveV3/MapleAaveV3Strategy.sol";

import { AaveV3TestBase } from "../../utils/AaveV3TestBase.sol";

contract AaveV3RemoveImpairmentFailureTests is AaveV3TestBase {

    function test_removeImpairment_revert_functionPaused() external {
        globals.__setIsFunctionPaused(MapleAaveV3Strategy.removeImpairment.selector, true);

        vm.prank(governor);
        vm.expectRevert("MAV3S:PAUSED");
        strategy.removeImpairment(1);
    }

    function test_removeImpairment_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(governor);
        vm.expectRevert("MAV3S:LOCKED");
        strategy.removeImpairment(1);
    }

    function test_removeImpairment_revert_notAdmin() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:NOT_ADMIN");
        strategy.removeImpairment(1);
    }

    function test_removeImpairment_revert_lossRecognized() external {
        strategy.__setIsLossRecognized(true);

        vm.prank(governor);
        vm.expectRevert("MAV3S:LOSS_RECOGNIZED");
        strategy.removeImpairment(1);
    }

    function test_removeImpairment_revert_zeroUnrealizedLosses() external {
        vm.prank(governor);
        vm.expectRevert("MAV3S:RI:ZERO");
        strategy.removeImpairment(0);
    }

    function test_removeImpairment_revert_exceedsImpairment() external {
        uint256 unrealizedLosses  = 20e6; // Existing unrealized losses are 20 assets.
        uint256 impairmentRemoved = 30e6; // Admin attempts to remove 30 assets of unrealized losses.

        strategy.__setImpairedAssets(unrealizedLosses);

        assertEq(strategy.impairedAssets(), unrealizedLosses);

        vm.prank(governor);
        vm.expectRevert("MAV3S:RI:EXCEEDS_IMPAIRMENT");
        strategy.removeImpairment(impairmentRemoved);
    }

}

contract AaveV3RemoveImpairmentSuccessTests is AaveV3TestBase {

    function test_removeImpairment_success_governor() external {
        uint256 currentTotalAssets       = 100e6; // Strategy holds 100 aTokens worth 100 assets.
        uint256 aaveTokenBalance         = 100e6; // Strategy holds 100 aTokens.
        uint256 initialUnrealizedLosses  = 20e6;  // Existing unrealized losses are 20 assets.
        uint256 impairmentRemoved        = 5e6;   // Admin removes 5 assets of unrealized losses.
        uint256 expectedUnrealizedLosses = 15e6;  // 20 assets of losses - 5 assets removed.

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: currentTotalAssets,
            aaveTokenBalance_:        aaveTokenBalance
        });

        strategy.__setImpairedAssets(initialUnrealizedLosses);

        assertEq(strategy.impairedAssets(),   initialUnrealizedLosses);
        assertEq(strategy.unrealizedLosses(), initialUnrealizedLosses);

        vm.expectEmit();
        emit IMapleAaveV3Strategy.ImpairmentRemoved(impairmentRemoved);

        vm.prank(governor);
        strategy.removeImpairment(impairmentRemoved);

        assertEq(strategy.impairedAssets(),   expectedUnrealizedLosses);
        assertEq(strategy.unrealizedLosses(), expectedUnrealizedLosses);
    }

    function test_removeImpairment_success_operationalAdmin() external {
        uint256 currentTotalAssets       = 100e6; // Strategy holds 100 aTokens worth 100 assets.
        uint256 aaveTokenBalance         = 100e6; // Strategy holds 100 aTokens.
        uint256 initialUnrealizedLosses  = 20e6;  // Existing unrealized losses are 20 assets.
        uint256 impairmentRemoved        = 5e6;   // Admin removes 5 assets of unrealized losses.
        uint256 expectedUnrealizedLosses = 15e6;  // 20 assets of losses - 5 assets removed.

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: currentTotalAssets,
            aaveTokenBalance_:        aaveTokenBalance
        });

        strategy.__setImpairedAssets(initialUnrealizedLosses);

        assertEq(strategy.impairedAssets(),   initialUnrealizedLosses);
        assertEq(strategy.unrealizedLosses(), initialUnrealizedLosses);

        vm.expectEmit();
        emit IMapleAaveV3Strategy.ImpairmentRemoved(impairmentRemoved);

        vm.prank(operationalAdmin);
        strategy.removeImpairment(impairmentRemoved);

        assertEq(strategy.impairedAssets(),   expectedUnrealizedLosses);
        assertEq(strategy.unrealizedLosses(), expectedUnrealizedLosses);
    }

    function test_removeImpairment_success_clearsExistingValue() external {
        uint256 currentTotalAssets = 100e6; // Strategy holds 100 aTokens worth 100 assets.
        uint256 aaveTokenBalance   = 100e6; // Strategy holds 100 aTokens.
        uint256 unrealizedLosses   = 20e6;  // Existing unrealized losses are 20 assets.

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: currentTotalAssets,
            aaveTokenBalance_:        aaveTokenBalance
        });

        strategy.__setImpairedAssets(unrealizedLosses);

        assertEq(strategy.impairedAssets(),   unrealizedLosses);
        assertEq(strategy.unrealizedLosses(), unrealizedLosses);

        vm.expectEmit();
        emit IMapleAaveV3Strategy.ImpairmentRemoved(unrealizedLosses);

        vm.prank(governor);
        strategy.removeImpairment(unrealizedLosses);

        assertEq(strategy.impairedAssets(),   0);
        assertEq(strategy.unrealizedLosses(), 0);
    }

    function test_removeImpairment_success_doesNotChangeAccounting() external {
        uint256 lastRecordedTotalAssets  = 100e6;
        uint256 aaveTokenBalance         = 200e6;
        uint256 aaveLiquidity            = 300e6; // Aave liquidity is above the 200e6 strategy position.
        uint256 expectedAum              = 195e6; // 200e6 current assets - 2e6 delegate fee - 3e6 protocol fee.
        uint256 initialUnrealizedLosses  = 20e6;  // Existing unrealized losses are 20 assets.
        uint256 impairmentRemoved        = 5e6;   // Admin removes 5 assets of unrealized losses.
        uint256 expectedUnrealizedLosses = 15e6;  // 20 assets of losses - 5 assets removed.

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: lastRecordedTotalAssets,
            aaveTokenBalance_:        aaveTokenBalance
        });

        setAaveV3Liquidity(aaveLiquidity);
        strategy.__setImpairedAssets(initialUnrealizedLosses);

        assertEq(strategy.impairedAssets(),      initialUnrealizedLosses);
        assertEq(strategy.unrealizedLosses(),    initialUnrealizedLosses);
        assertEq(strategy.availableToWithdraw(), expectedAum);

        assertAaveV3Strategy({
            aaveTokenBalance:        aaveTokenBalance,
            lastRecordedTotalAssets: lastRecordedTotalAssets,
            assetsUnderManagement:   expectedAum
        });

        vm.expectEmit();
        emit IMapleAaveV3Strategy.ImpairmentRemoved(impairmentRemoved);

        vm.prank(governor);
        strategy.removeImpairment(impairmentRemoved);

        assertEq(strategy.impairedAssets(),      expectedUnrealizedLosses);
        assertEq(strategy.unrealizedLosses(),    expectedUnrealizedLosses);
        assertEq(strategy.availableToWithdraw(), expectedAum);

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        assertAaveV3Strategy({
            aaveTokenBalance:        aaveTokenBalance,
            lastRecordedTotalAssets: lastRecordedTotalAssets,
            assetsUnderManagement:   expectedAum
        });
    }

}
