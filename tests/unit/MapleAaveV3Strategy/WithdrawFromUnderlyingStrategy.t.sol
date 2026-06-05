// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MapleAaveV3Strategy } from "../../../contracts/aaveV3/MapleAaveV3Strategy.sol";

import { IMapleAaveV3Strategy } from "../../../contracts/interfaces/IMapleAaveV3Strategy.sol";

import { AaveV3TestBase } from "../../utils/AaveV3TestBase.sol";

contract AaveV3WithdrawFromUnderlyingStrategyFailureTests is AaveV3TestBase {

    function test_withdrawFromUnderlyingStrategy_revert_functionPaused() external {
        globals.__setIsFunctionPaused(MapleAaveV3Strategy.withdrawFromUnderlyingStrategy.selector, true);

        vm.prank(address(strategyManager));
        vm.expectRevert("MAV3S:PAUSED");
        strategy.withdrawFromUnderlyingStrategy(makeAddr("destination"), 1, "");
    }

    function test_withdrawFromUnderlyingStrategy_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(address(strategyManager));
        vm.expectRevert("MAV3S:LOCKED");
        strategy.withdrawFromUnderlyingStrategy(makeAddr("destination"), 1, "");
    }

    function test_withdrawFromUnderlyingStrategy_revert_notStrategyManager() external {
        vm.expectRevert("MAV3S:NOT_STRATEGY_MANAGER");
        strategy.withdrawFromUnderlyingStrategy(makeAddr("destination"), 1, "");
    }

    function test_withdrawFromUnderlyingStrategy_revert_zeroDestination() external {
        vm.prank(address(strategyManager));
        vm.expectRevert("MAV3S:WFUS:ZERO_DESTINATION");
        strategy.withdrawFromUnderlyingStrategy(address(0), 1, "");
    }

    function test_withdrawFromUnderlyingStrategy_revert_zeroAssets() external {
        vm.prank(address(strategyManager));
        vm.expectRevert("MAV3S:WFUS:ZERO_ASSETS");
        strategy.withdrawFromUnderlyingStrategy(makeAddr("destination"), 0, "");
    }

    function test_withdrawFromUnderlyingStrategy_revert_fullWithdrawal_strategyHasYield_withProtocolFees_overWithdrawal() external {
        address destination = makeAddr("destination");

        strategy.__setStrategyDelegateFeeRate(0.02e6);  // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6);  // 3% protocol fee

        uint256 aaveTokenBalanceBeforeWithdraw = 200e6;
        uint256 lastRecordedBeforeWithdraw     = 100e6;
        uint256 currentAumBeforeWithdraw       = 195e6;

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: lastRecordedBeforeWithdraw,
            aaveTokenBalance_:        aaveTokenBalanceBeforeWithdraw
        });

        assertAaveV3Strategy({
            aaveTokenBalance:        aaveTokenBalanceBeforeWithdraw,
            lastRecordedTotalAssets: lastRecordedBeforeWithdraw,
            assetsUnderManagement:   currentAumBeforeWithdraw
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        uint256 withdrawAssets = 196e6;

        vm.prank(address(strategyManager));
        vm.expectRevert("MOCK_AAVE_TOKEN:BURN:INSUFFICIENT_BALANCE");
        strategy.withdrawFromUnderlyingStrategy(destination, withdrawAssets, "");
    }

}

