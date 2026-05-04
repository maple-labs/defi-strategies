// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { Test } from "../../modules/forge-std/src/Test.sol";

import { IMapleSkyStrategyInitializer } from "../../contracts/interfaces/IMapleSkyStrategyInitializer.sol";

import { MapleSkyStrategyFactory } from "../../contracts/MapleSkyStrategyFactory.sol";

import {
    MapleSkyStrategyHarness,
    MapleSkyStrategyInitializerHarness
} from "./Harnesses.sol";

import {
    MockAsset,
    MockFactory,
    MockGlobals,
    MockManager
} from "./Mocks.sol";

contract TestBase is Test {

    address deployer      = makeAddr("deployer");
    address governor      = makeAddr("governor");
    address securityAdmin = makeAddr("securityAdmin");

    address implementation = address(new MapleSkyStrategyHarness());
    address initializer    = address(new MapleSkyStrategyInitializerHarness());

    uint32 startingTime;

    IMapleSkyStrategyInitializer.Parameters params;

    MockAsset   asset   = new MockAsset();
    MockGlobals globals = new MockGlobals();
    MockManager manager = new MockManager();

    MapleSkyStrategyFactory factory;
    MapleSkyStrategyHarness strategy;

    function setUp() public virtual {
        startingTime = uint32(block.timestamp);

        globals.__setCanDeploy(deployer, true);
        globals.__setGovernor(governor);
        globals.__setSecurityAdmin(securityAdmin);

        factory = new MapleSkyStrategyFactory(address(globals));

        vm.startPrank(governor);
        factory.registerImplementation(100, implementation, initializer);
        factory.setDefaultVersion(100);
        vm.stopPrank();

        params = IMapleSkyStrategyInitializer.Parameters({
            manager: address(manager)
        });

        vm.prank(deployer);
        strategy = MapleSkyStrategyHarness(factory.createInstance(abi.encode(params), "DEFAULT"));
    }

}
