// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MapleAaveV3Strategy } from "../../../contracts/aaveV3/MapleAaveV3Strategy.sol";

import { IAavePoolLike }        from "../../../contracts/interfaces/Interfaces.sol";
import { IMapleAaveV3Strategy } from "../../../contracts/interfaces/IMapleAaveV3Strategy.sol";

import { AaveV3TestBase } from "../../utils/AaveV3TestBase.sol";

contract AaveV3SetStrategyDelegateFeeRateFailureTests is AaveV3TestBase {

    function setUp() public override {
        super.setUp();

        strategy.__setStrategyDelegateFeeRate(0);  // 0% delegate fee
        strategy.__setStrategyProtocolFeeRate(0);  // 0% protocol fee
    }

    function test_setStrategyDelegateFeeRate_revert_functionPaused() external {
        uint32 strategyDelegateFeeRate_ = 0.04e6;  // 4% delegate fee

        globals.__setIsFunctionPaused(MapleAaveV3Strategy.setStrategyDelegateFeeRate.selector, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:PAUSED");
        strategy.setStrategyDelegateFeeRate(strategyDelegateFeeRate_);
    }

    function test_setStrategyDelegateFeeRate_revert_reentrancy() external {
        uint32 strategyDelegateFeeRate_ = 0.04e6;  // 4% delegate fee

        strategy.__setLocked(2);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:LOCKED");
        strategy.setStrategyDelegateFeeRate(strategyDelegateFeeRate_);
    }

    function test_setStrategyDelegateFeeRate_revert_notStrategyDelegate() external {
        uint32 strategyDelegateFeeRate_ = 0.04e6;  // 4% delegate fee

        vm.expectRevert("MAV3S:SSDFR:NOT_STRATEGY_DELEGATE");
        strategy.setStrategyDelegateFeeRate(strategyDelegateFeeRate_);
    }

    function test_setStrategyDelegateFeeRate_revert_lossRecognized() external {
        uint32 strategyDelegateFeeRate_ = 0.04e6;  // 4% delegate fee

        strategy.__setIsLossRecognized(true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:LOSS_RECOGNIZED");
        strategy.setStrategyDelegateFeeRate(strategyDelegateFeeRate_);
    }

    function test_setStrategyDelegateFeeRate_revert_noChange() external {
        uint32 strategyDelegateFeeRate_ = 0.04e6;  // 4% delegate fee
        uint32 strategyProtocolFeeRate_ = 0.03e6;  // 3% protocol fee

        strategy.__setStrategyDelegateFeeRate(strategyDelegateFeeRate_);
        strategy.__setStrategyProtocolFeeRate(strategyProtocolFeeRate_);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:SSDFR:NO_CHANGE");
        strategy.setStrategyDelegateFeeRate(strategyDelegateFeeRate_);
    }

    function test_setStrategyDelegateFeeRate_revert_invalidFeeRate() external {
        uint32 strategyDelegateFeeRate_ = 1.5e6;  // 150% delegate fee

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:SSDFR:INVALID_FEE_RATE");
        strategy.setStrategyDelegateFeeRate(strategyDelegateFeeRate_);
    }

    function test_setStrategyDelegateFeeRate_revert_invalidSumFeeRate() external {
        uint32 strategyDelegateFeeRate_ = 0.97e6 + 1;  // > 97% delegate fee
        uint32 strategyProtocolFeeRate_ = 0.03e6;      // 3% protocol fee

        strategy.__setStrategyProtocolFeeRate(strategyProtocolFeeRate_);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:SSDFR:INVALID_SUM_FEE_RATE");
        strategy.setStrategyDelegateFeeRate(strategyDelegateFeeRate_);
    }

}

contract AaveV3SetStrategyDelegateFeeRateSuccessTests is AaveV3TestBase {

    function setUp() public override {
        super.setUp();

        strategy.__setStrategyDelegateFeeRate(0);  // 0% delegate fee
        strategy.__setStrategyProtocolFeeRate(0);  // 0% protocol fee
    }

    function test_setStrategyDelegateFeeRate_success() external {
        uint32 strategyDelegateFeeRate_ = 0.04e6;  // 4% delegate fee

        assertEq(strategy.strategyDelegateFeeRate(), 0);
        assertEq(strategy.strategyProtocolFeeRate(), 0);

        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyFeesCollected(0, 0);

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyDelegateFeeRateSet(strategyDelegateFeeRate_);

        vm.prank(strategyDelegate);
        strategy.setStrategyDelegateFeeRate(strategyDelegateFeeRate_);

        assertEq(strategy.strategyDelegateFeeRate(), strategyDelegateFeeRate_);
        assertEq(strategy.strategyProtocolFeeRate(), 0);

        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

    function test_setStrategyDelegateFeeRate_success_maxSumFeeRate() external {
        uint32 strategyDelegateFeeRate_ = 0.97e6;  // 97% delegate fee
        uint32 strategyProtocolFeeRate_ = 0.03e6;  // 3% protocol fee

        strategy.__setStrategyProtocolFeeRate(strategyProtocolFeeRate_);

        assertEq(strategy.strategyDelegateFeeRate(), 0);
        assertEq(strategy.strategyProtocolFeeRate(), strategyProtocolFeeRate_);

        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyFeesCollected(0, 0);

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyDelegateFeeRateSet(strategyDelegateFeeRate_);

        vm.prank(strategyDelegate);
        strategy.setStrategyDelegateFeeRate(strategyDelegateFeeRate_);

        assertEq(strategy.strategyDelegateFeeRate(), strategyDelegateFeeRate_);
        assertEq(strategy.strategyProtocolFeeRate(), strategyProtocolFeeRate_);

        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

    function test_setStrategyDelegateFeeRate_success_minFeeRate() external {
        uint32 strategyDelegateFeeRate_ = 1;  // Minimum non-zero delegate fee.

        assertEq(strategy.strategyDelegateFeeRate(), 0);
        assertEq(strategy.strategyProtocolFeeRate(), 0);

        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyFeesCollected(0, 0);

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyDelegateFeeRateSet(strategyDelegateFeeRate_);

        vm.prank(strategyDelegate);
        strategy.setStrategyDelegateFeeRate(strategyDelegateFeeRate_);

        assertEq(strategy.strategyDelegateFeeRate(), strategyDelegateFeeRate_);
        assertEq(strategy.strategyProtocolFeeRate(), 0);

        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

    function test_setStrategyDelegateFeeRate_success_maxFeeRate() external {
        uint32 strategyDelegateFeeRate_ = 1e6;  // 100% delegate fee.

        assertEq(strategy.strategyDelegateFeeRate(), 0);
        assertEq(strategy.strategyProtocolFeeRate(), 0);

        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyFeesCollected(0, 0);

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyDelegateFeeRateSet(strategyDelegateFeeRate_);

        vm.prank(strategyDelegate);
        strategy.setStrategyDelegateFeeRate(strategyDelegateFeeRate_);

        assertEq(strategy.strategyDelegateFeeRate(), strategyDelegateFeeRate_);
        assertEq(strategy.strategyProtocolFeeRate(), 0);

        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

    function test_setStrategyDelegateFeeRate_success_zeroFeeRate() external {
        uint32 strategyDelegateFeeRate_ = 0.04e6;  // 4% delegate fee
        uint32 strategyProtocolFeeRate_ = 0.03e6;  // 3% protocol fee

        strategy.__setStrategyDelegateFeeRate(strategyDelegateFeeRate_);
        strategy.__setStrategyProtocolFeeRate(strategyProtocolFeeRate_);

        assertEq(strategy.strategyDelegateFeeRate(), strategyDelegateFeeRate_);
        assertEq(strategy.strategyProtocolFeeRate(), strategyProtocolFeeRate_);

        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyFeesCollected(0, 0);

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyDelegateFeeRateSet(0);

        vm.prank(strategyDelegate);
        strategy.setStrategyDelegateFeeRate(0);

        assertEq(strategy.strategyDelegateFeeRate(), 0);
        assertEq(strategy.strategyProtocolFeeRate(), strategyProtocolFeeRate_);

        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

    function test_setStrategyDelegateFeeRate_success_accruesFeesBeforeUpdatingRate() external {
        uint32 newStrategyDelegateFeeRate_ = 0.10e6;  // 10% delegate fee
        uint32 strategyDelegateFeeRate_    = 0.02e6;  // 2% delegate fee
        uint32 strategyProtocolFeeRate_    = 0.03e6;  // 3% protocol fee

        strategy.__setStrategyDelegateFeeRate(strategyDelegateFeeRate_);
        strategy.__setStrategyProtocolFeeRate(strategyProtocolFeeRate_);

        uint256 expectedATokenBalanceBeforeRateSet         = 200e6;  // 200 aToken balance.
        uint256 expectedLastRecordedBeforeRateSet          = 100e6;  // Existing recorded assets before 100e6 yield.
        uint256 expectedAssetsUnderManagementBeforeRateSet = 195e6;  // 200e6 current assets - 5e6 accrued fees.

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: expectedLastRecordedBeforeRateSet,
            aaveTokenBalance_:        expectedATokenBalanceBeforeRateSet
        });

        assertEq(strategy.strategyDelegateFeeRate(), strategyDelegateFeeRate_);
        assertEq(strategy.strategyProtocolFeeRate(), strategyProtocolFeeRate_);

        assertAaveV3Strategy({
            aaveTokenBalance:        expectedATokenBalanceBeforeRateSet,
            lastRecordedTotalAssets: expectedLastRecordedBeforeRateSet,
            assetsUnderManagement:   expectedAssetsUnderManagementBeforeRateSet
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        uint256 expectedDelegateFee               = 2e6;    // 100e6 yield * 2% delegate fee.
        uint256 expectedProtocolFee               = 3e6;    // 100e6 yield * 3% protocol fee.
        uint256 expectedATokenBalanceAfterRateSet = 195e6;  // 200e6 - 5e6 fees.
        uint256 expectedLastRecordedAfterRateSet  = 195e6;  // 200e6 current assets - 5e6 fees.

        vm.expectCall(
            aavePool,
            abi.encodeCall(IAavePoolLike.withdraw, (address(asset), expectedDelegateFee + expectedProtocolFee, address(strategy))),
            1
        );

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyFeesCollected(expectedDelegateFee, expectedProtocolFee);

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyDelegateFeeRateSet(newStrategyDelegateFeeRate_);

        vm.prank(strategyDelegate);
        strategy.setStrategyDelegateFeeRate(newStrategyDelegateFeeRate_);

        assertEq(strategy.strategyDelegateFeeRate(), newStrategyDelegateFeeRate_);
        assertEq(strategy.strategyProtocolFeeRate(), strategyProtocolFeeRate_);

        assertAaveV3Strategy({
            aaveTokenBalance:        expectedATokenBalanceAfterRateSet,
            lastRecordedTotalAssets: expectedLastRecordedAfterRateSet,
            assetsUnderManagement:   expectedLastRecordedAfterRateSet
        });

        assertCollectedFees({
            delegateFee: expectedDelegateFee,
            protocolFee: expectedProtocolFee
        });
    }

}
