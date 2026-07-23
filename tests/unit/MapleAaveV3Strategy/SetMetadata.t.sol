// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleAaveV3Strategy } from "../../../contracts/interfaces/IMapleAaveV3Strategy.sol";

import { AaveV3TestBase } from "../../utils/AaveV3TestBase.sol";

contract AaveV3SetMetadataFailureTests is AaveV3TestBase {

    function test_setMetadata_revert_functionPaused() external {
        globals.__setIsFunctionPaused(IMapleAaveV3Strategy.setMetadata.selector, true);

        vm.prank(governor);
        vm.expectRevert("MAV3S:PAUSED");
        strategy.setMetadata("abc");
    }

    function test_setMetadata_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(governor);
        vm.expectRevert("MAV3S:LOCKED");
        strategy.setMetadata("abc");
    }

    function test_setMetadata_revert_notAdmin() external {
        vm.expectRevert("MAV3S:NOT_ADMIN");
        strategy.setMetadata("abc");
    }

    function test_setMetadata_revert_noChange() external {
        vm.prank(governor);
        vm.expectRevert("MAV3S:SM:NO_CHANGE");
        strategy.setMetadata(INITIAL_STRATEGY_METADATA);
    }

}

contract AaveV3SetMetadataSuccessTests is AaveV3TestBase {

    function test_setMetadata_success_emptyString() external {
        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyMetadataSet("");

        vm.prank(governor);
        strategy.setMetadata("");

        assertEq(strategy.strategyMetadata(), "");
    }

    function test_setMetadata_success_governor() external {
        string memory metadata = "abc";

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyMetadataSet(metadata);

        vm.prank(governor);
        strategy.setMetadata(metadata);

        assertEq(strategy.strategyMetadata(), metadata);
    }

    function test_setMetadata_success_operationalAdmin() external {
        string memory metadata = "abc";

        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        vm.expectEmit();
        emit IMapleAaveV3Strategy.StrategyMetadataSet(metadata);

        vm.prank(operationalAdmin);
        strategy.setMetadata(metadata);

        assertEq(strategy.strategyMetadata(), metadata);

        assertAaveV3Strategy({
            aaveTokenBalance:        0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

}
