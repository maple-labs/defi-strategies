// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MapleSkyStrategy } from "../../../contracts/sky/MapleSkyStrategy.sol";

import { IMapleSkyStrategy } from "../../../contracts/interfaces/IMapleSkyStrategy.sol";
import { IERC4626Like } from "../../../contracts/interfaces/Interfaces.sol";

import { SkyTestBase } from "../../utils/SkyTestBase.sol";

contract SkyFundUnderlyingStrategyFailureTests is SkyTestBase {

    function test_fundUnderlyingStrategy_revert_functionPaused() external {
        globals.__setIsFunctionPaused(MapleSkyStrategy.fundUnderlyingStrategy.selector, true);

        vm.prank(address(strategyManager));
        vm.expectRevert("MSS:PAUSED");
        strategy.fundUnderlyingStrategy(1, "");
    }

    function test_fundUnderlyingStrategy_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(address(strategyManager));
        vm.expectRevert("MSS:LOCKED");
        strategy.fundUnderlyingStrategy(1, "");
    }

    function test_fundUnderlyingStrategy_revert_notStrategyManager() external {
        vm.expectRevert("MSS:NOT_STRATEGY_MANAGER");
        strategy.fundUnderlyingStrategy(1, "");
    }

    function test_fundUnderlyingStrategy_revert_lossRecognized() external {
        strategy.__setIsLossRecognized(true);

        vm.prank(address(strategyManager));
        vm.expectRevert("MSS:LOSS_RECOGNIZED");
        strategy.fundUnderlyingStrategy(1, "");
    }

    function test_fundUnderlyingStrategy_revert_zeroAssets() external {
        vm.prank(address(strategyManager));
        vm.expectRevert("MSS:FUS:ZERO_ASSETS");
        strategy.fundUnderlyingStrategy(0, "");
    }

    function test_fundUnderlyingStrategy_revert_invalidStrategyVault() external {
        globals.__setIsInstanceOf("STRATEGY_VAULT", address(savingsUsds), false);

        vm.prank(address(strategyManager));
        vm.expectRevert("MSS:FUS:INVALID_STRATEGY_VAULT");
        strategy.fundUnderlyingStrategy(1, "");
    }

    function test_fundUnderlyingStrategy_revert_invalidPsm() external {
        globals.__setIsInstanceOf("PSM", address(psm), false);

        vm.prank(address(strategyManager));
        vm.expectRevert("MSS:FUS:INVALID_PSM");
        strategy.fundUnderlyingStrategy(1, "");
    }

    function test_fundUnderlyingStrategy_revert_psmHalted() external {
        psm.__setTout(type(uint256).max);

        vm.prank(address(strategyManager));
        vm.expectRevert("MSS:FUS:PSM_HALTED");
        strategy.fundUnderlyingStrategy(1, "");
    }

    function test_fundUnderlyingStrategy_revert_gemApproveFail() external {
        asset.__setApproveReverts(address(psm), true);

        vm.prank(address(strategyManager));
        vm.expectRevert("MSS:FUS:GEM_APPROVE_FAIL");
        strategy.fundUnderlyingStrategy(1, "");
    }

    function test_fundUnderlyingStrategy_revert_usdsApproveFail() external {
        asset.mint(address(strategy), 1);

        usds.__setApproveReverts(address(savingsUsds), true);

        vm.prank(address(strategyManager));
        vm.expectRevert("MSS:FUS:USDS_APPROVE_FAIL");
        strategy.fundUnderlyingStrategy(1, "");
    }

    function test_fundUnderlyingStrategy_revert_withdrawUsdsApproveFail() external {
        strategy.__setLastRecordedTotalAssets(100e6);
        savingsUsds.__setBalanceOf(address(strategy), 100e18);
        savingsUsds.__setSusdsRedeemExchangeRate(2e18);

        usds.mint(address(savingsUsds), 200e18);

        usds.__setApproveReverts(address(psm), true);

        vm.prank(address(strategyManager));
        vm.expectRevert("MSS:W:USDS_APPROVE_FAIL");
        strategy.fundUnderlyingStrategy(1, "");
    }

}

