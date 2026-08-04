// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleAaveV3Strategy } from "../../../contracts/interfaces/IMapleAaveV3Strategy.sol";

import { AaveV3TestBase } from "../../utils/AaveV3TestBase.sol";

contract AaveV3SetReferralCodeFailureTests is AaveV3TestBase {

    uint16 referralCode = 42;

    function test_setReferralCode_revert_functionPaused() external {
        globals.__setIsFunctionPaused(IMapleAaveV3Strategy.setReferralCode.selector, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:PAUSED");
        strategy.setReferralCode(referralCode);
    }

    function test_setReferralCode_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:LOCKED");
        strategy.setReferralCode(referralCode);
    }

    function test_setReferralCode_revert_notAuthorized() external {
        vm.prank(governor);
        vm.expectRevert("MAV3S:NOT_AUTHORIZED");
        strategy.setReferralCode(referralCode);
    }

    function test_setReferralCode_revert_lossRecognized() external {
        strategy.__setIsLossRecognized(true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:LOSS_RECOGNIZED");
        strategy.setReferralCode(referralCode);
    }

    function test_setReferralCode_revert_noChange() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:SRC:NO_CHANGE");
        strategy.setReferralCode(INITIAL_REFERRAL_CODE);
    }

}

contract AaveV3SetReferralCodeSuccessTests is AaveV3TestBase {

    uint16 referralCode = 42;

    function test_setReferralCode_success_strategyDelegate() external {
        assertEq(strategy.referralCode(), INITIAL_REFERRAL_CODE);

        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        vm.expectEmit();
        emit IMapleAaveV3Strategy.ReferralCodeSet(referralCode);

        vm.prank(strategyDelegate);
        strategy.setReferralCode(referralCode);

        assertEq(strategy.referralCode(), referralCode);

        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

    function test_setReferralCode_success_operationalAdmin() external {
        assertEq(strategy.referralCode(), INITIAL_REFERRAL_CODE);

        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        vm.expectEmit();
        emit IMapleAaveV3Strategy.ReferralCodeSet(referralCode);

        vm.prank(operationalAdmin);
        strategy.setReferralCode(referralCode);

        assertEq(strategy.referralCode(), referralCode);

        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

    function test_setReferralCode_success_zeroReferralCode() external {
        assertEq(strategy.referralCode(), INITIAL_REFERRAL_CODE);

        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        vm.expectEmit();
        emit IMapleAaveV3Strategy.ReferralCodeSet(0);

        vm.prank(strategyDelegate);
        strategy.setReferralCode(0);

        assertEq(strategy.referralCode(), 0);

        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

    function test_setReferralCode_success_maxReferralCode() external {
        uint16 referralCode_ = type(uint16).max;

        assertEq(strategy.referralCode(), INITIAL_REFERRAL_CODE);

        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        vm.expectEmit();
        emit IMapleAaveV3Strategy.ReferralCodeSet(referralCode_);

        vm.prank(strategyDelegate);
        strategy.setReferralCode(referralCode_);

        assertEq(strategy.referralCode(), referralCode_);

        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

}
