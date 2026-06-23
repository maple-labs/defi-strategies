// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleSkyStrategy } from "../../../contracts/interfaces/IMapleSkyStrategy.sol";

import { MapleSkyStrategy } from "../../../contracts/sky/MapleSkyStrategy.sol";

import { SkyTestBase } from "../../utils/SkyTestBase.sol";

contract SkyImpairFailureTests is SkyTestBase {

    function test_impair_revert_functionPaused() external {
        globals.__setIsFunctionPaused(MapleSkyStrategy.impair.selector, true);

        vm.prank(governor);
        vm.expectRevert("MSS:PAUSED");
        strategy.impair(1);
    }

    function test_impair_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(governor);
        vm.expectRevert("MSS:LOCKED");
        strategy.impair(1);
    }

    function test_impair_revert_notAdmin() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:NOT_ADMIN");
        strategy.impair(1);
    }

    function test_impair_revert_lossRecognized() external {
        strategy.__setIsLossRecognized(true);

        vm.prank(governor);
        vm.expectRevert("MSS:LOSS_RECOGNIZED");
        strategy.impair(1);
    }

    function test_impair_revert_zeroUnrealizedLosses() external {
        vm.prank(governor);
        vm.expectRevert("MSS:I:ZERO");
        strategy.impair(0);
    }

}

