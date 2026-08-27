// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleSkyStrategy } from "../../../contracts/interfaces/IMapleSkyStrategy.sol";

import { SkyTestBase } from "../../utils/SkyTestBase.sol";

contract SkySetMetadataFailureTests is SkyTestBase {

    function test_setMetadata_revert_functionPaused() external {
        globals.__setIsFunctionPaused(IMapleSkyStrategy.setMetadata.selector, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:PAUSED");
        strategy.setMetadata("abc");
    }

    function test_setMetadata_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:LOCKED");
        strategy.setMetadata("abc");
    }

    function test_setMetadata_revert_notAuthorized() external {
        vm.prank(governor);
        vm.expectRevert("MSS:NOT_AUTHORIZED");
        strategy.setMetadata("abc");
    }

    function test_setMetadata_revert_lossRecognized() external {
        strategy.__setIsLossRecognized(true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:LOSS_RECOGNIZED");
        strategy.setMetadata("abc");
    }

    function test_setMetadata_revert_noChange() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:SM:NO_CHANGE");
        strategy.setMetadata(INITIAL_STRATEGY_METADATA);
    }

}

contract SkySetMetadataSuccessTests is SkyTestBase {

    function test_setMetadata_success_emptyString() external {
        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyMetadataSet("");

        vm.prank(strategyDelegate);
        strategy.setMetadata("");

        assertEq(strategy.strategyMetadata(), "");
    }

    function test_setMetadata_success_strategyDelegate() external {
        string memory metadata = "abc";

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyMetadataSet(metadata);

        vm.prank(strategyDelegate);
        strategy.setMetadata(metadata);

        assertEq(strategy.strategyMetadata(), metadata);
    }

    function test_setMetadata_success_operationalAdmin() external {
        string memory metadata = "abc";

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });

        vm.expectEmit();
        emit IMapleSkyStrategy.StrategyMetadataSet(metadata);

        vm.prank(operationalAdmin);
        strategy.setMetadata(metadata);

        assertEq(strategy.strategyMetadata(), metadata);

        assertSkyStrategy({
            susdsBalance:            0,
            lastRecordedTotalAssets: 0,
            assetsUnderManagement:   0
        });
    }

}
