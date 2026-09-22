// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { AaveV3TestBase } from "../../utils/AaveV3TestBase.sol";

contract AaveV3AssetsUnderManagementTests is AaveV3TestBase {

    function setUp() public override {
        super.setUp();

        strategy.__setStrategyDelegateFeeRate(0); // 0% delegate fee
        strategy.__setStrategyProtocolFeeRate(0); // 0% protocol fee

        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

    function test_assetsUnderManagement_success_noAccruedFees() external {
        setAaveV3StrategyState({
            lastRecordedTotalAssets_: 100e6,
            aaveTokenBalance_:        100e6
        });

        assertAaveV3Strategy({
            aaveTokenBalance:        100e6,
            lastRecordedTotalAssets: 100e6,
            assetsUnderManagement:   100e6
        });
    }

    function test_assetsUnderManagement_success_directTransfer() external {
        aaveToken.mint(address(strategy), 100e6);

        assertAaveV3Strategy({
            aaveTokenBalance:        100e6,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   100e6
        });
    }

    function test_assetsUnderManagement_success_strategyHasYield() external {
        strategy.__setStrategyDelegateFeeRate(0.02e6); // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6); // 3% protocol fee

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: 100e6,
            aaveTokenBalance_:        100e6
        });

        assertAaveV3Strategy({
            aaveTokenBalance:        100e6,
            lastRecordedTotalAssets: 100e6,
            assetsUnderManagement:   100e6
        });

        setStrategyATokenBalance(200e6); // 100% yield

        // the aToken balance has grown to 200 assets, and 5% total fees on 100 yield leaves 195 AUM
        assertAaveV3Strategy({
            aaveTokenBalance:        200e6,
            lastRecordedTotalAssets: 100e6,
            assetsUnderManagement:   195e6
        });
    }

    function test_assetsUnderManagement_success_strategyHasLoss() external {
        setAaveV3StrategyState({
            lastRecordedTotalAssets_: 100e6,
            aaveTokenBalance_:        100e6
        });

        assertAaveV3Strategy({
            aaveTokenBalance:        100e6,
            lastRecordedTotalAssets: 100e6,
            assetsUnderManagement:   100e6
        });

        setStrategyATokenBalance(50e6); // 50% loss

        // a 50% balance loss makes the position worth 50 assets
        assertAaveV3Strategy({
            aaveTokenBalance:        50e6,
            lastRecordedTotalAssets: 100e6,
            assetsUnderManagement:   50e6
        });
    }

    function test_assetsUnderManagement_success_strategyHasLossWithFeeRates() external {
        strategy.__setStrategyDelegateFeeRate(0.02e6); // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6); // 3% protocol fee

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: 100e6,
            aaveTokenBalance_:        100e6
        });

        assertAaveV3Strategy({
            aaveTokenBalance:        100e6,
            lastRecordedTotalAssets: 100e6,
            assetsUnderManagement:   100e6
        });

        setStrategyATokenBalance(50e6); // 50% loss

        // fee rates do not reduce AUM during a loss because there is no yield to charge
        assertAaveV3Strategy({
            aaveTokenBalance:        50e6,
            lastRecordedTotalAssets: 100e6,
            assetsUnderManagement:   50e6
        });
    }

    function test_assetsUnderManagement_success_totalLoss() external {
        setAaveV3StrategyState({
            lastRecordedTotalAssets_: 100e6,
            aaveTokenBalance_:        100e6
        });

        assertAaveV3Strategy({
            aaveTokenBalance:        100e6,
            lastRecordedTotalAssets: 100e6,
            assetsUnderManagement:   100e6
        });

        setStrategyATokenBalance(0); // 100% loss

        // zero aToken balance means the position has no recoverable asset value
        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 100e6,
            assetsUnderManagement:   0
        });
    }

    function test_assetsUnderManagement_success_lossRecognizedReturnsZeroAfterRawPositionGrows() external {
        uint256 currentTotalAssets = 100e6; // Strategy holds 100 aTokens worth 100 assets.
        uint256 aaveTokenBalance   = 100e6; // Strategy holds 100 aTokens.

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: currentTotalAssets,
            aaveTokenBalance_:        aaveTokenBalance
        });

        assertAaveV3Strategy({
            aaveTokenBalance:        aaveTokenBalance,
            lastRecordedTotalAssets: currentTotalAssets,
            assetsUnderManagement:   currentTotalAssets
        });

        vm.prank(strategyDelegate);
        strategy.recognizeLoss();

        uint256 increasedATokenBalance = 200e6; // Raw Aave position grows after final loss recognition.

        setStrategyATokenBalance(increasedATokenBalance);

        assertAaveV3Strategy({
            aaveTokenBalance:        increasedATokenBalance,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

    function test_assetsUnderManagement_success_feesRoundedDownToZero() external {
        strategy.__setStrategyDelegateFeeRate(0.02e6); // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6); // 3% protocol fee

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: 100e6,
            aaveTokenBalance_:        100e6
        });

        assertAaveV3Strategy({
            aaveTokenBalance:        100e6,
            lastRecordedTotalAssets: 100e6,
            assetsUnderManagement:   100e6
        });

        setStrategyATokenBalance(100e6 + 20);

        // positive yield that rounds both fee shares to zero stays in AUM
        assertAaveV3Strategy({
            aaveTokenBalance:        100e6 + 20,
            lastRecordedTotalAssets: 100e6,
            assetsUnderManagement:   100e6 + 20
        });
    }

    function test_assetsUnderManagement_success_subtractsBothFeeShares() external {
        strategy.__setStrategyDelegateFeeRate(0.4e6); // 40% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.6e6); // 60% protocol fee

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: 100e6,
            aaveTokenBalance_:        100e6
        });

        assertAaveV3Strategy({
            aaveTokenBalance:        100e6,
            lastRecordedTotalAssets: 100e6,
            assetsUnderManagement:   100e6
        });

        setStrategyATokenBalance(200e6); // 100% yield

        // 100 assets of yield is fully consumed by 40% delegate and 60% protocol fees
        assertAaveV3Strategy({
            aaveTokenBalance:        200e6,
            lastRecordedTotalAssets: 100e6,
            assetsUnderManagement:   100e6
        });
    }

    function test_assetsUnderManagement_success_maxDelegateFeeRate() external {
        strategy.__setStrategyDelegateFeeRate(1e6); // 100% delegate fee

        setStrategyATokenBalance(100e6);

        // all 100 assets are yield and the delegate fee consumes it
        assertAaveV3Strategy({
            aaveTokenBalance:        100e6,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

    function test_assetsUnderManagement_success_maxProtocolFeeRate() external {
        strategy.__setStrategyProtocolFeeRate(1e6); // 100% protocol fee

        setStrategyATokenBalance(100e6);

        // all 100 assets are yield and the protocol fee consumes it
        assertAaveV3Strategy({
            aaveTokenBalance:        100e6,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

    function test_assetsUnderManagement_success_maxSplitFeeRate() external {
        strategy.__setStrategyDelegateFeeRate(0.4e6); // 40% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.6e6); // 60% protocol fee

        setStrategyATokenBalance(100e6);

        // all 100 assets are yield and the combined fee consumes it
        assertAaveV3Strategy({
            aaveTokenBalance:        100e6,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

}
