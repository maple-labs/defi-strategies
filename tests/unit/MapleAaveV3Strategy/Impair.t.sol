// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleAaveV3Strategy } from "../../../contracts/interfaces/IMapleAaveV3Strategy.sol";

import { MapleAaveV3Strategy } from "../../../contracts/aaveV3/MapleAaveV3Strategy.sol";

import { AaveV3TestBase } from "../../utils/AaveV3TestBase.sol";

contract AaveV3ImpairFailureTests is AaveV3TestBase {

    function test_impair_revert_functionPaused() external {
        globals.__setIsFunctionPaused(MapleAaveV3Strategy.impair.selector, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:PAUSED");
        strategy.impair(1);
    }

    function test_impair_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:LOCKED");
        strategy.impair(1);
    }

    function test_impair_revert_notAuthorized() external {
        vm.prank(governor);
        vm.expectRevert("MAV3S:NOT_AUTHORIZED");
        strategy.impair(1);
    }

    function test_impair_revert_lossRecognized() external {
        strategy.__setIsLossRecognized(true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:LOSS_RECOGNIZED");
        strategy.impair(1);
    }

    function test_impair_revert_zeroUnrealizedLosses() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:I:ZERO");
        strategy.impair(0);
    }

}

contract AaveV3ImpairSuccessTests is AaveV3TestBase {

    function test_impair_success_strategyDelegate() external {
        uint256 currentTotalAssets = 100e6; // Strategy holds 100 aTokens worth 100 assets.
        uint256 aaveTokenBalance   = 100e6; // Strategy holds 100 aTokens.
        uint256 unrealizedLosses   = 20e6; // Admin records 20 assets of unrealized losses.

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: currentTotalAssets,
            aaveTokenBalance_:        aaveTokenBalance
        });

        assertEq(strategy.impairedAssets(),   0);
        assertEq(strategy.unrealizedLosses(), 0);

        vm.expectEmit();
        emit IMapleAaveV3Strategy.Impaired(unrealizedLosses);

        vm.prank(strategyDelegate);
        strategy.impair(unrealizedLosses);

        assertEq(strategy.impairedAssets(),   unrealizedLosses);
        assertEq(strategy.unrealizedLosses(), unrealizedLosses);
    }

    function test_impair_success_operationalAdmin() external {
        uint256 currentTotalAssets = 100e6; // Strategy holds 100 aTokens worth 100 assets.
        uint256 aaveTokenBalance   = 100e6; // Strategy holds 100 aTokens.
        uint256 unrealizedLosses   = 20e6; // Admin records 20 assets of unrealized losses.

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: currentTotalAssets,
            aaveTokenBalance_:        aaveTokenBalance
        });

        assertEq(strategy.impairedAssets(),   0);
        assertEq(strategy.unrealizedLosses(), 0);

        vm.expectEmit();
        emit IMapleAaveV3Strategy.Impaired(unrealizedLosses);

        vm.prank(operationalAdmin);
        strategy.impair(unrealizedLosses);

        assertEq(strategy.impairedAssets(),   unrealizedLosses);
        assertEq(strategy.unrealizedLosses(), unrealizedLosses);
    }

    function test_impair_success_increasesExistingValue() external {
        uint256 currentTotalAssets         = 100e6; // Strategy holds 100 aTokens worth 100 assets.
        uint256 aaveTokenBalance           = 100e6; // Strategy holds 100 aTokens.
        uint256 initialUnrealizedLosses    = 20e6; // Existing unrealized losses are 20 assets.
        uint256 additionalUnrealizedLosses = 10e6; // Admin adds 10 assets of unrealized losses.
        uint256 expectedUnrealizedLosses   = 30e6; // 20 assets of losses + 10 additional assets.

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: currentTotalAssets,
            aaveTokenBalance_:        aaveTokenBalance
        });

        strategy.__setImpairedAssets(initialUnrealizedLosses);

        assertEq(strategy.impairedAssets(),   initialUnrealizedLosses);
        assertEq(strategy.unrealizedLosses(), initialUnrealizedLosses);

        vm.expectEmit();
        emit IMapleAaveV3Strategy.Impaired(additionalUnrealizedLosses);

        vm.prank(strategyDelegate);
        strategy.impair(additionalUnrealizedLosses);

        assertEq(strategy.impairedAssets(),   expectedUnrealizedLosses);
        assertEq(strategy.unrealizedLosses(), expectedUnrealizedLosses);
    }

    function test_impair_success_allowsExactAssetsUnderManagementWithExistingValue() external {
        uint256 currentTotalAssets         = 100e6; // Strategy holds 100 aTokens worth 100 assets.
        uint256 aaveTokenBalance           = 100e6; // Strategy holds 100 aTokens.
        uint256 initialUnrealizedLosses    = 80e6; // Existing unrealized losses are 80 assets.
        uint256 additionalUnrealizedLosses = 20e6; // Admin adds 20 assets of unrealized losses.
        uint256 expectedUnrealizedLosses   = 100e6; // Total unrealized losses equals 100 assets of AUM.

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: currentTotalAssets,
            aaveTokenBalance_:        aaveTokenBalance
        });

        strategy.__setImpairedAssets(initialUnrealizedLosses);

        assertEq(strategy.assetsUnderManagement(), currentTotalAssets);
        assertEq(strategy.impairedAssets(),        initialUnrealizedLosses);
        assertEq(strategy.unrealizedLosses(),      initialUnrealizedLosses);

        vm.expectEmit();
        emit IMapleAaveV3Strategy.Impaired(additionalUnrealizedLosses);

        vm.prank(strategyDelegate);
        strategy.impair(additionalUnrealizedLosses);

        assertEq(strategy.impairedAssets(),   expectedUnrealizedLosses);
        assertEq(strategy.unrealizedLosses(), expectedUnrealizedLosses);
    }

    function test_impair_success_capsToAssetsUnderManagement() external {
        uint256 currentTotalAssets       = 100e6; // Strategy holds 100 aTokens worth 100 assets.
        uint256 aaveTokenBalance         = 100e6; // Strategy holds 100 aTokens.
        uint256 unrealizedLosses         = 101e6; // Admin records 101 assets of unrealized losses.
        uint256 excessUnrealizedLosses   = 1e6; // Unrealized losses exceed current AUM by 1 asset.
        uint256 expectedUnrealizedLosses = 100e6; // Reported losses are capped by current AUM.

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: currentTotalAssets,
            aaveTokenBalance_:        aaveTokenBalance
        });

        assertEq(strategy.assetsUnderManagement(), currentTotalAssets);
        assertEq(strategy.impairedAssets(),        0);
        assertEq(strategy.unrealizedLosses(),      0);

        vm.expectEmit();
        emit IMapleAaveV3Strategy.Impaired(unrealizedLosses);

        vm.prank(strategyDelegate);
        strategy.impair(unrealizedLosses);

        assertEq(strategy.impairedAssets(),   unrealizedLosses);
        assertEq(strategy.unrealizedLosses(), expectedUnrealizedLosses);

        vm.prank(strategyDelegate);
        strategy.removeImpairment(excessUnrealizedLosses);

        assertEq(strategy.impairedAssets(),   expectedUnrealizedLosses);
        assertEq(strategy.unrealizedLosses(), expectedUnrealizedLosses);
    }

    function test_impair_success_doesNotChangeAccounting() external {
        uint256 lastRecordedTotalAssets = 100e6;
        uint256 aaveTokenBalance        = 200e6;
        uint256 aaveLiquidity           = 300e6; // Aave liquidity is above the 200e6 strategy position.
        uint256 expectedAum             = 195e6; // 200e6 current assets - 2e6 delegate fee - 3e6 protocol fee.
        uint256 unrealizedLosses        = 20e6; // Admin records 20 assets of unrealized losses.

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: lastRecordedTotalAssets,
            aaveTokenBalance_:        aaveTokenBalance
        });

        setAaveV3Liquidity(aaveLiquidity);

        assertEq(strategy.impairedAssets(),      0);
        assertEq(strategy.unrealizedLosses(),    0);
        assertEq(strategy.availableToWithdraw(), expectedAum);

        assertAaveV3Strategy({
            aaveTokenBalance:        aaveTokenBalance,
            lastRecordedTotalAssets: lastRecordedTotalAssets,
            assetsUnderManagement:   expectedAum
        });

        vm.expectEmit();
        emit IMapleAaveV3Strategy.Impaired(unrealizedLosses);

        vm.prank(strategyDelegate);
        strategy.impair(unrealizedLosses);

        assertEq(strategy.impairedAssets(),      unrealizedLosses);
        assertEq(strategy.unrealizedLosses(),    unrealizedLosses);
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

    function test_impair_success_clampsToAssetsUnderManagementWhenAumDrops() external {
        uint256 currentTotalAssets       = 100e6; // Strategy holds 100 aTokens worth 100 assets.
        uint256 aaveTokenBalance         = 100e6; // Strategy holds 100 aTokens.
        uint256 unrealizedLosses         = 80e6; // Admin records 80 assets of unrealized losses.
        uint256 expectedAum              = 50e6; // Strategy position drops to 50 assets.
        uint256 expectedUnrealizedLosses = 50e6; // 80 assets of losses capped by 50 assets of AUM.

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: currentTotalAssets,
            aaveTokenBalance_:        aaveTokenBalance
        });

        assertEq(strategy.impairedAssets(),   0);
        assertEq(strategy.unrealizedLosses(), 0);

        vm.prank(strategyDelegate);
        strategy.impair(unrealizedLosses);

        assertEq(strategy.impairedAssets(),   unrealizedLosses);
        assertEq(strategy.unrealizedLosses(), unrealizedLosses);

        setStrategyATokenBalance(expectedAum);

        assertEq(strategy.assetsUnderManagement(), expectedAum);
        assertEq(strategy.impairedAssets(),        unrealizedLosses);
        assertEq(strategy.unrealizedLosses(),      expectedUnrealizedLosses);
    }

}
