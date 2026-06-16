// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleSkyStrategyInitializer } from "../../../contracts/interfaces/IMapleSkyStrategyInitializer.sol";

import { MapleSkyStrategyHarness } from "../../utils/Harnesses.sol";
import { SkyTestBase }             from "../../utils/SkyTestBase.sol";

contract SkyCreateInstanceTests is SkyTestBase {

    function setUp() public override {
        super.setUp();

        strategyManager.__setUnderlyingStrategy(factory.getInstanceAddress(initializationArguments(), ""));
    }

    function test_createInstance_revert_invalidDeployer() external {
        globals.__setCanDeploy(deployer, false);

        vm.prank(deployer);
        vm.expectRevert("MTSF:CI:CANNOT_DEPLOY");
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

        bytes memory validArguments      = initializationArguments();
        bytes memory truncatedArguments  = new bytes(validArguments.length - 1);

        vm.prank(deployer);
        vm.expectRevert("MPF:CI:FAILED");
        factory.createInstance(truncatedArguments, "");
    }

    function test_createInstance_success() external {
        vm.expectEmit();
        emit IMapleSkyStrategyInitializer.Initialized(address(strategyManager), params);

        vm.prank(deployer);
        strategy = MapleSkyStrategyHarness(factory.createInstance(initializationArguments(), ""));

        assertTrue(factory.isInstance(address(strategy)));

        assertEq(strategy.strategyManager(), address(strategyManager));
        assertEq(strategy.fundsAsset(),      address(asset));
        assertEq(strategy.psm(),             address(psm));
        assertEq(strategy.savingsUsds(),     address(savingsUsds));
        assertEq(strategy.usds(),            address(usds));
        assertEq(strategy.locked(),          1);

        assertEq(strategy.strategyDelegateFeeRate(), 0.02e6);
        assertEq(strategy.strategyProtocolFeeRate(), 0.03e6);
        assertEq(strategy.referralCode(),            123);
    }

}