contract AaveV3WithdrawFromUnderlyingStrategySuccessTests is AaveV3TestBase {

    address destination = makeAddr("destination");

    function setUp() public override {
        super.setUp();

        strategy.__setStrategyDelegateFeeRate(0);
        strategy.__setStrategyProtocolFeeRate(0);
    }

    function test_withdrawFromUnderlyingStrategy_success_partialWithdrawal_noYield() external {

        /**********************************************************************************************************************************/
        /*** Step 1: Pre-seed strategy state                                                                                            ***/
        /**********************************************************************************************************************************/

        uint256 aaveTokenBalanceBeforeWithdraw = 100e6;
        uint256 lastRecordedBeforeWithdraw     = 100e6;

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: lastRecordedBeforeWithdraw,
            aaveTokenBalance_:        aaveTokenBalanceBeforeWithdraw
        });

        assertAaveV3Strategy({
            aaveTokenBalance:        aaveTokenBalanceBeforeWithdraw,
            lastRecordedTotalAssets: lastRecordedBeforeWithdraw,
            assetsUnderManagement:   lastRecordedBeforeWithdraw
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        assertEq(asset.balanceOf(destination), 0);

        /**********************************************************************************************************************************/
        /*** Step 2: Execute and assert                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 withdrawAssets                        = 40e6;
        uint256 expectedAaveTokenBalanceAfterWithdraw = 60e6;
        uint256 expectedLastRecordedAfterWithdraw     = 60e6;

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyWithdrawal(destination, withdrawAssets);

        vm.prank(address(strategyManager));
        strategy.withdrawFromUnderlyingStrategy(destination, withdrawAssets, "");

        assertAaveV3Strategy({
            aaveTokenBalance:        expectedAaveTokenBalanceAfterWithdraw,
            lastRecordedTotalAssets: expectedLastRecordedAfterWithdraw,
            assetsUnderManagement:   expectedLastRecordedAfterWithdraw
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        assertEq(asset.balanceOf(destination), withdrawAssets);
    }

    function test_withdrawFromUnderlyingStrategy_success_fullWithdrawal_noYield() external {

        /**********************************************************************************************************************************/
        /*** Step 1: Pre-seed strategy state                                                                                            ***/
        /**********************************************************************************************************************************/

        uint256 aaveTokenBalanceBeforeWithdraw = 100e6;
        uint256 lastRecordedBeforeWithdraw     = 100e6;

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: lastRecordedBeforeWithdraw,
            aaveTokenBalance_:        aaveTokenBalanceBeforeWithdraw
        });

        assertAaveV3Strategy({
            aaveTokenBalance:        aaveTokenBalanceBeforeWithdraw,
            lastRecordedTotalAssets: lastRecordedBeforeWithdraw,
            assetsUnderManagement:   lastRecordedBeforeWithdraw
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        assertEq(asset.balanceOf(destination), 0);

        /**********************************************************************************************************************************/
        /*** Step 2: Execute and assert                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 withdrawAssets = 100e6;

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyWithdrawal(destination, withdrawAssets);

        vm.prank(address(strategyManager));
        strategy.withdrawFromUnderlyingStrategy(destination, withdrawAssets, "");

        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        assertEq(asset.balanceOf(destination), withdrawAssets);
    }

    function test_withdrawFromUnderlyingStrategy_success_partialWithdrawal_strategyHasLoss_withProtocolFees() external {

        /**********************************************************************************************************************************/
        /*** Step 1: Pre-seed strategy state                                                                                            ***/
        /**********************************************************************************************************************************/

        strategy.__setStrategyDelegateFeeRate(0.02e6);  // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6);  // 3% protocol fee

        uint256 aaveTokenBalanceBeforeWithdraw = 80e6;
        uint256 lastRecordedBeforeWithdraw     = 100e6;

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: lastRecordedBeforeWithdraw,
            aaveTokenBalance_:        aaveTokenBalanceBeforeWithdraw
        });

        assertAaveV3Strategy({
            aaveTokenBalance:        aaveTokenBalanceBeforeWithdraw,
            lastRecordedTotalAssets: lastRecordedBeforeWithdraw,
            assetsUnderManagement:   aaveTokenBalanceBeforeWithdraw
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        assertEq(asset.balanceOf(destination), 0);

        /**********************************************************************************************************************************/
        /*** Step 2: Execute and assert                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 withdrawAssets                        = 20e6;
        uint256 expectedAaveTokenBalanceAfterWithdraw = 60e6;
        uint256 expectedLastRecordedAfterWithdraw     = 60e6;

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyFeesCollected(0, 0);

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyWithdrawal(destination, withdrawAssets);

        vm.prank(address(strategyManager));
        strategy.withdrawFromUnderlyingStrategy(destination, withdrawAssets, "");

        assertAaveV3Strategy({
            aaveTokenBalance:        expectedAaveTokenBalanceAfterWithdraw,
            lastRecordedTotalAssets: expectedLastRecordedAfterWithdraw,
            assetsUnderManagement:   expectedLastRecordedAfterWithdraw
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        assertEq(asset.balanceOf(destination), withdrawAssets);
    }

    function test_withdrawFromUnderlyingStrategy_success_partialWithdrawal_strategyHasYield_feesRoundedDownToZero() external {

        /**********************************************************************************************************************************/
        /*** Step 1: Pre-seed strategy state                                                                                            ***/
        /**********************************************************************************************************************************/

        strategy.__setStrategyDelegateFeeRate(0.02e6);  // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6);  // 3% protocol fee

        uint256 lastRecordedBeforeWithdraw     = 100e6;
        uint256 yieldThatRoundsFeesToZero      = 20;
        uint256 aaveTokenBalanceBeforeWithdraw = lastRecordedBeforeWithdraw + yieldThatRoundsFeesToZero;
        uint256 currentAumBeforeWithdraw       = aaveTokenBalanceBeforeWithdraw;

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: lastRecordedBeforeWithdraw,
            aaveTokenBalance_:        aaveTokenBalanceBeforeWithdraw
        });

        assertAaveV3Strategy({
            aaveTokenBalance:        aaveTokenBalanceBeforeWithdraw,
            lastRecordedTotalAssets: lastRecordedBeforeWithdraw,
            assetsUnderManagement:   currentAumBeforeWithdraw
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        assertEq(asset.balanceOf(destination), 0);

        /**********************************************************************************************************************************/
        /*** Step 2: Execute and assert                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 withdrawAssets                        = 40e6;
        uint256 expectedAaveTokenBalanceAfterWithdraw = 60e6 + yieldThatRoundsFeesToZero;
        uint256 expectedLastRecordedAfterWithdraw     = 60e6 + yieldThatRoundsFeesToZero;

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyFeesCollected(0, 0);

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyWithdrawal(destination, withdrawAssets);

        vm.prank(address(strategyManager));
        strategy.withdrawFromUnderlyingStrategy(destination, withdrawAssets, "");

        assertAaveV3Strategy({
            aaveTokenBalance:        expectedAaveTokenBalanceAfterWithdraw,
            lastRecordedTotalAssets: expectedLastRecordedAfterWithdraw,
            assetsUnderManagement:   expectedLastRecordedAfterWithdraw
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        assertEq(asset.balanceOf(destination), withdrawAssets);
    }

    function test_withdrawFromUnderlyingStrategy_success_partialWithdrawal_strategyHasYield_withProtocolFees() external {

        /**********************************************************************************************************************************/
        /*** Step 1: Pre-seed strategy state                                                                                            ***/
        /**********************************************************************************************************************************/

        strategy.__setStrategyDelegateFeeRate(0.02e6);  // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6);  // 3% protocol fee

        uint256 aaveTokenBalanceBeforeWithdraw = 200e6;
        uint256 lastRecordedBeforeWithdraw     = 100e6;
        uint256 currentAumBeforeWithdraw       = 195e6;

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: lastRecordedBeforeWithdraw,
            aaveTokenBalance_:        aaveTokenBalanceBeforeWithdraw
        });

        assertAaveV3Strategy({
            aaveTokenBalance:        aaveTokenBalanceBeforeWithdraw,
            lastRecordedTotalAssets: lastRecordedBeforeWithdraw,
            assetsUnderManagement:   currentAumBeforeWithdraw
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        assertEq(asset.balanceOf(destination), 0);

        /**********************************************************************************************************************************/
        /*** Step 2: Execute and assert                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 withdrawAssets                        = 50e6;
        uint256 expectedDelegateFee                   = 2e6;
        uint256 expectedProtocolFee                   = 3e6;
        uint256 expectedAaveTokenBalanceAfterWithdraw = 145e6;
        uint256 expectedLastRecordedAfterWithdraw     = 145e6;

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyFeesCollected(expectedDelegateFee, expectedProtocolFee);

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyWithdrawal(destination, withdrawAssets);

        vm.prank(address(strategyManager));
        strategy.withdrawFromUnderlyingStrategy(destination, withdrawAssets, "");

        assertAaveV3Strategy({
            aaveTokenBalance:        expectedAaveTokenBalanceAfterWithdraw,
            lastRecordedTotalAssets: expectedLastRecordedAfterWithdraw,
            assetsUnderManagement:   expectedLastRecordedAfterWithdraw
        });

        assertCollectedFees({
            delegateFee: expectedDelegateFee,
            protocolFee: expectedProtocolFee
        });

        assertEq(asset.balanceOf(destination), withdrawAssets);
    }

    function test_withdrawFromUnderlyingStrategy_success_fullWithdrawal_strategyHasYield_withProtocolFees() external {

        /**********************************************************************************************************************************/
        /*** Step 1: Pre-seed strategy state                                                                                            ***/
        /**********************************************************************************************************************************/

        strategy.__setStrategyDelegateFeeRate(0.02e6);  // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6);  // 3% protocol fee

        uint256 aaveTokenBalanceBeforeWithdraw = 200e6;
        uint256 lastRecordedBeforeWithdraw     = 100e6;
        uint256 currentAumBeforeWithdraw       = 195e6;

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: lastRecordedBeforeWithdraw,
            aaveTokenBalance_:        aaveTokenBalanceBeforeWithdraw
        });

        assertAaveV3Strategy({
            aaveTokenBalance:        aaveTokenBalanceBeforeWithdraw,
            lastRecordedTotalAssets: lastRecordedBeforeWithdraw,
            assetsUnderManagement:   currentAumBeforeWithdraw
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        assertEq(asset.balanceOf(destination), 0);

        /**********************************************************************************************************************************/
        /*** Step 2: Execute and assert                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 withdrawAssets      = 195e6;
        uint256 expectedDelegateFee = 2e6;
        uint256 expectedProtocolFee = 3e6;

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyFeesCollected(expectedDelegateFee, expectedProtocolFee);

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyWithdrawal(destination, withdrawAssets);

        vm.prank(address(strategyManager));
        strategy.withdrawFromUnderlyingStrategy(destination, withdrawAssets, "");

        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        assertCollectedFees({
            delegateFee: expectedDelegateFee,
            protocolFee: expectedProtocolFee
        });

        assertEq(asset.balanceOf(destination), withdrawAssets);
    }

    function test_withdrawFromUnderlyingStrategy_success_multipleSequentialWithdrawals() external {

        /**********************************************************************************************************************************/
        /*** Step 1: Pre-seed strategy state                                                                                            ***/
        /**********************************************************************************************************************************/

        uint256 aaveTokenBalanceBeforeFirstWithdraw = 100e6;
        uint256 lastRecordedBeforeFirstWithdraw     = 100e6;

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: lastRecordedBeforeFirstWithdraw,
            aaveTokenBalance_:        aaveTokenBalanceBeforeFirstWithdraw
        });

        assertAaveV3Strategy({
            aaveTokenBalance:        aaveTokenBalanceBeforeFirstWithdraw,
            lastRecordedTotalAssets: lastRecordedBeforeFirstWithdraw,
            assetsUnderManagement:   lastRecordedBeforeFirstWithdraw
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        assertEq(asset.balanceOf(destination), 0);

        /**********************************************************************************************************************************/
        /*** Step 2: Execute first withdrawal                                                                                           ***/
        /**********************************************************************************************************************************/

        uint256 firstWithdrawAssets                 = 40e6;
        uint256 aaveTokenBalanceAfterFirstWithdraw  = 60e6;
        uint256 lastRecordedAfterFirstWithdraw      = 60e6;

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyWithdrawal(destination, firstWithdrawAssets);

        vm.prank(address(strategyManager));
        strategy.withdrawFromUnderlyingStrategy(destination, firstWithdrawAssets, "");

        assertAaveV3Strategy({
            aaveTokenBalance:        aaveTokenBalanceAfterFirstWithdraw,
            lastRecordedTotalAssets: lastRecordedAfterFirstWithdraw,
            assetsUnderManagement:   lastRecordedAfterFirstWithdraw
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        assertEq(asset.balanceOf(destination), firstWithdrawAssets);

        /**********************************************************************************************************************************/
        /*** Step 3: Execute second withdrawal                                                                                          ***/
        /**********************************************************************************************************************************/

        uint256 secondWithdrawAssets                = 20e6;
        uint256 aaveTokenBalanceAfterSecondWithdraw = 40e6;
        uint256 lastRecordedAfterSecondWithdraw     = 40e6;

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyWithdrawal(destination, secondWithdrawAssets);

        vm.prank(address(strategyManager));
        strategy.withdrawFromUnderlyingStrategy(destination, secondWithdrawAssets, "");

        assertAaveV3Strategy({
            aaveTokenBalance:        aaveTokenBalanceAfterSecondWithdraw,
            lastRecordedTotalAssets: lastRecordedAfterSecondWithdraw,
            assetsUnderManagement:   lastRecordedAfterSecondWithdraw
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        assertEq(asset.balanceOf(destination), firstWithdrawAssets + secondWithdrawAssets);
    }

}
