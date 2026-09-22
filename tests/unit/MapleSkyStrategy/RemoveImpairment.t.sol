// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleSkyStrategy } from "../../../contracts/interfaces/IMapleSkyStrategy.sol";

import { MapleSkyStrategy } from "../../../contracts/sky/MapleSkyStrategy.sol";

import { SkyTestBase } from "../../utils/SkyTestBase.sol";

contract SkyRemoveImpairmentFailureTests is SkyTestBase {

    function test_removeImpairment_revert_functionPaused() external {
        globals.__setIsFunctionPaused(MapleSkyStrategy.removeImpairment.selector, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:PAUSED");
        strategy.removeImpairment(1);
    }

    function test_removeImpairment_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:LOCKED");
        strategy.removeImpairment(1);
    }

    function test_removeImpairment_revert_notAuthorized() external {
        vm.prank(governor);
        vm.expectRevert("MSS:NOT_AUTHORIZED");
        strategy.removeImpairment(1);
    }

    function test_removeImpairment_revert_lossRecognized() external {
        strategy.__setIsLossRecognized(true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:LOSS_RECOGNIZED");
        strategy.removeImpairment(1);
    }

    function test_removeImpairment_revert_zeroUnrealizedLosses() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:RI:ZERO");
        strategy.removeImpairment(0);
    }

    function test_removeImpairment_revert_exceedsImpairment() external {
        uint256 unrealizedLosses  = 20e6; // Existing unrealized losses are 20 assets.
        uint256 impairmentRemoved = 30e6; // Admin attempts to remove 30 assets of unrealized losses.

        strategy.__setImpairedAssets(unrealizedLosses);

        assertEq(strategy.impairedAssets(), unrealizedLosses);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:RI:EXCEEDS_IMPAIRMENT");
        strategy.removeImpairment(impairmentRemoved);
    }

}

