// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleProxied } from "../../../modules/proxy-factory/contracts/interfaces/IMapleProxied.sol";

import { MapleAaveV3Strategy } from "../../../contracts/aaveV3/MapleAaveV3Strategy.sol";

import { AaveV3TestBase }     from "../../utils/AaveV3TestBase.sol";
import { MockAaveV3Migrator } from "../../utils/Mocks.sol";

contract AaveV3UpgradeTests is AaveV3TestBase {

    address migrator          = address(new MockAaveV3Migrator());
    address newImplementation = address(new MapleAaveV3Strategy());

    bytes arguments = abi.encode(address(1337));

    function setUp() public override {
        super.setUp();

        vm.startPrank(governor);
        factory.registerImplementation(200, newImplementation, initializer);
        factory.enableUpgradePath(100, 200, migrator);
        vm.stopPrank();
    }

    function test_upgrade_revert_internalFailure() external {
        vm.prank(securityAdmin);
        vm.expectRevert("MPF:UI:FAILED");
        strategy.upgrade(200, "");
    }

    function test_upgrade_revert_notAuthorized() external {
        vm.expectRevert("MAV3S:U:NOT_AUTHORIZED");
        strategy.upgrade(200, arguments);
    }

    function test_upgrade_revert_protocolPaused() external {
        globals.__setIsFunctionPaused(MapleAaveV3Strategy.upgrade.selector, true);

        vm.expectRevert("MAV3S:PAUSED");
        strategy.upgrade(200, arguments);
    }

    function test_upgrade_success() external {
        assertEq(strategy.strategyManager(), address(strategyManager));

        vm.expectEmit();
        emit IMapleProxied.Upgraded(200, arguments);

        vm.prank(securityAdmin);
        strategy.upgrade(200, arguments);

        assertEq(strategy.strategyManager(), address(1337));
        assertEq(strategy.implementation(),  newImplementation);
    }

}
