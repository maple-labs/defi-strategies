// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleSkyStrategy } from "../../../contracts/interfaces/IMapleSkyStrategy.sol";

import { MapleSkyStrategy } from "../../../contracts/sky/MapleSkyStrategy.sol";

import { SkyTestBase } from "../../utils/SkyTestBase.sol";

contract SkySetStrategyProtocolFeeRateFailureTests is SkyTestBase {

    function setUp() public override {
        super.setUp();

        strategy.__setStrategyDelegateFeeRate(0);  // 0% delegate fee
        strategy.__setStrategyProtocolFeeRate(0);  // 0% protocol fee
    }

    function test_setStrategyProtocolFeeRate_revert_protocolPaused() external {
        uint32 strategyProtocolFeeRate_ = 0.04e6;  // 4% protocol fee

        globals.__setIsFunctionPaused(MapleSkyStrategy.setStrategyProtocolFeeRate.selector, true);

        vm.prank(governor);
        vm.expectRevert("MSS:PAUSED");
        strategy.setStrategyProtocolFeeRate(strategyProtocolFeeRate_);
    }

    function test_setStrategyProtocolFeeRate_revert_reentrancy() external {
        uint32 strategyProtocolFeeRate_ = 0.04e6;  // 4% protocol fee

        strategy.__setLocked(2);

        vm.prank(governor);
        vm.expectRevert("MSS:LOCKED");
        strategy.setStrategyProtocolFeeRate(strategyProtocolFeeRate_);
    }

    function test_setStrategyProtocolFeeRate_revert_notAdmin() external {
        uint32 strategyProtocolFeeRate_ = 0.04e6;  // 4% protocol fee

        vm.expectRevert("MSS:NOT_ADMIN");
        strategy.setStrategyProtocolFeeRate(strategyProtocolFeeRate_);
    }

    function test_setStrategyProtocolFeeRate_revert_noChange() external {
        uint32 strategyDelegateFeeRate_ = 0.02e6;  // 2% delegate fee
        uint32 strategyProtocolFeeRate_ = 0.05e6;  // 5% protocol fee

        strategy.__setStrategyDelegateFeeRate(strategyDelegateFeeRate_);
        strategy.__setStrategyProtocolFeeRate(strategyProtocolFeeRate_);

        vm.prank(governor);
        vm.expectRevert("MSS:SSPFR:NO_CHANGE");
        strategy.setStrategyProtocolFeeRate(strategyProtocolFeeRate_);
    }

    function test_setStrategyProtocolFeeRate_revert_invalidFeeRate() external {
        uint32 strategyProtocolFeeRate_ = 1.5e6;  // 150% protocol fee

        vm.prank(governor);
        vm.expectRevert("MSS:SSPFR:INVALID_FEE_RATE");
        strategy.setStrategyProtocolFeeRate(strategyProtocolFeeRate_);
    }

    function test_setStrategyProtocolFeeRate_revert_invalidSumFeeRate() external {
        uint32 strategyDelegateFeeRate_ = 0.03e6;      // 3% delegate fee
        uint32 strategyProtocolFeeRate_ = 0.97e6 + 1;  // > 97% protocol fee

        strategy.__setStrategyDelegateFeeRate(strategyDelegateFeeRate_);

        vm.prank(governor);
        vm.expectRevert("MSS:SSPFR:INVALID_SUM_FEE_RATE");
        strategy.setStrategyProtocolFeeRate(strategyProtocolFeeRate_);
    }

}

