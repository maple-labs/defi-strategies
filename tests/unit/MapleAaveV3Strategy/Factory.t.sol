// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { AaveV3TestBase } from "../../utils/AaveV3TestBase.sol";

contract AaveV3FactoryTests is AaveV3TestBase {

    function test_factory_success() external view {
        assertEq(strategy.factory(), address(factory));
    }

}
