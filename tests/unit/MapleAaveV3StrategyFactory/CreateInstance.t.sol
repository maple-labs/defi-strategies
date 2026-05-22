// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MapleAaveV3StrategyHarness } from "../../utils/Harnesses.sol";
import { AaveV3TestBase }             from "../../utils/AaveV3TestBase.sol";

contract AaveV3CreateInstanceTests is AaveV3TestBase {

    function test_createInstance_revert_invalidDeployer() external {
        globals.__setCanDeploy(deployer, false);

        vm.prank(deployer);
        vm.expectRevert("MAV3SF:CI:CANNOT_DEPLOY");
        factory.createInstance(abi.encode(params), "");
    }

    function test_createInstance_revert_malformedPayload() external {
        vm.prank(deployer);
        vm.expectRevert("MPF:CI:FAILED");
        factory.createInstance(new bytes(0), "");

        bytes memory validArguments     = abi.encode(params);
        bytes memory truncatedArguments = new bytes(validArguments.length - 1);

        vm.prank(deployer);
        vm.expectRevert("MPF:CI:FAILED");
        factory.createInstance(truncatedArguments, "");
    }

    function test_createInstance_revert_protocolPaused() external {
        globals.__setProtocolPaused(true);

        vm.prank(deployer);
        vm.expectRevert("MPF:PROTOCOL_PAUSED");
        factory.createInstance(abi.encode(params), "");
    }

    function test_createInstance_success() external {
        vm.prank(deployer);
        strategy = MapleAaveV3StrategyHarness(factory.createInstance(abi.encode(params), ""));

        assertTrue(factory.isInstance(address(strategy)));

        assertEq(strategy.factory(),        address(factory));
        assertEq(strategy.implementation(), implementation);
    }

}
