// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MapleAaveV3Strategy } from "../../../contracts/aaveV3/MapleAaveV3Strategy.sol";

import { IAavePoolLike }        from "../../../contracts/interfaces/Interfaces.sol";
import { IMapleAaveV3Strategy } from "../../../contracts/interfaces/IMapleAaveV3Strategy.sol";

import { AaveV3TestBase } from "../../utils/AaveV3TestBase.sol";

contract AaveV3FundUnderlyingStrategyFailureTests is AaveV3TestBase {

    function test_fundUnderlyingStrategy_revert_functionPaused() external {
        globals.__setIsFunctionPaused(MapleAaveV3Strategy.fundUnderlyingStrategy.selector, true);

        vm.prank(address(strategyManager));
        vm.expectRevert("MAV3S:PAUSED");
        strategy.fundUnderlyingStrategy(1, "");
    }

    function test_fundUnderlyingStrategy_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(address(strategyManager));
        vm.expectRevert("MAV3S:LOCKED");
        strategy.fundUnderlyingStrategy(1, "");
    }

    function test_fundUnderlyingStrategy_revert_notStrategyManager() external {
        vm.expectRevert("MAV3S:NOT_STRATEGY_MANAGER");
        strategy.fundUnderlyingStrategy(1, "");
    }

    function test_fundUnderlyingStrategy_revert_lossRecognized() external {
        strategy.__setIsLossRecognized(true);

        vm.prank(address(strategyManager));
        vm.expectRevert("MAV3S:LOSS_RECOGNIZED");
        strategy.fundUnderlyingStrategy(1, "");
    }

    function test_fundUnderlyingStrategy_revert_zeroAssets() external {
        vm.prank(address(strategyManager));
        vm.expectRevert("MAV3S:FUS:ZERO_ASSETS");
        strategy.fundUnderlyingStrategy(0, "");
    }

    function test_fundUnderlyingStrategy_revert_invalidStrategyVault() external {
        globals.__setIsInstanceOf("STRATEGY_VAULT", address(aaveToken), false);

        vm.prank(address(strategyManager));
        vm.expectRevert("MAV3S:FUS:INVALID_STRATEGY_VAULT");
        strategy.fundUnderlyingStrategy(1, "");
    }

    function test_fundUnderlyingStrategy_revert_assetApproveFail() external {
        asset.__setApproveReverts(aavePool, true);

        vm.prank(address(strategyManager));
        vm.expectRevert("MAV3S:FUS:ASSET_APPROVE_FAIL");
        strategy.fundUnderlyingStrategy(1, "");
    }

}

