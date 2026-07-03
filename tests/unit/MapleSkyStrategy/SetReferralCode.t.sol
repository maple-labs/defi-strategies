// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleSkyStrategy } from "../../../contracts/interfaces/IMapleSkyStrategy.sol";

import { SkyTestBase } from "../../utils/SkyTestBase.sol";

contract SkySetReferralCodeFailureTests is SkyTestBase {

    uint16 referralCode = 42;

    function test_setReferralCode_revert_functionPaused() external {
        globals.__setIsFunctionPaused(IMapleSkyStrategy.setReferralCode.selector, true);

        vm.prank(governor);
        vm.expectRevert("MSS:PAUSED");
        strategy.setReferralCode(referralCode);
    }

    function test_setReferralCode_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(governor);
        vm.expectRevert("MSS:LOCKED");
        strategy.setReferralCode(referralCode);
    }

    function test_setReferralCode_revert_notAdmin() external {
        vm.expectRevert("MSS:NOT_ADMIN");
        strategy.setReferralCode(referralCode);
    }

    function test_setReferralCode_revert_noChange() external {
        vm.prank(governor);
        vm.expectRevert("MSS:SRC:NO_CHANGE");
        strategy.setReferralCode(INITIAL_REFERRAL_CODE);
    }

}

contract SkySetReferralCodeSuccessTests is SkyTestBase {

    uint16 referralCode = 42;

    function test_setReferralCode_success_governor() external {
        assertEq(strategy.referralCode(), INITIAL_REFERRAL_CODE);

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        vm.expectEmit();
        emit IMapleSkyStrategy.ReferralCodeSet(referralCode);

        vm.prank(governor);
        strategy.setReferralCode(referralCode);

        assertEq(strategy.referralCode(), referralCode);

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

    function test_setReferralCode_success_operationalAdmin() external {
        assertEq(strategy.referralCode(), INITIAL_REFERRAL_CODE);

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        vm.expectEmit();
        emit IMapleSkyStrategy.ReferralCodeSet(referralCode);

        vm.prank(operationalAdmin);
        strategy.setReferralCode(referralCode);

        assertEq(strategy.referralCode(), referralCode);

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

    function test_setReferralCode_success_zeroReferralCode() external {
        assertEq(strategy.referralCode(), INITIAL_REFERRAL_CODE);

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        vm.expectEmit();
        emit IMapleSkyStrategy.ReferralCodeSet(0);

        vm.prank(governor);
        strategy.setReferralCode(0);

        assertEq(strategy.referralCode(), 0);

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

    function test_setReferralCode_success_maxReferralCode() external {
        uint16 referralCode_ = type(uint16).max;

        assertEq(strategy.referralCode(), INITIAL_REFERRAL_CODE);

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        vm.expectEmit();
        emit IMapleSkyStrategy.ReferralCodeSet(referralCode_);

        vm.prank(governor);
        strategy.setReferralCode(referralCode_);

        assertEq(strategy.referralCode(), referralCode_);

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

}
