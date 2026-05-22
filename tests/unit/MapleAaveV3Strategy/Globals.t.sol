// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { AaveV3TestBase } from "../../utils/AaveV3TestBase.sol";

contract AaveV3GlobalsTests is AaveV3TestBase {

    function test_globals_success() external view {
        assertEq(strategy.globals(), address(globals));
    }

}
