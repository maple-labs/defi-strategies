// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { SkyTestBase } from "../../utils/SkyTestBase.sol";

contract SecurityAdminTests is SkyTestBase {

    function test_securityAdmin_success() external view {
        assertEq(strategy.securityAdmin(), address(securityAdmin));
    }

}