contract SkySetStrategyProtocolFeeRateSuccessTests is SkyTestBase {

    function setUp() public override {
        super.setUp();

        strategy.__setStrategyDelegateFeeRate(0);  // 0% delegate fee
        strategy.__setStrategyProtocolFeeRate(0);  // 0% protocol fee
    }

    function test_setStrategyProtocolFeeRate_success_governor() external {
        uint32 strategyProtocolFeeRate_ = 0.04e6;  // 4% protocol fee

        assertEq(strategy.strategyDelegateFeeRate(), 0);
        assertEq(strategy.strategyProtocolFeeRate(), 0);

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyFeesCollected(0, 0);

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyProtocolFeeRateSet(strategyProtocolFeeRate_);

        vm.prank(governor);
        strategy.setStrategyProtocolFeeRate(strategyProtocolFeeRate_);

        assertEq(strategy.strategyDelegateFeeRate(), 0);
        assertEq(strategy.strategyProtocolFeeRate(), strategyProtocolFeeRate_);

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

    function test_setStrategyProtocolFeeRate_success_operationalAdmin() external {
        uint32 strategyProtocolFeeRate_ = 0.05e6;  // 5% protocol fee

        assertEq(strategy.strategyDelegateFeeRate(), 0);
        assertEq(strategy.strategyProtocolFeeRate(), 0);

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyFeesCollected(0, 0);

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyProtocolFeeRateSet(strategyProtocolFeeRate_);

        vm.prank(operationalAdmin);
        strategy.setStrategyProtocolFeeRate(strategyProtocolFeeRate_);

        assertEq(strategy.strategyDelegateFeeRate(), 0);
        assertEq(strategy.strategyProtocolFeeRate(), strategyProtocolFeeRate_);

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

    function test_setStrategyProtocolFeeRate_success_maxSumFeeRate() external {
        uint32 strategyDelegateFeeRate_ = 0.02e6;  // 2% delegate fee
        uint32 strategyProtocolFeeRate_ = 0.98e6;  // 98% protocol fee

        strategy.__setStrategyDelegateFeeRate(strategyDelegateFeeRate_);

        assertEq(strategy.strategyDelegateFeeRate(), strategyDelegateFeeRate_);
        assertEq(strategy.strategyProtocolFeeRate(), 0);

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyFeesCollected(0, 0);

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyProtocolFeeRateSet(strategyProtocolFeeRate_);

        vm.prank(governor);
        strategy.setStrategyProtocolFeeRate(strategyProtocolFeeRate_);

        assertEq(strategy.strategyDelegateFeeRate(), strategyDelegateFeeRate_);
        assertEq(strategy.strategyProtocolFeeRate(), strategyProtocolFeeRate_);
    }

    function test_setStrategyProtocolFeeRate_success_minFeeRate() external {
        uint32 strategyProtocolFeeRate_ = 1;  // Minimum non-zero protocol fee.

        assertEq(strategy.strategyDelegateFeeRate(), 0);
        assertEq(strategy.strategyProtocolFeeRate(), 0);

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyFeesCollected(0, 0);

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyProtocolFeeRateSet(strategyProtocolFeeRate_);

        vm.prank(governor);
        strategy.setStrategyProtocolFeeRate(strategyProtocolFeeRate_);

        assertEq(strategy.strategyDelegateFeeRate(), 0);
        assertEq(strategy.strategyProtocolFeeRate(), strategyProtocolFeeRate_);

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

    function test_setStrategyProtocolFeeRate_success_maxFeeRate() external {
        uint32 strategyProtocolFeeRate_ = 1e6;  // 100% protocol fee.

        assertEq(strategy.strategyDelegateFeeRate(), 0);
        assertEq(strategy.strategyProtocolFeeRate(), 0);

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyFeesCollected(0, 0);

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyProtocolFeeRateSet(strategyProtocolFeeRate_);

        vm.prank(governor);
        strategy.setStrategyProtocolFeeRate(strategyProtocolFeeRate_);

        assertEq(strategy.strategyDelegateFeeRate(), 0);
        assertEq(strategy.strategyProtocolFeeRate(), strategyProtocolFeeRate_);

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

    function test_setStrategyProtocolFeeRate_success_zeroFeeRate() external {
        uint32 strategyDelegateFeeRate_ = 0.02e6;  // 2% delegate fee
        uint32 strategyProtocolFeeRate_ = 0.05e6;  // 5% protocol fee

        strategy.__setStrategyDelegateFeeRate(strategyDelegateFeeRate_);
        strategy.__setStrategyProtocolFeeRate(strategyProtocolFeeRate_);

        assertEq(strategy.strategyDelegateFeeRate(), strategyDelegateFeeRate_);
        assertEq(strategy.strategyProtocolFeeRate(), strategyProtocolFeeRate_);

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyFeesCollected(0, 0);

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyProtocolFeeRateSet(0);

        vm.prank(governor);
        strategy.setStrategyProtocolFeeRate(0);

        assertEq(strategy.strategyDelegateFeeRate(), strategyDelegateFeeRate_);
        assertEq(strategy.strategyProtocolFeeRate(), 0);

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

    function test_setStrategyProtocolFeeRate_success_accruesFeesBeforeUpdatingRate() external {
        uint32 newStrategyProtocolFeeRate_ = 0.10e6;  // 10% protocol fee
        uint32 strategyDelegateFeeRate_    = 0.02e6;  // 2% delegate fee
        uint32 strategyProtocolFeeRate_    = 0.03e6;  // 3% protocol fee

        psm.__setUsdsRedeemExchangeRate(1e18);
        savingsUsds.__setSusdsRedeemExchangeRate(2e18);

        strategy.__setStrategyDelegateFeeRate(strategyDelegateFeeRate_);
        strategy.__setStrategyProtocolFeeRate(strategyProtocolFeeRate_);

        uint256 expectedSusdsBalanceBeforeRateSet          = 100e18;  // 100 sUSDS balance.
        uint256 expectedLastRecordedBeforeRateSet          = 100e6;   // Existing recorded assets before 100e6 yield.
        uint256 expectedAssetsUnderManagementBeforeRateSet = 195e6;   // 200e6 current assets - 5e6 accrued fees.

        setSkyStrategyState({
            lastRecordedTotalAssets_: expectedLastRecordedBeforeRateSet,
            susdsBalance_:            expectedSusdsBalanceBeforeRateSet
        });

        assertEq(strategy.strategyDelegateFeeRate(), strategyDelegateFeeRate_);
        assertEq(strategy.strategyProtocolFeeRate(), strategyProtocolFeeRate_);

        assertSkyStrategy({
            susdsBalance:            expectedSusdsBalanceBeforeRateSet,
            lastRecordedTotalAssets: expectedLastRecordedBeforeRateSet,
            assetsUnderManagement:   expectedAssetsUnderManagementBeforeRateSet
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        uint256 expectedDelegateFee              = 2e6;      // 100e6 yield * 2% delegate fee.
        uint256 expectedProtocolFee              = 3e6;      // 100e6 yield * 3% protocol fee.
        uint256 expectedSusdsBalanceAfterRateSet = 97.5e18;  // 100e18 - 2.5e18 fee shares (5e6 fees / 2e18 rate).
        uint256 expectedLastRecordedAfterRateSet = 195e6;    // 200e6 current assets - 5e6 fees.

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyFeesCollected(expectedDelegateFee, expectedProtocolFee);

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyProtocolFeeRateSet(newStrategyProtocolFeeRate_);

        vm.prank(governor);
        strategy.setStrategyProtocolFeeRate(newStrategyProtocolFeeRate_);

        assertEq(strategy.strategyDelegateFeeRate(), strategyDelegateFeeRate_);
        assertEq(strategy.strategyProtocolFeeRate(), newStrategyProtocolFeeRate_);

        assertSkyStrategy({
            susdsBalance:            expectedSusdsBalanceAfterRateSet,
            lastRecordedTotalAssets: expectedLastRecordedAfterRateSet,
            assetsUnderManagement:   expectedLastRecordedAfterRateSet
        });

        assertCollectedFees({
            delegateFee: expectedDelegateFee,
            protocolFee: expectedProtocolFee
        });
    }

}
