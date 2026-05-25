// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { SkyTestBase } from "../../utils/SkyTestBase.sol";

contract SkyGlobalsTests is SkyTestBase {

    function test_globals_success() external view {
        assertEq(strategy.globals(), address(globals));
    }

}