contract SkyFundUnderlyingStrategySuccessTests is SkyTestBase {

    function setUp() public override {
        super.setUp();

        strategy.__setStrategyDelegateFeeRate(0);
        strategy.__setStrategyProtocolFeeRate(0);

        psm.__setUsdsDepositExchangeRate(1e18); // 1 USDC  -> 1 USDS
        psm.__setUsdsRedeemExchangeRate(1e18); // 1 USDS  -> 1 USDC
        savingsUsds.__setSusdsDepositExchangeRate(1e18); // 1 USDS  -> 1 sUSDS
        savingsUsds.__setSusdsRedeemExchangeRate(1e18); // 1 sUSDS -> 1 USDS

        asset.mint(address(strategy), 1e30);
    }

    function test_fundUnderlyingStrategy_success_forwardsReferralCode() external {
        uint16 referralCode = 42;

        vm.prank(strategyDelegate);
        strategy.setReferralCode(referralCode);

        vm.expectCall(address(savingsUsds), abi.encodeCall(IERC4626Like.deposit, (100e18, address(strategy), referralCode)));

        vm.prank(address(strategyManager));
        strategy.fundUnderlyingStrategy(100e6, "");

        assertSkyStrategy({
            susdsBalance:            100e18,
            lastRecordedTotalAssets: 100e6,
            assetsUnderManagement:   100e6
        });
    }

    function test_fundUnderlyingStrategy_success_firstDeposit() external {
        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        uint256 assets                  = 100e6;
        uint256 expectedSharesToReceive = 100e18;
        uint256 expectedDeployed        = 100e6;

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyFeesCollected(0, 0);

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyFunded(address(strategyManager), assets, expectedSharesToReceive, expectedDeployed);

        vm.prank(address(strategyManager));
        uint256 deployedAssets = strategy.fundUnderlyingStrategy(assets, "");

        assertEq(deployedAssets, expectedDeployed);

        assertSkyStrategy({
            susdsBalance:            expectedSharesToReceive,
            lastRecordedTotalAssets: expectedDeployed,
            assetsUnderManagement:   expectedDeployed
        });
    }

    function test_fundUnderlyingStrategy_success_secondDeposit_strategyHasYield_withProtocolFees() external {
        /**********************************************************************************************************************************/
        /*** Step 1: Set fee rates                                                                                                      ***/
        /**********************************************************************************************************************************/

        strategy.__setStrategyDelegateFeeRate(0.02e6); // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6); // 3% protocol fee

        /**********************************************************************************************************************************/
        /*** Step 2: Make first deposit                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 lastRecordedAfterFirstDeposit = 100e6;

        strategy.__setLastRecordedTotalAssets(lastRecordedAfterFirstDeposit); // First deposit of 100 USDC
        savingsUsds.__setBalanceOf(address(strategy), 100e18); // Strategy got 100 sUSDS after first deposit
        savingsUsds.__setSusdsRedeemExchangeRate(2e18); // 1 sUSDS = 2 USDS (100% yield)
        savingsUsds.__setSusdsDepositExchangeRate(0.5e18); // 1 USDS  = 0.5 sUSDS at current price

        usds.mint(address(savingsUsds), 200e18); // sUSDS holds 200 USDS reserves to back 100 sUSDS at 2x

        uint256 assetsUnderManagementAfterFirstDeposit = 195e6; // 200 current assets minus 5 assets fees

        assertSkyStrategy({
            susdsBalance:            100e18,
            lastRecordedTotalAssets: lastRecordedAfterFirstDeposit,
            assetsUnderManagement:   assetsUnderManagementAfterFirstDeposit
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 3: Execute and assert                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 secondDepositAssets           = 100e6;
        uint256 expectedDeployedAssets        = 100e6;
        uint256 expectedSharesToReceive       = 50e18;
        uint256 expectedDelegateFee           = 2e6;
        uint256 expectedProtocolFee           = 3e6;
        uint256 expectedLastRecordedAfterFund = 295e6;
        uint256 expectedBalanceAfterFund      = 147.5e18; // 100 (existing) - 2.5 (burnt for 5 USDC fees at rate 2.0) + 50 (new deposit)

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyFeesCollected(expectedDelegateFee, expectedProtocolFee);

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyFunded(
            address(strategyManager),
            secondDepositAssets,
            expectedSharesToReceive,
            expectedDeployedAssets
        );

        vm.prank(address(strategyManager));
        uint256 deployedAssets = strategy.fundUnderlyingStrategy(secondDepositAssets, "");

        assertEq(deployedAssets, expectedDeployedAssets);

        assertSkyStrategy({
            susdsBalance:            expectedBalanceAfterFund,
            lastRecordedTotalAssets: expectedLastRecordedAfterFund,
            assetsUnderManagement:   expectedLastRecordedAfterFund
        });

        assertCollectedFees({
            delegateFee: expectedDelegateFee,
            protocolFee: expectedProtocolFee
        });
    }

    function test_fundUnderlyingStrategy_success_secondDeposit_strategyHasLoss_withProtocolFees() external {
        /**********************************************************************************************************************************/
        /*** Step 1: Set fee rates                                                                                                      ***/
        /**********************************************************************************************************************************/

        strategy.__setStrategyDelegateFeeRate(0.02e6); // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6); // 3% protocol fee

        /**********************************************************************************************************************************/
        /*** Step 2: Make first deposit and simulate loss                                                                               ***/
        /**********************************************************************************************************************************/

        uint256 lastRecordedAfterFirstDeposit = 100e6;

        strategy.__setLastRecordedTotalAssets(lastRecordedAfterFirstDeposit); // First deposit of 100 USDC
        savingsUsds.__setBalanceOf(address(strategy), 100e18); // Strategy holds 100 sUSDS from first deposit
        savingsUsds.__setSusdsRedeemExchangeRate(0.5e18); // 1 sUSDS = 0.5 USDS (50% loss)
        savingsUsds.__setSusdsDepositExchangeRate(2e18); // 1 USDS  = 2 sUSDS at current price

        uint256 assetsUnderManagementAfterFirstDeposit = 50e6; // 100 initial assets minus 50 assets loss

        assertSkyStrategy({
            susdsBalance:            100e18,
            lastRecordedTotalAssets: lastRecordedAfterFirstDeposit,
            assetsUnderManagement:   assetsUnderManagementAfterFirstDeposit
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 3: Execute and assert                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 secondDepositAssets           = 100e6;
        uint256 expectedDeployedAssets        = 100e6;
        uint256 expectedLastRecordedAfterFund = 150e6;
        uint256 expectedBalanceAfterFund      = 300e18; // 100 (existing) + 200 (new deposit), no fees on loss

        vm.prank(address(strategyManager));
        uint256 deployedAssets = strategy.fundUnderlyingStrategy(secondDepositAssets, "");

        assertEq(deployedAssets, expectedDeployedAssets);

        assertSkyStrategy({
            susdsBalance:            expectedBalanceAfterFund,
            lastRecordedTotalAssets: expectedLastRecordedAfterFund,
            assetsUnderManagement:   expectedLastRecordedAfterFund
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });
    }

    function test_fundUnderlyingStrategy_success_firstDeposit_usdsHasRedemptionFee() external {
        psm.__setTout(0.25e18); // USDS redemption fee: 20%

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        vm.prank(address(strategyManager));
        uint256 deployedAssets = strategy.fundUnderlyingStrategy(100e6, "");

        assertEq(deployedAssets, 80e6);

        assertSkyStrategy({
            susdsBalance:            100e18,
            lastRecordedTotalAssets: 80e6,
            assetsUnderManagement:   80e6
        });
    }

    function test_fundUnderlyingStrategy_success_susdsHasRedemptionFee() external {
        savingsUsds.__setSusdsRedeemExchangeRate(0.99e18); // sUSDS redemption fee: 1%

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        vm.prank(address(strategyManager));
        uint256 deployedAssets = strategy.fundUnderlyingStrategy(100e6, "");

        assertEq(deployedAssets, 99e6);

        assertSkyStrategy({
            susdsBalance:            100e18,
            lastRecordedTotalAssets: 99e6,
            assetsUnderManagement:   99e6
        });
    }

    function test_fundUnderlyingStrategy_success_susdsRedemptionFeeStacksWithUsdsRedemptionFee() external {
        psm.__setTout(0.25e18); // USDS redemption fee: 25%
        savingsUsds.__setSusdsRedeemExchangeRate(0.99e18); // sUSDS redemption fee: 1%

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        vm.prank(address(strategyManager));
        uint256 deployedAssets = strategy.fundUnderlyingStrategy(100e6, "");

        assertEq(deployedAssets, 79.2e6);

        assertSkyStrategy({
            susdsBalance:            100e18,
            lastRecordedTotalAssets: 79.2e6,
            assetsUnderManagement:   79.2e6
        });
    }

    function test_fundUnderlyingStrategy_success_usdsHasDepositFee() external {
        psm.__setUsdsDepositExchangeRate(0.99e18); // USDS deposit fee: 1%

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        vm.prank(address(strategyManager));
        uint256 deployedAssets = strategy.fundUnderlyingStrategy(100e6, "");

        assertEq(deployedAssets, 99e6);

        assertSkyStrategy({
            susdsBalance:            99e18,
            lastRecordedTotalAssets: 99e6,
            assetsUnderManagement:   99e6
        });
    }

    function test_fundUnderlyingStrategy_success_susdsHasDepositFee() external {
        savingsUsds.__setSusdsDepositExchangeRate(0.95e18); // sUSDS deposit fee: 5%

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        vm.prank(address(strategyManager));
        uint256 deployedAssets = strategy.fundUnderlyingStrategy(100e6, "");

        assertEq(deployedAssets, 95e6);

        assertSkyStrategy({
            susdsBalance:            95e18,
            lastRecordedTotalAssets: 95e6,
            assetsUnderManagement:   95e6
        });
    }

    function test_fundUnderlyingStrategy_success_susdsHasMaxDepositFee() external {
        savingsUsds.__setSusdsDepositExchangeRate(0); // sUSDS deposit fee: 100%

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        vm.prank(address(strategyManager));
        uint256 deployedAssets = strategy.fundUnderlyingStrategy(100e6, "");

        assertEq(deployedAssets, 0);

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

    function test_fundUnderlyingStrategy_success_susdsDepositFeeStacksWithUsdsDepositFee() external {
        psm.__setUsdsDepositExchangeRate(0.99e18); // USDS deposit fee: 1%
        savingsUsds.__setSusdsDepositExchangeRate(0.95e18); // sUSDS deposit fee: 5%

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        vm.prank(address(strategyManager));
        uint256 deployedAssets = strategy.fundUnderlyingStrategy(100e6, "");

        assertEq(deployedAssets, 94.05e6); // 100 USDC * 0.99 * 0.95

        assertSkyStrategy({
            susdsBalance:            94.05e18,
            lastRecordedTotalAssets: 94.05e6,
            assetsUnderManagement:   94.05e6
        });
    }

    function test_fundUnderlyingStrategy_success_secondDeposit_usdsRedemptionFeeDecreased_phantomYield() external {
        /**********************************************************************************************************************************/
        /*** Step 1: Set fee rates                                                                                                      ***/
        /**********************************************************************************************************************************/

        strategy.__setStrategyDelegateFeeRate(0.02e6); // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6); // 3% protocol fee

        /**********************************************************************************************************************************/
        /*** Step 2: Make first deposit with USDS redemption fee at 25%                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 firstDepositAssets            = 100e6;
        uint256 lastRecordedAfterFirstDeposit = 80e6;
        uint256 expectedBalanceAfterFirstFund = 100e18;

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        psm.__setTout(0.25e18); // USDS redemption fee: 25%

        vm.prank(address(strategyManager));
        strategy.fundUnderlyingStrategy(firstDepositAssets, "");

        assertSkyStrategy({
            susdsBalance:            expectedBalanceAfterFirstFund,
            lastRecordedTotalAssets: lastRecordedAfterFirstDeposit,
            assetsUnderManagement:   lastRecordedAfterFirstDeposit
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 3: USDS redemption fee drops to 0 between deposits                                                                    ***/
        /**********************************************************************************************************************************/

        psm.__setTout(0); // USDS redemption fee: 0%

        /**********************************************************************************************************************************/
        /*** Step 4: Execute and assert                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 secondDepositAssets           = 100e6;
        uint256 expectedDeployedAssets        = 100e6;
        uint256 expectedDelegateFee           = 0.4e6; // phantom 20e6 yield * 2%
        uint256 expectedProtocolFee           = 0.6e6; // phantom 20e6 yield * 3%
        uint256 expectedLastRecordedAfterFund = 199e6;
        uint256 expectedBalanceAfterFund      = 199e18; // 100 (existing) - 1 (burnt for 1 USDC fees at rate 1.0) + 100 (new deposit)

        vm.prank(address(strategyManager));
        uint256 deployedAssets = strategy.fundUnderlyingStrategy(secondDepositAssets, "");

        assertEq(deployedAssets, expectedDeployedAssets);

        assertSkyStrategy({
            susdsBalance:            expectedBalanceAfterFund,
            lastRecordedTotalAssets: expectedLastRecordedAfterFund,
            assetsUnderManagement:   expectedLastRecordedAfterFund
        });

        assertCollectedFees({
            delegateFee: expectedDelegateFee,
            protocolFee: expectedProtocolFee
        });
    }

    function test_fundUnderlyingStrategy_success_secondDeposit_usdsRedemptionFeeIncreased() external {
        /**********************************************************************************************************************************/
        /*** Step 1: Set fee rates                                                                                                      ***/
        /**********************************************************************************************************************************/

        strategy.__setStrategyDelegateFeeRate(0.02e6); // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6); // 3% protocol fee

        /**********************************************************************************************************************************/
        /*** Step 2: Make first deposit with no USDS redemption fee                                                                     ***/
        /**********************************************************************************************************************************/

        uint256 lastRecordedAfterFirstDeposit = 100e6;

        strategy.__setLastRecordedTotalAssets(lastRecordedAfterFirstDeposit); // baseline at 100 USDC
        savingsUsds.__setBalanceOf(address(strategy), 100e18); // strategy holds 100 sUSDS

        assertSkyStrategy({
            susdsBalance:            100e18,
            lastRecordedTotalAssets: lastRecordedAfterFirstDeposit,
            assetsUnderManagement:   lastRecordedAfterFirstDeposit
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 3: USDS redemption fee rises to 20% between deposits                                                                  ***/
        /**********************************************************************************************************************************/

        psm.__setTout(0.25e18); // USDS redemption fee: 20%

        /**********************************************************************************************************************************/
        /*** Step 4: Execute and assert                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 secondDepositAssets           = 100e6;
        uint256 expectedDeployedAssets        = 80e6; // _gemForUsds(100e18, tout=0.25e18)
        uint256 expectedLastRecordedAfterFund = 160e6; // _gemForUsds(200e18, tout=0.25e18)
        uint256 expectedBalanceAfterFund      = 200e18; // 100 (existing) + 100 (new deposit), no fees on loss

        vm.prank(address(strategyManager));
        uint256 deployedAssets = strategy.fundUnderlyingStrategy(secondDepositAssets, "");

        assertEq(deployedAssets, expectedDeployedAssets);

        assertSkyStrategy({
            susdsBalance:            expectedBalanceAfterFund,
            lastRecordedTotalAssets: expectedLastRecordedAfterFund,
            assetsUnderManagement:   expectedLastRecordedAfterFund
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });
    }

    function test_fundUnderlyingStrategy_success_secondDeposit_susdsValueIncreased() external {
        /**********************************************************************************************************************************/
        /*** Step 1: Set fee rates                                                                                                      ***/
        /**********************************************************************************************************************************/

        strategy.__setStrategyDelegateFeeRate(0.02e6); // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6); // 3% protocol fee

        /**********************************************************************************************************************************/
        /*** Step 2: Make first deposit when sUSDS shares are worth 0.99 USDS each                                                      ***/
        /**********************************************************************************************************************************/

        uint256 firstDepositAssets            = 100e6;
        uint256 lastRecordedAfterFirstDeposit = 99e6;
        uint256 expectedBalanceAfterFirstFund = 100e18;

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        savingsUsds.__setSusdsRedeemExchangeRate(0.99e18); // shares worth 0.99 USDS each

        vm.prank(address(strategyManager));
        strategy.fundUnderlyingStrategy(firstDepositAssets, "");

        assertSkyStrategy({
            susdsBalance:            expectedBalanceAfterFirstFund,
            lastRecordedTotalAssets: lastRecordedAfterFirstDeposit,
            assetsUnderManagement:   lastRecordedAfterFirstDeposit
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 3: sUSDS shares appreciate to 1.0 USDS each between deposits                                                          ***/
        /**********************************************************************************************************************************/

        savingsUsds.__setSusdsRedeemExchangeRate(1e18); // shares worth 1.0 USDS each

        /**********************************************************************************************************************************/
        /*** Step 4: Execute and assert                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 secondDepositAssets           = 100e6;
        uint256 expectedDeployedAssets        = 100e6;
        uint256 expectedDelegateFee           = 0.02e6; // 1e6 yield * 2%
        uint256 expectedProtocolFee           = 0.03e6; // 1e6 yield * 3%
        uint256 expectedLastRecordedAfterFund = 199.95e6;
        uint256 expectedBalanceAfterFund      = 199.95e18; // 100 (existing) - 0.05 (burnt for 0.05 USDC fees at rate 1.0) + 100 (new)

        vm.prank(address(strategyManager));
        uint256 deployedAssets = strategy.fundUnderlyingStrategy(secondDepositAssets, "");

        assertEq(deployedAssets, expectedDeployedAssets);

        assertSkyStrategy({
            susdsBalance:            expectedBalanceAfterFund,
            lastRecordedTotalAssets: expectedLastRecordedAfterFund,
            assetsUnderManagement:   expectedLastRecordedAfterFund
        });

        assertCollectedFees({
            delegateFee: expectedDelegateFee,
            protocolFee: expectedProtocolFee
        });
    }

    function test_fundUnderlyingStrategy_success_secondDeposit_susdsLostValue() external {
        /**********************************************************************************************************************************/
        /*** Step 1: Set fee rates                                                                                                      ***/
        /**********************************************************************************************************************************/

        strategy.__setStrategyDelegateFeeRate(0.02e6); // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6); // 3% protocol fee

        /**********************************************************************************************************************************/
        /*** Step 2: Make first deposit when sUSDS shares are worth 1.0 USDS each                                                       ***/
        /**********************************************************************************************************************************/

        uint256 firstDepositAssets            = 100e6;
        uint256 lastRecordedAfterFirstDeposit = 100e6;
        uint256 expectedBalanceAfterFirstFund = 100e18;

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        vm.prank(address(strategyManager));
        strategy.fundUnderlyingStrategy(firstDepositAssets, "");

        assertSkyStrategy({
            susdsBalance:            expectedBalanceAfterFirstFund,
            lastRecordedTotalAssets: lastRecordedAfterFirstDeposit,
            assetsUnderManagement:   lastRecordedAfterFirstDeposit
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 3: sUSDS shares lose 1% of value between deposits                                                                     ***/
        /**********************************************************************************************************************************/

        savingsUsds.__setSusdsRedeemExchangeRate(0.99e18); // shares worth 0.99 USDS each

        /**********************************************************************************************************************************/
        /*** Step 4: Execute and assert                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 secondDepositAssets           = 100e6;
        uint256 expectedDeployedAssets        = 99e6; // new shares valued at the new (lower) share value
        uint256 expectedLastRecordedAfterFund = 198e6;
        uint256 expectedBalanceAfterFund      = 200e18; // 100 (existing) + 100 (new), no fees on loss

        vm.prank(address(strategyManager));
        uint256 deployedAssets = strategy.fundUnderlyingStrategy(secondDepositAssets, "");

        assertEq(deployedAssets, expectedDeployedAssets);

        assertSkyStrategy({
            susdsBalance:            expectedBalanceAfterFund,
            lastRecordedTotalAssets: expectedLastRecordedAfterFund,
            assetsUnderManagement:   expectedLastRecordedAfterFund
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });
    }

    function test_fundUnderlyingStrategy_success_secondDeposit_usdsDepositFeeDecreased() external {
        /**********************************************************************************************************************************/
        /*** Step 1: Set fee rates                                                                                                      ***/
        /**********************************************************************************************************************************/

        strategy.__setStrategyDelegateFeeRate(0.02e6); // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6); // 3% protocol fee

        /**********************************************************************************************************************************/
        /*** Step 2: Make first deposit with USDS deposit fee at 1%                                                                     ***/
        /**********************************************************************************************************************************/

        uint256 firstDepositAssets            = 100e6;
        uint256 lastRecordedAfterFirstDeposit = 99e6;
        uint256 expectedBalanceAfterFirstFund = 99e18;

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        psm.__setUsdsDepositExchangeRate(0.99e18); // USDS deposit fee: 1%

        vm.prank(address(strategyManager));
        strategy.fundUnderlyingStrategy(firstDepositAssets, "");

        assertSkyStrategy({
            susdsBalance:            expectedBalanceAfterFirstFund,
            lastRecordedTotalAssets: lastRecordedAfterFirstDeposit,
            assetsUnderManagement:   lastRecordedAfterFirstDeposit
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 3: USDS removes deposit fee between deposits                                                                          ***/
        /**********************************************************************************************************************************/

        psm.__setUsdsDepositExchangeRate(1e18); // USDS deposit fee: 0% (removed)

        /**********************************************************************************************************************************/
        /*** Step 4: Execute and assert                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 secondDepositAssets           = 100e6;
        uint256 expectedDeployedAssets        = 100e6;
        uint256 expectedLastRecordedAfterFund = 199e6;
        uint256 expectedBalanceAfterFund      = 199e18; // 99 (existing) + 100 (new), no fees

        vm.prank(address(strategyManager));
        uint256 deployedAssets = strategy.fundUnderlyingStrategy(secondDepositAssets, "");

        assertEq(deployedAssets, expectedDeployedAssets);

        assertSkyStrategy({
            susdsBalance:            expectedBalanceAfterFund,
            lastRecordedTotalAssets: expectedLastRecordedAfterFund,
            assetsUnderManagement:   expectedLastRecordedAfterFund
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });
    }

    function test_fundUnderlyingStrategy_success_secondDeposit_usdsDepositFeeIncreased() external {
        /**********************************************************************************************************************************/
        /*** Step 1: Set fee rates                                                                                                      ***/
        /**********************************************************************************************************************************/

        strategy.__setStrategyDelegateFeeRate(0.02e6); // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6); // 3% protocol fee

        /**********************************************************************************************************************************/
        /*** Step 2: Make first deposit with no USDS deposit fee                                                                        ***/
        /**********************************************************************************************************************************/

        uint256 firstDepositAssets            = 100e6;
        uint256 lastRecordedAfterFirstDeposit = 100e6;
        uint256 expectedBalanceAfterFirstFund = 100e18;

        assertEq(savingsUsds.balanceOf(address(strategy)), 0);

        vm.prank(address(strategyManager));
        strategy.fundUnderlyingStrategy(firstDepositAssets, "");

        assertSkyStrategy({
            susdsBalance:            expectedBalanceAfterFirstFund,
            lastRecordedTotalAssets: lastRecordedAfterFirstDeposit,
            assetsUnderManagement:   lastRecordedAfterFirstDeposit
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 3: USDS adds 1% deposit fee between deposits                                                                          ***/
        /**********************************************************************************************************************************/

        psm.__setUsdsDepositExchangeRate(0.99e18); // USDS deposit fee: 1%

        /**********************************************************************************************************************************/
        /*** Step 4: Execute and assert                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 secondDepositAssets           = 100e6;
        uint256 expectedDeployedAssets        = 99e6;
        uint256 expectedLastRecordedAfterFund = 199e6;
        uint256 expectedBalanceAfterFund      = 199e18; // 100 (existing) + 99 (new), no fees

        vm.prank(address(strategyManager));
        uint256 deployedAssets = strategy.fundUnderlyingStrategy(secondDepositAssets, "");

        assertEq(deployedAssets, expectedDeployedAssets);

        assertSkyStrategy({
            susdsBalance:            expectedBalanceAfterFund,
            lastRecordedTotalAssets: expectedLastRecordedAfterFund,
            assetsUnderManagement:   expectedLastRecordedAfterFund
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });
    }

    function test_fundUnderlyingStrategy_success_secondDeposit_susdsDepositFeeDecreased() external {
        /**********************************************************************************************************************************/
        /*** Step 1: Set fee rates                                                                                                      ***/
        /**********************************************************************************************************************************/

        strategy.__setStrategyDelegateFeeRate(0.02e6); // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6); // 3% protocol fee

        /**********************************************************************************************************************************/
        /*** Step 2: Make first deposit with sUSDS deposit fee at 5%                                                                    ***/
        /**********************************************************************************************************************************/

        uint256 firstDepositAssets            = 100e6;
        uint256 lastRecordedAfterFirstDeposit = 95e6;
        uint256 expectedBalanceAfterFirstFund = 95e18;

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        savingsUsds.__setSusdsDepositExchangeRate(0.95e18); // sUSDS deposit fee: 5%

        vm.prank(address(strategyManager));
        strategy.fundUnderlyingStrategy(firstDepositAssets, "");

        assertSkyStrategy({
            susdsBalance:            expectedBalanceAfterFirstFund,
            lastRecordedTotalAssets: lastRecordedAfterFirstDeposit,
            assetsUnderManagement:   lastRecordedAfterFirstDeposit
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 3: sUSDS removes deposit fee between deposits                                                                         ***/
        /**********************************************************************************************************************************/

        savingsUsds.__setSusdsDepositExchangeRate(1e18); // sUSDS deposit fee: 0% (removed)

        /**********************************************************************************************************************************/
        /*** Step 4: Execute and assert                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 secondDepositAssets           = 100e6;
        uint256 expectedDeployedAssets        = 100e6;
        uint256 expectedLastRecordedAfterFund = 195e6;
        uint256 expectedBalanceAfterFund      = 195e18; // 95 (existing) + 100 (new), no fees

        vm.prank(address(strategyManager));
        uint256 deployedAssets = strategy.fundUnderlyingStrategy(secondDepositAssets, "");

        assertEq(deployedAssets, expectedDeployedAssets);

        assertSkyStrategy({
            susdsBalance:            expectedBalanceAfterFund,
            lastRecordedTotalAssets: expectedLastRecordedAfterFund,
            assetsUnderManagement:   expectedLastRecordedAfterFund
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });
    }

    function test_fundUnderlyingStrategy_success_secondDeposit_susdsDepositFeeIncreased() external {
        /**********************************************************************************************************************************/
        /*** Step 1: Set fee rates                                                                                                      ***/
        /**********************************************************************************************************************************/

        strategy.__setStrategyDelegateFeeRate(0.02e6); // 2% delegate fee
        strategy.__setStrategyProtocolFeeRate(0.03e6); // 3% protocol fee

        /**********************************************************************************************************************************/
        /*** Step 2: Make first deposit with no sUSDS deposit fee                                                                       ***/
        /**********************************************************************************************************************************/

        uint256 firstDepositAssets            = 100e6;
        uint256 lastRecordedAfterFirstDeposit = 100e6;
        uint256 expectedBalanceAfterFirstFund = 100e18;

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        vm.prank(address(strategyManager));
        strategy.fundUnderlyingStrategy(firstDepositAssets, "");

        assertSkyStrategy({
            susdsBalance:            expectedBalanceAfterFirstFund,
            lastRecordedTotalAssets: lastRecordedAfterFirstDeposit,
            assetsUnderManagement:   lastRecordedAfterFirstDeposit
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        /**********************************************************************************************************************************/
        /*** Step 3: sUSDS adds 5% deposit fee between deposits                                                                         ***/
        /**********************************************************************************************************************************/

        savingsUsds.__setSusdsDepositExchangeRate(0.95e18); // sUSDS deposit fee: 5%

        /**********************************************************************************************************************************/
        /*** Step 4: Execute and assert                                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 secondDepositAssets           = 100e6;
        uint256 expectedDeployedAssets        = 95e6;
        uint256 expectedLastRecordedAfterFund = 195e6;
        uint256 expectedBalanceAfterFund      = 195e18; // 100 (existing) + 95 (new), no fees

        vm.prank(address(strategyManager));
        uint256 deployedAssets = strategy.fundUnderlyingStrategy(secondDepositAssets, "");

        assertEq(deployedAssets, expectedDeployedAssets);

        assertSkyStrategy({
            susdsBalance:            expectedBalanceAfterFund,
            lastRecordedTotalAssets: expectedLastRecordedAfterFund,
            assetsUnderManagement:   expectedLastRecordedAfterFund
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });
    }

}
