// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { Test } from "../../modules/forge-std/src/Test.sol";

import { IMapleAaveV3StrategyInitializer } from "../../contracts/interfaces/IMapleAaveV3StrategyInitializer.sol";

import { MapleAaveV3StrategyFactory } from "../../contracts/aaveV3/MapleAaveV3StrategyFactory.sol";

import { MapleAaveV3StrategyHarness, MapleAaveV3StrategyInitializerHarness } from "./Harnesses.sol";

import {
    MockAsset,
    MockGlobals,
    MockManager
} from "./Mocks.sol";

contract AaveV3TestBase is Test {

    address aavePool      = makeAddr("aavePool");
    address aaveToken     = makeAddr("aaveToken");
    address deployer      = makeAddr("deployer");
    address governor      = makeAddr("governor");
    address mapleTreasury = makeAddr("mapleTreasury");
    address securityAdmin = makeAddr("securityAdmin");

    address implementation = address(new MapleAaveV3StrategyHarness());
    address initializer    = address(new MapleAaveV3StrategyInitializerHarness());

    IMapleAaveV3StrategyInitializer.Parameters params;

    MockAsset   asset           = new MockAsset();
    MockGlobals globals         = new MockGlobals();
    MockManager strategyManager = new MockManager();

    MapleAaveV3StrategyFactory factory;
    MapleAaveV3StrategyHarness strategy;

    function setUp() public virtual {
        globals.__setCanDeploy(deployer, true);
        globals.__setGovernor(governor);
        globals.__setMapleTreasury(mapleTreasury);
        globals.__setSecurityAdmin(securityAdmin);

        factory = new MapleAaveV3StrategyFactory(address(globals));

        vm.startPrank(governor);
        factory.registerImplementation(100, implementation, initializer);
        factory.setDefaultVersion(100);
        vm.stopPrank();

        params = IMapleAaveV3StrategyInitializer.Parameters({
            strategyManager: address(strategyManager),
            fundsAsset:      address(asset),
            aavePool:        aavePool,
            aaveToken:       aaveToken
        });

        vm.prank(deployer);
        strategy = MapleAaveV3StrategyHarness(factory.createInstance(abi.encode(params), "DEFAULT"));
    }

}
