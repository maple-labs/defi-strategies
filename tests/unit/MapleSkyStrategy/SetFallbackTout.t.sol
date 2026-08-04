// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleSkyStrategy } from "../../../contracts/interfaces/IMapleSkyStrategy.sol";

import { MapleSkyStrategy } from "../../../contracts/sky/MapleSkyStrategy.sol";

import { SkyTestBase } from "../../utils/SkyTestBase.sol";

contract SkySetFallbackToutFailureTests is SkyTestBase {

    function test_setFallbackTout_revert_functionPaused() external {
        globals.__setIsFunctionPaused(MapleSkyStrategy.setFallbackTout.selector, true);

        vm.prank(governor);
        vm.expectRevert("MSS:PAUSED");
        strategy.setFallbackTout(0.25e18);
    }

    function test_setFallbackTout_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(governor);
        vm.expectRevert("MSS:LOCKED");
        strategy.setFallbackTout(0.25e18);
    }

    function test_setFallbackTout_revert_notAdmin() external {
        vm.expectRevert("MSS:NOT_ADMIN");
        strategy.setFallbackTout(0.25e18);
    }

    function test_setFallbackTout_revert_lossRecognized() external {
        strategy.__setIsLossRecognized(true);

        vm.prank(governor);
        vm.expectRevert("MSS:LOSS_RECOGNIZED");
        strategy.setFallbackTout(0.25e18);
    }

    function test_setFallbackTout_revert_noChange() external {
        strategy.__setFallbackTout(0.25e18);

        vm.prank(governor);
        vm.expectRevert("MSS:SFT:NO_CHANGE");
        strategy.setFallbackTout(0.25e18);
    }

    function test_setFallbackTout_revert_invalidTout() external {
        vm.prank(governor);
        vm.expectRevert("MSS:SFT:INVALID_TOUT");
        strategy.setFallbackTout(type(uint256).max);
    }

}

contract SkySetFallbackToutSuccessTests is SkyTestBase {

    function test_setFallbackTout_success_governor() external {
        uint256 fallbackTout_ = 0.25e18;

        assertEq(strategy.fallbackTout(), 0);

        vm.expectEmit();
        emit IMapleSkyStrategy.FallbackToutSet(fallbackTout_);

        vm.prank(governor);
        strategy.setFallbackTout(fallbackTout_);

        assertEq(strategy.fallbackTout(), fallbackTout_);
    }

    function test_setFallbackTout_success_operationalAdmin() external {
        uint256 fallbackTout_ = 0.25e18;

        assertEq(strategy.fallbackTout(), 0);

        vm.expectEmit();
        emit IMapleSkyStrategy.FallbackToutSet(fallbackTout_);

        vm.prank(operationalAdmin);
        strategy.setFallbackTout(fallbackTout_);

        assertEq(strategy.fallbackTout(), fallbackTout_);
    }

    function test_setFallbackTout_success_updatesExistingValue() external {
        strategy.__setFallbackTout(0.1e18);

        uint256 fallbackTout_ = 0.25e18;

        assertEq(strategy.fallbackTout(), 0.1e18);

        vm.expectEmit();
        emit IMapleSkyStrategy.FallbackToutSet(fallbackTout_);

        vm.prank(governor);
        strategy.setFallbackTout(fallbackTout_);

        assertEq(strategy.fallbackTout(), fallbackTout_);
    }

    function test_setFallbackTout_success_clearsToZero() external {
        strategy.__setFallbackTout(0.25e18);

        assertEq(strategy.fallbackTout(), 0.25e18);

        vm.expectEmit();
        emit IMapleSkyStrategy.FallbackToutSet(0);

        vm.prank(governor);
        strategy.setFallbackTout(0);

        assertEq(strategy.fallbackTout(), 0);
    }

    function test_setFallbackTout_success_psmHaltThenUnhaltUnchangedAum() external {
        uint256 tout = 0.25e18;
        uint256 aum  = 80e6;

        savingsUsds.__setSusdsRedeemExchangeRate(1e18);
        strategy.__setLastRecordedTotalAssets(100e6);
        savingsUsds.__setBalanceOf(address(strategy), 100e18);

        psm.__setTout(tout);

        vm.prank(governor);
        strategy.setFallbackTout(tout);

        assertEq(strategy.assetsUnderManagement(), aum);

        psm.__setTout(type(uint256).max);

        assertEq(strategy.assetsUnderManagement(), aum);

        psm.__setTout(tout);

        assertEq(strategy.assetsUnderManagement(), aum);
    }

}