contract AaveV3FundUnderlyingStrategySuccessTests is AaveV3TestBase {

    function setUp() public override {
        super.setUp();

        strategy.__setStrategyDelegateFeeRate(0);
        strategy.__setStrategyProtocolFeeRate(0);

        asset.mint(address(strategy), 1e30);
    }

    function test_fundUnderlyingStrategy_success_forwardsReferralCode() external {
        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        uint16 referralCode = 42;
        uint256 assets      = 100e6;

        vm.prank(strategyDelegate);
        strategy.setReferralCode(referralCode);

        vm.expectCall(
            aavePool,
            abi.encodeCall(IAavePoolLike.supply, (address(asset), assets, address(strategy), referralCode))
        );

        vm.prank(address(strategyManager));
        strategy.fundUnderlyingStrategy(assets, "");

        assertAaveV3Strategy({
            aaveTokenBalance:        assets,
            lastRecordedTotalAssets: assets,
            assetsUnderManagement:   assets
        });
    }

    function test_fundUnderlyingStrategy_success_firstDeposit() external {
        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        uint256 assets           = 100e6;
        uint256 expectedDeployed = 100e6;

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyFeesCollected(0, 0);

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyFunded(address(strategyManager), assets, expectedDeployed);

        vm.prank(address(strategyManager));
        uint256 deployedAssets = strategy.fundUnderlyingStrategy(assets, "");

        assertEq(deployedAssets, expectedDeployed);

        assertAaveV3Strategy({
            aaveTokenBalance:        expectedDeployed,
            lastRecordedTotalAssets: expectedDeployed,
            assetsUnderManagement:   expectedDeployed
        });
    }

    function test_fundUnderlyingStrategy_success_secondDeposit_strategyHasYield_withProtocolFees() external {
        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        /**********************************************************************************************************************************/
        /*** Step 1: Set fee rates                                                                                                      ***/
        /**********************************************************************************************************************************/

        strategy.__setStrategyDelegateFeeRate(0.02e6); // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6); // 3% protocol fee

        /**********************************************************************************************************************************/
        /*** Step 2: Make first deposit and simulate yield                                                                              ***/
        /**********************************************************************************************************************************/

        uint256 firstDepositAssets                  = 100e6;
        uint256 expectedFirstDeployedAssets         = 100e6;  // First deposit deploys all assets.
        uint256 expectedTotalAfterFirstFund         = 100e6;  // First deposit has no prior yield to collect fees on.
        uint256 yieldToAdd                          = 40e6;   // Simulate Aave balance increasing by 40 USDC.
        uint256 assetsUnderManagementAfterFirstFund = 138e6;  // 140e6 Aave balance - 0.8e6 delegate fee - 1.2e6 protocol fee.

        vm.prank(address(strategyManager));
        uint256 firstDeployedAssets = strategy.fundUnderlyingStrategy(firstDepositAssets, "");

        assertEq(firstDeployedAssets, expectedFirstDeployedAssets);

        setStrategyATokenBalance(firstDepositAssets + yieldToAdd);  // Strategy position has 40 USDC of yield

        assertAaveV3Strategy({
            aaveTokenBalance:        firstDepositAssets + yieldToAdd,
            lastRecordedTotalAssets: expectedTotalAfterFirstFund,
            assetsUnderManagement:   assetsUnderManagementAfterFirstFund
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 3: Make second deposit and assert                                                                                     ***/
        /**********************************************************************************************************************************/

        uint256 secondDepositAssets           = 100e6;
        uint256 expectedDeployedAssets        = 100e6;  // Second deposit deploys all assets.

        uint256 expectedDelegateFee           = 0.8e6;  // 40e6 yield * 2% delegate fee.
        uint256 expectedProtocolFee           = 1.2e6;  // 40e6 yield * 3% protocol fee.
        uint256 expectedLastRecordedAfterFund = 238e6;  // 140e6 Aave balance - 2e6 fees + 100e6 second deposit.

        vm.expectCall(
            aavePool,
            abi.encodeCall(IAavePoolLike.withdraw, (address(asset), expectedDelegateFee + expectedProtocolFee, address(strategy))),
            1
        );

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyFeesCollected(expectedDelegateFee, expectedProtocolFee);

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyFunded(
            address(strategyManager),
            secondDepositAssets,
            expectedDeployedAssets
        );

        vm.prank(address(strategyManager));
        uint256 deployedAssets = strategy.fundUnderlyingStrategy(secondDepositAssets, "");

        assertEq(deployedAssets, expectedDeployedAssets);

        assertAaveV3Strategy({
            aaveTokenBalance:        expectedLastRecordedAfterFund,
            lastRecordedTotalAssets: expectedLastRecordedAfterFund,
            assetsUnderManagement:   expectedLastRecordedAfterFund
        });

        assertCollectedFees({
            delegateFee: expectedDelegateFee,
            protocolFee: expectedProtocolFee
        });
    }

    function test_fundUnderlyingStrategy_success_secondDeposit_strategyHasYield_withDelegateFeeOnly() external {
        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        /**********************************************************************************************************************************/
        /*** Step 1: Set fee rates                                                                                                      ***/
        /**********************************************************************************************************************************/

        strategy.__setStrategyDelegateFeeRate(0.02e6); // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0);      // 0% protocol fee

        /**********************************************************************************************************************************/
        /*** Step 2: Make first deposit and simulate yield                                                                              ***/
        /**********************************************************************************************************************************/

        uint256 firstDepositAssets                  = 100e6;
        uint256 expectedFirstDeployedAssets         = 100e6;    // First deposit deploys all assets.
        uint256 expectedTotalAfterFirstFund         = 100e6;    // First deposit has no prior yield to collect fees on.
        uint256 yieldToAdd                          = 40e6;     // Simulate Aave balance increasing by 40 USDC.
        uint256 assetsUnderManagementAfterFirstFund = 139.2e6;  // 140e6 Aave balance - 0.8e6 delegate fee.

        vm.prank(address(strategyManager));
        uint256 firstDeployedAssets = strategy.fundUnderlyingStrategy(firstDepositAssets, "");

        assertEq(firstDeployedAssets, expectedFirstDeployedAssets);

        setStrategyATokenBalance(firstDepositAssets + yieldToAdd);  // Strategy position has 40 USDC of yield

        assertAaveV3Strategy({
            aaveTokenBalance:        firstDepositAssets + yieldToAdd,
            lastRecordedTotalAssets: expectedTotalAfterFirstFund,
            assetsUnderManagement:   assetsUnderManagementAfterFirstFund
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 3: Make second deposit and assert                                                                                     ***/
        /**********************************************************************************************************************************/

        uint256 secondDepositAssets           = 100e6;
        uint256 expectedDeployedAssets        = 100e6;   // Second deposit deploys all assets.

        uint256 expectedDelegateFee           = 0.8e6;   // 40e6 yield * 2% delegate fee.
        uint256 expectedProtocolFee           = 0;       // 40e6 yield * 0% protocol fee.
        uint256 expectedLastRecordedAfterFund = 239.2e6; // 140e6 Aave balance - 0.8e6 fees + 100e6 second deposit.

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyFeesCollected(expectedDelegateFee, expectedProtocolFee);

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyFunded(
            address(strategyManager),
            secondDepositAssets,
            expectedDeployedAssets
        );

        vm.prank(address(strategyManager));
        uint256 deployedAssets = strategy.fundUnderlyingStrategy(secondDepositAssets, "");

        assertEq(deployedAssets, expectedDeployedAssets);

        assertAaveV3Strategy({
            aaveTokenBalance:        expectedLastRecordedAfterFund,
            lastRecordedTotalAssets: expectedLastRecordedAfterFund,
            assetsUnderManagement:   expectedLastRecordedAfterFund
        });

        assertCollectedFees({
            delegateFee: expectedDelegateFee,
            protocolFee: expectedProtocolFee
        });
    }

    function test_fundUnderlyingStrategy_success_secondDeposit_strategyHasYield_withProtocolFeeOnly() external {
        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        /**********************************************************************************************************************************/
        /*** Step 1: Set fee rates                                                                                                      ***/
        /**********************************************************************************************************************************/

        strategy.__setStrategyDelegateFeeRate(0);      // 0% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6); // 3% protocol fee

        /**********************************************************************************************************************************/
        /*** Step 2: Make first deposit and simulate yield                                                                              ***/
        /**********************************************************************************************************************************/

        uint256 firstDepositAssets                  = 100e6;
        uint256 expectedFirstDeployedAssets         = 100e6;    // First deposit deploys all assets.
        uint256 expectedTotalAfterFirstFund         = 100e6;    // First deposit has no prior yield to collect fees on.
        uint256 yieldToAdd                          = 40e6;     // Simulate Aave balance increasing by 40 USDC.
        uint256 assetsUnderManagementAfterFirstFund = 138.8e6;  // 140e6 Aave balance - 1.2e6 protocol fee.

        vm.prank(address(strategyManager));
        uint256 firstDeployedAssets = strategy.fundUnderlyingStrategy(firstDepositAssets, "");

        assertEq(firstDeployedAssets, expectedFirstDeployedAssets);

        setStrategyATokenBalance(firstDepositAssets + yieldToAdd);  // Strategy position has 40 USDC of yield

        assertAaveV3Strategy({
            aaveTokenBalance:        firstDepositAssets + yieldToAdd,
            lastRecordedTotalAssets: expectedTotalAfterFirstFund,
            assetsUnderManagement:   assetsUnderManagementAfterFirstFund
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 3: Make second deposit and assert                                                                                     ***/
        /**********************************************************************************************************************************/

        uint256 secondDepositAssets           = 100e6;
        uint256 expectedDeployedAssets        = 100e6;  // Second deposit deploys all assets.

        uint256 expectedDelegateFee           = 0;      // 40e6 yield * 0% delegate fee.
        uint256 expectedProtocolFee           = 1.2e6;  // 40e6 yield * 3% protocol fee.
        uint256 expectedLastRecordedAfterFund = 238.8e6;  // 140e6 Aave balance - 1.2e6 fees + 100e6 second deposit.

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyFeesCollected(expectedDelegateFee, expectedProtocolFee);

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyFunded(
            address(strategyManager),
            secondDepositAssets,
            expectedDeployedAssets
        );

        vm.prank(address(strategyManager));
        uint256 deployedAssets = strategy.fundUnderlyingStrategy(secondDepositAssets, "");

        assertEq(deployedAssets, expectedDeployedAssets);

        assertAaveV3Strategy({
            aaveTokenBalance:        expectedLastRecordedAfterFund,
            lastRecordedTotalAssets: expectedLastRecordedAfterFund,
            assetsUnderManagement:   expectedLastRecordedAfterFund
        });

        assertCollectedFees({
            delegateFee: expectedDelegateFee,
            protocolFee: expectedProtocolFee
        });
    }

    function test_fundUnderlyingStrategy_success_secondDeposit_strategyHasYield_feesRoundedDownToZero() external {
        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        /**********************************************************************************************************************************/
        /*** Step 1: Set fee rates                                                                                                      ***/
        /**********************************************************************************************************************************/

        strategy.__setStrategyDelegateFeeRate(0.02e6); // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6); // 3% protocol fee

        /**********************************************************************************************************************************/
        /*** Step 2: Make first deposit and simulate yield that rounds fees to zero                                                     ***/
        /**********************************************************************************************************************************/

        uint256 firstDepositAssets          = 100e6;
        uint256 expectedFirstDeployedAssets = 100e6;
        uint256 expectedTotalAfterFirstFund = 100e6;
        uint256 yieldThatRoundsFeesToZero   = 20;
        uint256 aaveAmountOutBeforeFund     = expectedTotalAfterFirstFund + yieldThatRoundsFeesToZero;

        vm.prank(address(strategyManager));
        uint256 firstDeployedAssets = strategy.fundUnderlyingStrategy(firstDepositAssets, "");

        assertEq(firstDeployedAssets, expectedFirstDeployedAssets);

        setStrategyATokenBalance(aaveAmountOutBeforeFund);  // Strategy position has positive yield that rounds fees to zero

        assertAaveV3Strategy({
            aaveTokenBalance:        aaveAmountOutBeforeFund,
            lastRecordedTotalAssets: expectedTotalAfterFirstFund,
            assetsUnderManagement:   aaveAmountOutBeforeFund
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 3: Make second deposit and assert                                                                                     ***/
        /**********************************************************************************************************************************/

        uint256 secondDepositAssets           = 100e6;
        uint256 expectedDeployedAssets        = 100e6;
        uint256 expectedLastRecordedAfterFund = 200e6 + yieldThatRoundsFeesToZero;

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyFeesCollected(0, 0);

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyFunded(
            address(strategyManager),
            secondDepositAssets,
            expectedDeployedAssets
        );

        vm.prank(address(strategyManager));
        uint256 deployedAssets = strategy.fundUnderlyingStrategy(secondDepositAssets, "");

        assertEq(deployedAssets, expectedDeployedAssets);

        assertAaveV3Strategy({
            aaveTokenBalance:        expectedLastRecordedAfterFund,
            lastRecordedTotalAssets: expectedLastRecordedAfterFund,
            assetsUnderManagement:   expectedLastRecordedAfterFund
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });
    }

    function test_fundUnderlyingStrategy_success_secondDeposit_strategyHasZeroYield_withProtocolFees() external {
        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        /**********************************************************************************************************************************/
        /*** Step 1: Set fee rates                                                                                                      ***/
        /**********************************************************************************************************************************/

        strategy.__setStrategyDelegateFeeRate(0.02e6); // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6); // 3% protocol fee

        /**********************************************************************************************************************************/
        /*** Step 2: Make first deposit with zero yield/loss                                                                            ***/
        /**********************************************************************************************************************************/

        uint256 firstDepositAssets            = 100e6;
        uint256 expectedFirstDeployedAssets   = 100e6;
        uint256 expectedTotalAfterFirstFund   = 100e6;

        vm.prank(address(strategyManager));
        uint256 firstDeployedAssets = strategy.fundUnderlyingStrategy(firstDepositAssets, "");

        assertEq(firstDeployedAssets, expectedFirstDeployedAssets);

        assertAaveV3Strategy({
            aaveTokenBalance:        expectedTotalAfterFirstFund,
            lastRecordedTotalAssets: expectedTotalAfterFirstFund,
            assetsUnderManagement:   expectedTotalAfterFirstFund
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 3: Make second deposit and assert                                                                                     ***/
        /**********************************************************************************************************************************/

        uint256 secondDepositAssets           = 100e6;
        uint256 expectedDeployedAssets        = 100e6;
        uint256 expectedLastRecordedAfterFund = 200e6;

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyFeesCollected(0, 0);

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyFunded(
            address(strategyManager),
            secondDepositAssets,
            expectedDeployedAssets
        );

        vm.prank(address(strategyManager));
        uint256 deployedAssets = strategy.fundUnderlyingStrategy(secondDepositAssets, "");

        assertEq(deployedAssets, expectedDeployedAssets);

        assertAaveV3Strategy({
            aaveTokenBalance:        expectedLastRecordedAfterFund,
            lastRecordedTotalAssets: expectedLastRecordedAfterFund,
            assetsUnderManagement:   expectedLastRecordedAfterFund
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });
    }

    function test_fundUnderlyingStrategy_success_secondDeposit_strategyHasLoss_withProtocolFees() external {
        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        /**********************************************************************************************************************************/
        /*** Step 1: Set fee rates                                                                                                      ***/
        /**********************************************************************************************************************************/

        strategy.__setStrategyDelegateFeeRate(0.02e6); // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6); // 3% protocol fee

        /**********************************************************************************************************************************/
        /*** Step 2: Make first deposit and simulate loss                                                                               ***/
        /**********************************************************************************************************************************/

        uint256 firstDepositAssets          = 100e6;
        uint256 expectedFirstDeployedAssets = 100e6;
        uint256 expectedTotalAfterFirstFund = 100e6;
        uint256 aaveAmountOutBeforeFund     = 80e6;

        vm.prank(address(strategyManager));
        uint256 firstDeployedAssets = strategy.fundUnderlyingStrategy(firstDepositAssets, "");

        assertEq(firstDeployedAssets, expectedFirstDeployedAssets);

        setStrategyATokenBalance(aaveAmountOutBeforeFund);  // Strategy position has a 20 USDC loss

        assertAaveV3Strategy({
            aaveTokenBalance:        aaveAmountOutBeforeFund,
            lastRecordedTotalAssets: expectedTotalAfterFirstFund,
            assetsUnderManagement:   aaveAmountOutBeforeFund
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 3: Make second deposit and assert                                                                                     ***/
        /**********************************************************************************************************************************/

        uint256 secondDepositAssets           = 100e6;
        uint256 expectedDeployedAssets        = 100e6;
        uint256 expectedLastRecordedAfterFund = 180e6;

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyFeesCollected(0, 0);

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyFunded(
            address(strategyManager),
            secondDepositAssets,
            expectedDeployedAssets
        );

        vm.prank(address(strategyManager));
        uint256 deployedAssets = strategy.fundUnderlyingStrategy(secondDepositAssets, "");

        assertEq(deployedAssets, expectedDeployedAssets);

        assertAaveV3Strategy({
            aaveTokenBalance:        expectedLastRecordedAfterFund,
            lastRecordedTotalAssets: expectedLastRecordedAfterFund,
            assetsUnderManagement:   expectedLastRecordedAfterFund
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });
    }

}
