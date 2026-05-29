// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { Test } from "../../modules/forge-std/src/Test.sol";

import { IMapleAaveV3StrategyInitializer } from "../../contracts/interfaces/IMapleAaveV3StrategyInitializer.sol";

import { MapleAaveV3StrategyFactory } from "../../contracts/aaveV3/MapleAaveV3StrategyFactory.sol";

import { MapleAaveV3StrategyHarness, MapleAaveV3StrategyInitializerHarness } from "./Harnesses.sol";

import {
    MockAavePool,
    MockAaveToken,
    MockAsset,
    MockFactory,
    MockGlobals,
    MockManager
} from "./Mocks.sol";

contract AaveV3TestBase is Test {

    address aavePool         = address(new MockAavePool());
    address deployer         = makeAddr("deployer");
    address governor         = makeAddr("governor");
    address mapleTreasury    = makeAddr("mapleTreasury");
    address securityAdmin    = makeAddr("securityAdmin");
    address strategyDelegate = makeAddr("strategyDelegate");

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

        MockAavePool(aavePool).__setAaveToken(address(aaveToken));

        globals.__setCanDeploy(deployer, true);
        globals.__setGovernor(governor);
        globals.__setIsInstanceOf("STRATEGY_MANAGER_FACTORY", address(managerFactory), true);
        globals.__setIsInstanceOf("STRATEGY_VAULT", address(aaveToken), true);
        globals.__setIsPoolAsset(address(asset), true);
        globals.__setMapleTreasury(mapleTreasury);
        globals.__setSecurityAdmin(securityAdmin);
        globals.__setStrategyDelegateOf(address(strategyManager), strategyDelegate);

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

    function assertAaveV3Strategy(
        uint256 aaveTokenBalance,
        uint256 lastRecordedTotalAssets,
        uint256 assetsUnderManagement
    )
        internal view
    {
        assertEq(aaveToken.balanceOf(address(strategy)), aaveTokenBalance);
        assertEq(strategy.lastRecordedTotalAssets(),     lastRecordedTotalAssets);
        assertEq(strategy.assetsUnderManagement(),       assetsUnderManagement);
    }

    function assertCollectedFees(uint256 delegateFee, uint256 protocolFee) internal view {
        assertEq(asset.balanceOf(strategyDelegate), delegateFee);
        assertEq(asset.balanceOf(mapleTreasury),    protocolFee);
    }

    function setAaveAmountOut(uint256 amountOut_) internal {
        MockAavePool(aavePool).__setAmountOut(address(asset), address(strategy), amountOut_);
    }

    function setAaveV3StrategyState(uint256 lastRecordedTotalAssets_, uint256 aaveTokenBalance_) internal {
        strategy.__setLastRecordedTotalAssets(lastRecordedTotalAssets_);
        setAaveAmountOut(aaveTokenBalance_);
    }

}
