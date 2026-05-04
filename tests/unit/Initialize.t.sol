// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleSkyStrategyInitializer } from "../../contracts/interfaces/IMapleSkyStrategyInitializer.sol";

import { MapleSkyStrategyInitializerHarness } from "../utils/Harnesses.sol";
import { TestBase }                           from "../utils/TestBase.sol";

contract InitializeTests is TestBase {

    MapleSkyStrategyInitializerHarness proxy = MapleSkyStrategyInitializerHarness(initializer);

    function test_initialize_success() external {
        vm.expectEmit();
        emit IMapleSkyStrategyInitializer.Initialized(params);

        vm.prank(address(factory));
        proxy.__initialize(params);

        assertEq(proxy.manager(), address(manager));
    }

}
