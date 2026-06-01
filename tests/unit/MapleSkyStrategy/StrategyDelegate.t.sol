// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { SkyTestBase } from "../../utils/SkyTestBase.sol";

contract SkyStrategyDelegateTests is SkyTestBase {

    function test_strategyDelegate_success() external view {
        assertEq(strategy.strategyDelegate(), strategyDelegate);
    }

}
