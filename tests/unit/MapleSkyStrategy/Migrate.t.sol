// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MapleSkyStrategy } from "../../../contracts/sky/MapleSkyStrategy.sol";

import { MockMigrator } from "../../utils/Mocks.sol";
import { SkyTestBase } from "../../utils/SkyTestBase.sol";

contract SkyMigrateTests is SkyTestBase {

    address migrator = address(new MockMigrator());

    bytes arguments = abi.encode(address(1337));

    function test_migrate_revert_functionPaused() external {
        globals.__setIsFunctionPaused(MapleSkyStrategy.migrate.selector, true);

        vm.expectRevert("MSS:PAUSED");
        strategy.migrate(migrator, arguments);
    }

    function test_migrate_revert_notFactory() external {
        vm.expectRevert("MSS:NOT_FACTORY");
        strategy.migrate(migrator, arguments);
    }

    function test_migrate_revert_failedMigration() external {
        vm.prank(address(factory));
        vm.expectRevert("MSS:M:FAILED");
        strategy.migrate(migrator, "");
    }

    function test_migrate_success() external {
        assertEq(strategy.strategyManager(), address(strategyManager));

        vm.prank(address(factory));
        strategy.migrate(migrator, arguments);

        assertEq(strategy.strategyManager(), address(1337));
    }

}