contract SkyImpairSuccessTests is SkyTestBase {

    function setUp() public override {
        super.setUp();

        psm.__setUsdsDepositExchangeRate(1e18);          // 1 USDC  -> 1 USDS
        psm.__setUsdsRedeemExchangeRate(1e18);           // 1 USDS  -> 1 USDC
        savingsUsds.__setSusdsDepositExchangeRate(1e18); // 1 USDS  -> 1 sUSDS
        savingsUsds.__setSusdsRedeemExchangeRate(1e18);  // 1 sUSDS -> 1 USDS
    }

    function test_impair_success_governor() external {
        uint256 currentTotalAssets = 100e6;  // Strategy holds 100 sUSDS worth 100 assets.
        uint256 susdsBalance       = 100e18; // Strategy holds 100 sUSDS.
        uint256 unrealizedLosses   = 20e6;   // Admin records 20 assets of unrealized losses.

        setSkyStrategyState({
            lastRecordedTotalAssets_: currentTotalAssets,
            susdsBalance_:            susdsBalance
        });

        assertEq(strategy.impairedAssets(),   0);
        assertEq(strategy.unrealizedLosses(), 0);

        vm.expectEmit();
        emit IMapleSkyStrategy.Impaired(unrealizedLosses);

        vm.prank(governor);
        strategy.impair(unrealizedLosses);

        assertEq(strategy.impairedAssets(),   unrealizedLosses);
        assertEq(strategy.unrealizedLosses(), unrealizedLosses);
    }

    function test_impair_success_operationalAdmin() external {
        uint256 currentTotalAssets = 100e6;  // Strategy holds 100 sUSDS worth 100 assets.
        uint256 susdsBalance       = 100e18; // Strategy holds 100 sUSDS.
        uint256 unrealizedLosses   = 20e6;   // Admin records 20 assets of unrealized losses.

        setSkyStrategyState({
            lastRecordedTotalAssets_: currentTotalAssets,
            susdsBalance_:            susdsBalance
        });

        assertEq(strategy.impairedAssets(),   0);
        assertEq(strategy.unrealizedLosses(), 0);

        vm.expectEmit();
        emit IMapleSkyStrategy.Impaired(unrealizedLosses);

        vm.prank(operationalAdmin);
        strategy.impair(unrealizedLosses);

        assertEq(strategy.impairedAssets(),   unrealizedLosses);
        assertEq(strategy.unrealizedLosses(), unrealizedLosses);
    }

    function test_impair_success_increasesExistingValue() external {
        uint256 currentTotalAssets         = 100e6;  // Strategy holds 100 sUSDS worth 100 assets.
        uint256 susdsBalance               = 100e18; // Strategy holds 100 sUSDS.
        uint256 initialUnrealizedLosses    = 20e6;   // Existing unrealized losses are 20 assets.
        uint256 additionalUnrealizedLosses = 10e6;   // Admin adds 10 assets of unrealized losses.
        uint256 expectedUnrealizedLosses   = 30e6;   // 20 assets of losses + 10 additional assets.

        setSkyStrategyState({
            lastRecordedTotalAssets_: currentTotalAssets,
            susdsBalance_:            susdsBalance
        });

        strategy.__setImpairedAssets(initialUnrealizedLosses);

        assertEq(strategy.impairedAssets(),   initialUnrealizedLosses);
        assertEq(strategy.unrealizedLosses(), initialUnrealizedLosses);

        vm.expectEmit();
        emit IMapleSkyStrategy.Impaired(additionalUnrealizedLosses);

        vm.prank(governor);
        strategy.impair(additionalUnrealizedLosses);

        assertEq(strategy.impairedAssets(),   expectedUnrealizedLosses);
        assertEq(strategy.unrealizedLosses(), expectedUnrealizedLosses);
    }

    function test_impair_success_allowsExactAssetsUnderManagementWithExistingValue() external {
        uint256 currentTotalAssets         = 100e6;  // Strategy holds 100 sUSDS worth 100 assets.
        uint256 susdsBalance               = 100e18; // Strategy holds 100 sUSDS.
        uint256 initialUnrealizedLosses    = 80e6;   // Existing unrealized losses are 80 assets.
        uint256 additionalUnrealizedLosses = 20e6;   // Admin adds 20 assets of unrealized losses.
        uint256 expectedUnrealizedLosses   = 100e6;  // Total unrealized losses equals 100 assets of AUM.

        setSkyStrategyState({
            lastRecordedTotalAssets_: currentTotalAssets,
            susdsBalance_:            susdsBalance
        });

        strategy.__setImpairedAssets(initialUnrealizedLosses);

        assertEq(strategy.assetsUnderManagement(), currentTotalAssets);
        assertEq(strategy.impairedAssets(),        initialUnrealizedLosses);
        assertEq(strategy.unrealizedLosses(),      initialUnrealizedLosses);

        vm.expectEmit();
        emit IMapleSkyStrategy.Impaired(additionalUnrealizedLosses);

        vm.prank(governor);
        strategy.impair(additionalUnrealizedLosses);

        assertEq(strategy.impairedAssets(),   expectedUnrealizedLosses);
        assertEq(strategy.unrealizedLosses(), expectedUnrealizedLosses);
    }

    function test_impair_success_capsToAssetsUnderManagement() external {
        uint256 currentTotalAssets       = 100e6;  // Strategy holds 100 sUSDS worth 100 assets.
        uint256 susdsBalance             = 100e18; // Strategy holds 100 sUSDS.
        uint256 unrealizedLosses         = 101e6;  // Admin records 101 assets of unrealized losses.
        uint256 excessUnrealizedLosses   = 1e6;    // Unrealized losses exceed current AUM by 1 asset.
        uint256 expectedUnrealizedLosses = 100e6;  // Reported losses are capped by current AUM.

        setSkyStrategyState({
            lastRecordedTotalAssets_: currentTotalAssets,
            susdsBalance_:            susdsBalance
        });

        assertEq(strategy.assetsUnderManagement(), currentTotalAssets);
        assertEq(strategy.impairedAssets(),        0);
        assertEq(strategy.unrealizedLosses(),      0);

        vm.expectEmit();
        emit IMapleSkyStrategy.Impaired(unrealizedLosses);

        vm.prank(governor);
        strategy.impair(unrealizedLosses);

        assertEq(strategy.impairedAssets(),   unrealizedLosses);
        assertEq(strategy.unrealizedLosses(), expectedUnrealizedLosses);

        vm.prank(governor);
        strategy.removeImpairment(excessUnrealizedLosses);

        assertEq(strategy.impairedAssets(),   expectedUnrealizedLosses);
        assertEq(strategy.unrealizedLosses(), expectedUnrealizedLosses);
    }

    function test_impair_success_doesNotChangeAccounting() external {
        savingsUsds.__setSusdsRedeemExchangeRate(2e18); // 1 sUSDS = 2 USDS (100% yield).

        uint256 lastRecordedTotalAssets = 100e6;
        uint256 susdsBalance            = 100e18;
        uint256 psmPocketLiquidity      = 300e6; // PSM pocket liquidity is above the 200e6 strategy position.
        uint256 expectedAum             = 195e6; // 200e6 current assets - 2e6 delegate fee - 3e6 protocol fee.
        uint256 unrealizedLosses        = 20e6;  // Admin records 20 assets of unrealized losses.

        setSkyStrategyState({
            lastRecordedTotalAssets_: lastRecordedTotalAssets,
            susdsBalance_:            susdsBalance
        });

        setPsmPocketLiquidity(psmPocketLiquidity);

        assertEq(strategy.impairedAssets(),      0);
        assertEq(strategy.unrealizedLosses(),    0);
        assertEq(strategy.availableToWithdraw(), expectedAum);

        assertSkyStrategy({
            susdsBalance:            susdsBalance,
            lastRecordedTotalAssets: lastRecordedTotalAssets,
            assetsUnderManagement:   expectedAum
        });

        vm.expectEmit();
        emit IMapleSkyStrategy.Impaired(unrealizedLosses);

        vm.prank(governor);
        strategy.impair(unrealizedLosses);

        assertEq(strategy.impairedAssets(),      unrealizedLosses);
        assertEq(strategy.unrealizedLosses(),    unrealizedLosses);
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

    function test_impair_success_clampsToAssetsUnderManagementWhenAumDrops() external {
        uint256 currentTotalAssets       = 100e6;  // Strategy holds 100 sUSDS worth 100 assets.
        uint256 susdsBalance             = 100e18; // Strategy holds 100 sUSDS.
        uint256 unrealizedLosses         = 80e6;   // Admin records 80 assets of unrealized losses.
        uint256 newRate                  = 0.5e18; // 1 sUSDS = 0.5 USDS (50% loss).
        uint256 expectedAum              = 50e6;   // 100 sUSDS * 0.5 USDS/sUSDS = 50 assets.
        uint256 expectedUnrealizedLosses = 50e6;   // 80 assets of losses capped by 50 assets of AUM.

        setSkyStrategyState({
            lastRecordedTotalAssets_: currentTotalAssets,
            susdsBalance_:            susdsBalance
        });

        assertEq(strategy.impairedAssets(),   0);
        assertEq(strategy.unrealizedLosses(), 0);

        vm.prank(governor);
        strategy.impair(unrealizedLosses);

        assertEq(strategy.impairedAssets(),   unrealizedLosses);
        assertEq(strategy.unrealizedLosses(), unrealizedLosses);

        savingsUsds.__setSusdsRedeemExchangeRate(newRate);

        assertEq(strategy.assetsUnderManagement(), expectedAum);
        assertEq(strategy.impairedAssets(),        unrealizedLosses);
        assertEq(strategy.unrealizedLosses(),      expectedUnrealizedLosses);
    }

}
