// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MapleAaveV3Strategy } from "../../../contracts/aaveV3/MapleAaveV3Strategy.sol";

import { AaveV3TestBase }     from "../../utils/AaveV3TestBase.sol";
import { MockAaveV3Migrator } from "../../utils/Mocks.sol";

contract AaveV3MigrateTests is AaveV3TestBase {

    address migrator = address(new MockAaveV3Migrator());

    bytes arguments = abi.encode(address(1337));

    function test_migrate_revert_failedMigration() external {
        vm.prank(address(factory));
        vm.expectRevert("MAV3S:M:FAILED");
        strategy.migrate(migrator, "");
    }

    function test_migrate_revert_notFactory() external {
        vm.expectRevert("MAV3S:NOT_FACTORY");
        strategy.migrate(migrator, arguments);
    }

    function test_migrate_revert_functionPaused() external {
        globals.__setIsFunctionPaused(MapleAaveV3Strategy.migrate.selector, true);

        vm.expectRevert("MAV3S:PAUSED");
        strategy.migrate(migrator, arguments);
    }

    function test_migrate_success() external {
        assertEq(strategy.strategyManager(), address(strategyManager));

        vm.prank(address(factory));
        strategy.migrate(migrator, arguments);

        assertEq(strategy.strategyManager(), address(1337));
    }

}
