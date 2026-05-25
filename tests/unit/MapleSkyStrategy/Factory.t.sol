// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { SkyTestBase } from "../../utils/SkyTestBase.sol";

contract SkyFactoryTests is SkyTestBase {

    function test_factory_success() external view {
        assertEq(strategy.factory(), address(factory));
    }

}
