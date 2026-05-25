// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { Test } from "../../modules/forge-std/src/Test.sol";

import { IMapleAaveV3StrategyInitializer } from "../../contracts/interfaces/IMapleAaveV3StrategyInitializer.sol";

import { MapleAaveV3StrategyFactory } from "../../contracts/aaveV3/MapleAaveV3StrategyFactory.sol";

import { MapleAaveV3StrategyHarness, MapleAaveV3StrategyInitializerHarness } from "./Harnesses.sol";

import {
    MockAaveToken,
    MockAsset,
    MockFactory,
    MockGlobals,
    MockManager
} from "./Mocks.sol";

contract AaveV3TestBase is Test {

    address aavePool      = makeAddr("aavePool");
    address deployer      = makeAddr("deployer");
    address governor      = makeAddr("governor");
    address mapleTreasury = makeAddr("mapleTreasury");
    address securityAdmin = makeAddr("securityAdmin");

    address implementation = address(new MapleAaveV3StrategyHarness());
    address initializer    = address(new MapleAaveV3StrategyInitializerHarness());

    IMapleAaveV3StrategyInitializer.Parameters params;

    MockAsset     asset           = new MockAsset();
    MockAaveToken aaveToken       = new MockAaveToken();
    MockGlobals   globals         = new MockGlobals();
    MockManager   strategyManager = new MockManager();
    MockFactory   managerFactory  = new MockFactory();

    MapleAaveV3StrategyFactory factory;
    MapleAaveV3StrategyHarness strategy;

    function setUp() public virtual {
        aaveToken.__setPool(aavePool);
        aaveToken.__setUnderlyingAsset(address(asset));

        globals.__setCanDeploy(deployer, true);
        globals.__setGovernor(governor);
        globals.__setIsInstanceOf("STRATEGY_MANAGER_FACTORY", address(managerFactory), true);
        globals.__setIsInstanceOf("STRATEGY_VAULT", address(aaveToken), true);
        globals.__setIsPoolAsset(address(asset), true);
        globals.__setMapleTreasury(mapleTreasury);
        globals.__setSecurityAdmin(securityAdmin);

        strategyManager.__setFactory(address(managerFactory));
        managerFactory.__setIsInstance(address(strategyManager), true);

        factory = new MapleAaveV3StrategyFactory(address(globals));

        vm.startPrank(governor);
        factory.registerImplementation(100, implementation, initializer);
        factory.setDefaultVersion(100);
        vm.stopPrank();

        params = IMapleAaveV3StrategyInitializer.Parameters({
            strategyManager:         address(strategyManager),
            aaveToken:               address(aaveToken),
            strategyDelegateFeeRate: 0.02e6,
            strategyProtocolFeeRate: 0.03e6,
            referralCode:            123
        });

        bytes memory arguments = abi.encode(params);

        strategyManager.__setUnderlyingStrategy(factory.getInstanceAddress(arguments, "DEFAULT"));

        vm.prank(deployer);
        strategy = MapleAaveV3StrategyHarness(factory.createInstance(arguments, "DEFAULT"));
    }

}
