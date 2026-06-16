// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleAaveV3StrategyInitializer } from "../../../contracts/interfaces/IMapleAaveV3StrategyInitializer.sol";

import { MapleAaveV3StrategyHarness } from "../../utils/Harnesses.sol";
import { AaveV3TestBase }             from "../../utils/AaveV3TestBase.sol";

contract AaveV3CreateInstanceTests is AaveV3TestBase {

    function setUp() public override {
        super.setUp();

        strategyManager.__setUnderlyingStrategy(factory.getInstanceAddress(initializationArguments(), ""));
    }

    function test_createInstance_revert_invalidDeployer() external {
        globals.__setCanDeploy(deployer, false);

        vm.prank(deployer);
        vm.expectRevert("MAV3SF:CI:CANNOT_DEPLOY");
        factory.createInstance(initializationArguments(), "");
    }

    function test_createInstance_revert_protocolPaused() external {
        globals.__setProtocolPaused(true);

        vm.prank(deployer);
        vm.expectRevert("MPF:PROTOCOL_PAUSED");
        factory.createInstance(initializationArguments(), "");
    }

    function test_createInstance_revert_malformedPayload() external {
        vm.prank(deployer);
        vm.expectRevert("MPF:CI:FAILED");
        factory.createInstance(new bytes(0), "");

        bytes memory validArguments     = initializationArguments();
        bytes memory truncatedArguments = new bytes(validArguments.length - 1);

        vm.prank(deployer);
        vm.expectRevert("MPF:CI:FAILED");
        factory.createInstance(truncatedArguments, "");
    }

    function test_createInstance_success() external {
        vm.expectEmit();
        emit IMapleAaveV3StrategyInitializer.Initialized(address(strategyManager), params);

        vm.prank(deployer);
        strategy = MapleAaveV3StrategyHarness(factory.createInstance(initializationArguments(), ""));

        assertTrue(factory.isInstance(address(strategy)));

        assertEq(strategy.strategyManager(), address(strategyManager));
        assertEq(strategy.fundsAsset(),      address(asset));
        assertEq(strategy.aavePool(),        aavePool);
        assertEq(strategy.aaveToken(),       address(aaveToken));
        assertEq(strategy.locked(),          1);

        assertEq(strategy.strategyDelegateFeeRate(), 0.02e6);
        assertEq(strategy.strategyProtocolFeeRate(), 0.03e6);
        assertEq(strategy.referralCode(),            123);
    }

}
