// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleSkyStrategy } from "../../../contracts/interfaces/IMapleSkyStrategy.sol";

import { MapleSkyStrategy } from "../../../contracts/sky/MapleSkyStrategy.sol";

import { MockPsm }     from "../../utils/Mocks.sol";
import { SkyTestBase } from "../../utils/SkyTestBase.sol";

contract SkySetPsmTestsBase is SkyTestBase {

    address newPsmPocket = makeAddr("newPsmPocket");

    MockPsm newPsm = new MockPsm();

    function setUp() public virtual override {
        super.setUp();

        newPsm.__setGem(address(asset));
        newPsm.__setPocket(newPsmPocket);
        newPsm.__setTo18ConversionFactor(1e12);
        newPsm.__setUsds(address(usds));

        asset.mint(newPsmPocket, 1e36);

        vm.prank(newPsmPocket);
        asset.approve(address(newPsm), type(uint256).max);

        globals.__setIsInstanceOf("PSM", address(newPsm), true);
    }

}

contract SkySetPsmFailureTests is SkySetPsmTestsBase {

    function test_setPsm_revert_protocolPaused() external {
        globals.__setIsFunctionPaused(MapleSkyStrategy.setPsm.selector, true);

        vm.prank(governor);
        vm.expectRevert("MSS:PAUSED");
        strategy.setPsm(address(newPsm));
    }

    function test_setPsm_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(governor);
        vm.expectRevert("MSS:LOCKED");
        strategy.setPsm(address(newPsm));
    }

    function test_setPsm_revert_notAdmin() external {
        vm.expectRevert("MSS:NOT_ADMIN");
        strategy.setPsm(address(newPsm));
    }

    function test_setPsm_revert_noChange() external {
        vm.prank(governor);
        vm.expectRevert("MSS:SP:NO_CHANGE");
        strategy.setPsm(address(psm));
    }

    function test_setPsm_revert_invalidPsm() external {
        globals.__setIsInstanceOf("PSM", address(newPsm), false);

        vm.prank(governor);
        vm.expectRevert("MSS:SP:INVALID_PSM");
        strategy.setPsm(address(newPsm));
    }

    function test_setPsm_revert_invalidGemPsm() external {
        newPsm.__setGem(makeAddr("invalidGem"));

        vm.prank(governor);
        vm.expectRevert("MSS:SP:INVALID_GEM_PSM");
        strategy.setPsm(address(newPsm));
    }

    function test_setPsm_revert_invalidUsdsPsm() external {
        newPsm.__setUsds(makeAddr("invalidUsds"));

        vm.prank(governor);
        vm.expectRevert("MSS:SP:INVALID_USDS_PSM");
        strategy.setPsm(address(newPsm));
    }

    function test_setPsm_revert_invalidPocketPsm() external {
        newPsm.__setPocket(address(0));

        vm.prank(governor);
        vm.expectRevert("MSS:SP:INVALID_POCKET_PSM");
        strategy.setPsm(address(newPsm));
    }

}

contract SkySetPsmSuccessTests is SkySetPsmTestsBase {

    function test_setPsm_success_governor() external {
        assertEq(strategy.psm(), address(psm));

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        vm.expectEmit();
        emit IMapleSkyStrategy.PsmSet(address(newPsm));

        vm.prank(governor);
        strategy.setPsm(address(newPsm));

        assertEq(strategy.psm(), address(newPsm));

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

    function test_setPsm_success_operationalAdmin() external {
        assertEq(strategy.psm(), address(psm));

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        vm.expectEmit();
        emit IMapleSkyStrategy.PsmSet(address(newPsm));

        vm.prank(operationalAdmin);
        strategy.setPsm(address(newPsm));

        assertEq(strategy.psm(), address(newPsm));

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

    function test_setPsm_success_doesNotAccrueFeesOrUpdateBaseline() external {
        savingsUsds.__setSusdsRedeemExchangeRate(2e18);

        uint256 expectedSusdsBalanceBeforeSet          = 100e18; // 100 sUSDS balance.
        uint256 expectedLastRecordedBeforeSet          = 100e6;  // Existing recorded assets before 100e6 yield.
        uint256 expectedAssetsUnderManagementBeforeSet = 195e6;  // 200e6 current assets - 5e6 accrued fees.

        setSkyStrategyState({
            lastRecordedTotalAssets_: expectedLastRecordedBeforeSet,
            susdsBalance_:            expectedSusdsBalanceBeforeSet
        });

        assertEq(strategy.psm(), address(psm));

        assertSkyStrategy({
            susdsBalance:            expectedSusdsBalanceBeforeSet,
            lastRecordedTotalAssets: expectedLastRecordedBeforeSet,
            assetsUnderManagement:   expectedAssetsUnderManagementBeforeSet
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });

        vm.expectEmit();
        emit IMapleSkyStrategy.PsmSet(address(newPsm));

        vm.prank(governor);
        strategy.setPsm(address(newPsm));

        assertEq(strategy.psm(), address(newPsm));

        assertSkyStrategy({
            susdsBalance:            expectedSusdsBalanceBeforeSet,
            lastRecordedTotalAssets: expectedLastRecordedBeforeSet,
            assetsUnderManagement:   expectedAssetsUnderManagementBeforeSet
        });

        assertCollectedFees({
            delegateFee: 0,
            protocolFee: 0
        });
    }

    function test_setPsm_success_viewsUseNewPsm() external {
        strategy.__setStrategyDelegateFeeRate(0); // 0% delegate fee.
        strategy.__setStrategyProtocolFeeRate(0); // 0% protocol fee.

        savingsUsds.__setSusdsRedeemExchangeRate(2e18);

        uint256 susdsBalance_       = 100e18; // 100 sUSDS balance.
        uint256 oldPsmAum_          = 200e6;  // 200e18 USDS / 1e12 old PSM conversion factor.
        uint256 newPsmAum_          = 100e6;  // 200e18 USDS / 2e12 new PSM conversion factor.
        uint256 newPsmLiquidity_    = 70e6;   // New PSM pocket liquidity is below 100e6 AUM.
        uint256 newPsmConversion_   = 2e12;   // New PSM converts 2e12 USDS units per asset.
        uint256 lastRecordedAssets_ = 0;

        setSkyStrategyState({
            lastRecordedTotalAssets_: lastRecordedAssets_,
            susdsBalance_:            susdsBalance_
        });

        newPsm.__setTo18ConversionFactor(newPsmConversion_);

        asset.burn(newPsmPocket, asset.balanceOf(newPsmPocket) - newPsmLiquidity_);

        assertEq(strategy.psm(), address(psm));

        assertSkyStrategy({
            susdsBalance:            susdsBalance_,
            lastRecordedTotalAssets: lastRecordedAssets_,
            assetsUnderManagement:   oldPsmAum_
        });

        vm.prank(governor);
        strategy.setPsm(address(newPsm));

        assertEq(strategy.psm(),                 address(newPsm));
        assertEq(strategy.availableToWithdraw(), newPsmLiquidity_);

        assertSkyStrategy({
            susdsBalance:            susdsBalance_,
            lastRecordedTotalAssets: lastRecordedAssets_,
            assetsUnderManagement:   newPsmAum_
        });
    }

}
