// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MapleAaveV3Strategy } from "../../../contracts/aaveV3/MapleAaveV3Strategy.sol";

import { IAaveRewardsControllerLike } from "../../../contracts/interfaces/Interfaces.sol";
import { IMapleAaveV3Strategy }       from "../../../contracts/interfaces/IMapleAaveV3Strategy.sol";

import { AaveV3TestBase } from "../../utils/AaveV3TestBase.sol";
import { MockAsset }      from "../../utils/Mocks.sol";

contract AaveV3ClaimRewardsFailureTests is AaveV3TestBase {

    address rewardToken = makeAddr("rewardToken");

    uint256 rewardAmount = 1e18;

    address[] assets;

    function setUp() public override {
        super.setUp();

        assets.push(address(aaveToken));

        rewardsController.__setRewardAmount(rewardAmount);
    }

    function test_claimRewards_revert_paused() external {
        globals.__setIsFunctionPaused(MapleAaveV3Strategy.claimRewards.selector, true);

        vm.prank(governor);
        vm.expectRevert("MAV3S:PAUSED");
        strategy.claimRewards(assets, rewardAmount, rewardToken);
    }

    function test_claimRewards_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(governor);
        vm.expectRevert("MAV3S:LOCKED");
        strategy.claimRewards(assets, rewardAmount, rewardToken);
    }

    function test_claimRewards_revert_notAdmin() external {
        vm.expectRevert("MAV3S:NOT_ADMIN");
        strategy.claimRewards(assets, rewardAmount, rewardToken);
    }

}

contract AaveV3ClaimRewardsSuccessTests is AaveV3TestBase {

    MockAsset rewardToken = new MockAsset();

    uint256 rewardAmount = 1e18;

    address[] assets;

    function setUp() public override {
        super.setUp();

        assets.push(address(aaveToken));

        rewardsController.__setRewardAmount(rewardAmount);

        setAaveV3StrategyState({
            lastRecordedTotalAssets_: 100e6,
            aaveTokenBalance_:        100e6
        });
    }

    function test_claimRewards_success_governor() external {
        assertAaveV3Strategy({
            aaveTokenBalance:        100e6,
            lastRecordedTotalAssets: 100e6,
            assetsUnderManagement:   100e6
        });

        assertEq(rewardToken.balanceOf(mapleTreasury),      0);
        assertEq(rewardToken.balanceOf(address(strategy)),  0);
        assertEq(rewardToken.balanceOf(governor),           0);

        vm.expectCall(
            address(rewardsController),
            abi.encodeCall(IAaveRewardsControllerLike.claimRewards, (assets, rewardAmount, mapleTreasury, address(rewardToken)))
        );

        vm.expectEmit();
        emit IMapleAaveV3Strategy.RewardsClaimed(address(rewardToken), rewardAmount);

        vm.prank(governor);
        strategy.claimRewards(assets, rewardAmount, address(rewardToken));

        assertAaveV3Strategy({
            aaveTokenBalance:        100e6,
            lastRecordedTotalAssets: 100e6,
            assetsUnderManagement:   100e6
        });

        assertEq(rewardToken.balanceOf(mapleTreasury),      rewardAmount);
        assertEq(rewardToken.balanceOf(address(strategy)),  0);
        assertEq(rewardToken.balanceOf(governor),           0);
    }

    function test_claimRewards_success_operationalAdmin() external {
        assertAaveV3Strategy({
            aaveTokenBalance:        100e6,
            lastRecordedTotalAssets: 100e6,
            assetsUnderManagement:   100e6
        });

        assertEq(rewardToken.balanceOf(mapleTreasury),      0);
        assertEq(rewardToken.balanceOf(address(strategy)),  0);
        assertEq(rewardToken.balanceOf(operationalAdmin),   0);

        vm.expectCall(
            address(rewardsController),
            abi.encodeCall(IAaveRewardsControllerLike.claimRewards, (assets, rewardAmount, mapleTreasury, address(rewardToken)))
        );

        vm.expectEmit();
        emit IMapleAaveV3Strategy.RewardsClaimed(address(rewardToken), rewardAmount);

        vm.prank(operationalAdmin);
        strategy.claimRewards(assets, rewardAmount, address(rewardToken));

        assertAaveV3Strategy({
            aaveTokenBalance:        100e6,
            lastRecordedTotalAssets: 100e6,
            assetsUnderManagement:   100e6
        });

        assertEq(rewardToken.balanceOf(mapleTreasury),      rewardAmount);
        assertEq(rewardToken.balanceOf(address(strategy)),  0);
        assertEq(rewardToken.balanceOf(operationalAdmin),   0);
    }

}