contract SkyRemoveImpairmentSuccessTests is SkyTestBase {

    function setUp() public override {
        super.setUp();

        psm.__setUsdsDepositExchangeRate(1e18); // 1 USDC  -> 1 USDS
        psm.__setUsdsRedeemExchangeRate(1e18); // 1 USDS  -> 1 USDC
        savingsUsds.__setSusdsDepositExchangeRate(1e18); // 1 USDS  -> 1 sUSDS
        savingsUsds.__setSusdsRedeemExchangeRate(1e18); // 1 sUSDS -> 1 USDS
    }

    function test_removeImpairment_success_strategyDelegate() external {
        uint256 currentTotalAssets       = 100e6; // Strategy holds 100 sUSDS worth 100 assets.
        uint256 susdsBalance             = 100e18; // Strategy holds 100 sUSDS.
        uint256 initialUnrealizedLosses  = 20e6; // Existing unrealized losses are 20 assets.
        uint256 impairmentRemoved        = 5e6; // Admin removes 5 assets of unrealized losses.
        uint256 expectedUnrealizedLosses = 15e6; // 20 assets of losses - 5 assets removed.

        setSkyStrategyState({
            lastRecordedTotalAssets_: currentTotalAssets,
            susdsBalance_:            susdsBalance
        });

        strategy.__setImpairedAssets(initialUnrealizedLosses);

        assertEq(strategy.impairedAssets(),   initialUnrealizedLosses);
        assertEq(strategy.unrealizedLosses(), initialUnrealizedLosses);

        vm.expectEmit();
        emit IMapleSkyStrategy.ImpairmentRemoved(impairmentRemoved);

        vm.prank(strategyDelegate);
        strategy.removeImpairment(impairmentRemoved);

        assertEq(strategy.impairedAssets(),   expectedUnrealizedLosses);
        assertEq(strategy.unrealizedLosses(), expectedUnrealizedLosses);
    }

    function test_removeImpairment_success_operationalAdmin() external {
        uint256 currentTotalAssets       = 100e6; // Strategy holds 100 sUSDS worth 100 assets.
        uint256 susdsBalance             = 100e18; // Strategy holds 100 sUSDS.
        uint256 initialUnrealizedLosses  = 20e6; // Existing unrealized losses are 20 assets.
        uint256 impairmentRemoved        = 5e6; // Admin removes 5 assets of unrealized losses.
        uint256 expectedUnrealizedLosses = 15e6; // 20 assets of losses - 5 assets removed.

        setSkyStrategyState({
            lastRecordedTotalAssets_: currentTotalAssets,
            susdsBalance_:            susdsBalance
        });

        strategy.__setImpairedAssets(initialUnrealizedLosses);

        assertEq(strategy.impairedAssets(),   initialUnrealizedLosses);
        assertEq(strategy.unrealizedLosses(), initialUnrealizedLosses);

        vm.expectEmit();
        emit IMapleSkyStrategy.ImpairmentRemoved(impairmentRemoved);

        vm.prank(operationalAdmin);
        strategy.removeImpairment(impairmentRemoved);

        assertEq(strategy.impairedAssets(),   expectedUnrealizedLosses);
        assertEq(strategy.unrealizedLosses(), expectedUnrealizedLosses);
    }

    function test_removeImpairment_success_clearsExistingValue() external {
        uint256 currentTotalAssets = 100e6; // Strategy holds 100 sUSDS worth 100 assets.
        uint256 susdsBalance       = 100e18; // Strategy holds 100 sUSDS.
        uint256 unrealizedLosses   = 20e6; // Existing unrealized losses are 20 assets.

        setSkyStrategyState({
            lastRecordedTotalAssets_: currentTotalAssets,
            susdsBalance_:            susdsBalance
        });

        strategy.__setImpairedAssets(unrealizedLosses);

        assertEq(strategy.impairedAssets(),   unrealizedLosses);
        assertEq(strategy.unrealizedLosses(), unrealizedLosses);

        vm.expectEmit();
        emit IMapleSkyStrategy.ImpairmentRemoved(unrealizedLosses);

        vm.prank(strategyDelegate);
        strategy.removeImpairment(unrealizedLosses);

        assertEq(strategy.impairedAssets(),   0);
        assertEq(strategy.unrealizedLosses(), 0);
    }

    function test_removeImpairment_success_doesNotChangeAccounting() external {
        savingsUsds.__setSusdsRedeemExchangeRate(2e18); // 1 sUSDS = 2 USDS (100% yield).

        uint256 lastRecordedTotalAssets  = 100e6;
        uint256 susdsBalance             = 100e18;
        uint256 psmPocketLiquidity       = 300e6; // PSM pocket liquidity is above the 200e6 strategy position.
        uint256 expectedAum              = 195e6; // 200e6 current assets - 2e6 delegate fee - 3e6 protocol fee.
        uint256 initialUnrealizedLosses  = 20e6; // Existing unrealized losses are 20 assets.
        uint256 impairmentRemoved        = 5e6; // Admin removes 5 assets of unrealized losses.
        uint256 expectedUnrealizedLosses = 15e6; // 20 assets of losses - 5 assets removed.

        setSkyStrategyState({
            lastRecordedTotalAssets_: lastRecordedTotalAssets,
            susdsBalance_:            susdsBalance
        });

        setPsmPocketLiquidity(psmPocketLiquidity);
        strategy.__setImpairedAssets(initialUnrealizedLosses);

        assertEq(strategy.impairedAssets(),      initialUnrealizedLosses);
        assertEq(strategy.unrealizedLosses(),    initialUnrealizedLosses);
        assertEq(strategy.availableToWithdraw(), expectedAum);

        assertSkyStrategy({
            susdsBalance:            susdsBalance,
            lastRecordedTotalAssets: lastRecordedTotalAssets,
            assetsUnderManagement:   expectedAum
        });

        vm.expectEmit();
        emit IMapleSkyStrategy.ImpairmentRemoved(impairmentRemoved);

        vm.prank(strategyDelegate);
        strategy.removeImpairment(impairmentRemoved);

        assertEq(strategy.impairedAssets(),      expectedUnrealizedLosses);
        assertEq(strategy.unrealizedLosses(),    expectedUnrealizedLosses);
        assertEq(strategy.availableToWithdraw(), expectedAum);

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        assertSkyStrategy({
            susdsBalance:            susdsBalance,
            lastRecordedTotalAssets: lastRecordedTotalAssets,
            assetsUnderManagement:   expectedAum
        });
    }

}
