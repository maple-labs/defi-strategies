// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { Test } from "../../modules/forge-std/src/Test.sol";

import { IMapleSkyStrategyInitializer } from "../../contracts/interfaces/IMapleSkyStrategyInitializer.sol";

import { MapleSkyStrategyFactory } from "../../contracts/sky/MapleSkyStrategyFactory.sol";

import { MapleSkyStrategyHarness, MapleSkyStrategyInitializerHarness } from "./Harnesses.sol";

import {
    MockAsset,
    MockFactory,
    MockGlobals,
    MockManager,
    MockPsm,
    MockSavingsUsds
} from "./Mocks.sol";

contract SkyTestBase is Test {

    address deployer         = makeAddr("deployer");
    address governor         = makeAddr("governor");
    address mapleTreasury    = makeAddr("mapleTreasury");
    address operationalAdmin = makeAddr("operationalAdmin");
    address securityAdmin    = makeAddr("securityAdmin");
    address strategyDelegate = makeAddr("strategyDelegate");

    address implementation = address(new MapleSkyStrategyHarness());
    address initializer    = address(new MapleSkyStrategyInitializerHarness());

    IMapleSkyStrategyInitializer.Parameters params;

    MockAsset       asset           = new MockAsset();
    MockAsset       usds            = new MockAsset();
    MockFactory     managerFactory  = new MockFactory();
    MockGlobals     globals         = new MockGlobals();
    MockManager     strategyManager = new MockManager();
    MockPsm         psm             = new MockPsm();
    MockSavingsUsds savingsUsds     = new MockSavingsUsds();

    MapleSkyStrategyFactory factory;
    MapleSkyStrategyHarness strategy;

    function setUp() public virtual {
        psm.__setGem(address(asset));
        psm.__setTo18ConversionFactor(1e12);
        psm.__setUsds(address(usds));

        savingsUsds.__setAsset(address(usds));

        globals.__setCanDeploy(deployer, true);
        globals.__setGovernor(governor);
        globals.__setIsInstanceOf("PSM", address(psm), true);
        globals.__setIsInstanceOf("STRATEGY_MANAGER_FACTORY", address(managerFactory), true);
        globals.__setIsInstanceOf("STRATEGY_VAULT", address(savingsUsds), true);
        globals.__setIsPoolAsset(address(asset), true);
        globals.__setMapleTreasury(mapleTreasury);
        globals.__setOperationalAdmin(operationalAdmin);
        globals.__setSecurityAdmin(securityAdmin);

        strategyManager.__setFactory(address(managerFactory));
        strategyManager.__setStrategyDelegate(strategyDelegate);
        managerFactory.__setIsInstance(address(strategyManager), true);

        factory = new MapleSkyStrategyFactory(address(globals));

        vm.startPrank(governor);
        factory.registerImplementation(100, implementation, initializer);
        factory.setDefaultVersion(100);
        vm.stopPrank();

        params = IMapleSkyStrategyInitializer.Parameters({
            strategyManager:         address(strategyManager),
            fundsAsset:              address(asset),
            psm:                     address(psm),
            savingsUsds:             address(savingsUsds),
            strategyDelegateFeeRate: 0.02e6,
            strategyProtocolFeeRate: 0.03e6,
            referralCode:            123
        });

        bytes memory arguments = abi.encode(params);

        strategyManager.__setUnderlyingStrategy(factory.getInstanceAddress(arguments, "DEFAULT"));

        vm.prank(deployer);
        strategy = MapleSkyStrategyHarness(factory.createInstance(arguments, "DEFAULT"));
    }

    function assertSkyStrategy(uint256 susdsBalance, uint256 lastRecordedTotalAssets, uint256 assetsUnderManagement) internal view {
        assertEq(savingsUsds.balanceOf(address(strategy)), susdsBalance);
        assertEq(strategy.lastRecordedTotalAssets(),       lastRecordedTotalAssets);
        assertEq(strategy.assetsUnderManagement(),         assetsUnderManagement);
    }

    function assertCollectedFees(uint256 delegateFee, uint256 protocolFee) internal view {
        assertEq(asset.balanceOf(strategyDelegate), delegateFee);
        assertEq(asset.balanceOf(mapleTreasury),    protocolFee);
    }

    function setSkyStrategyState(uint256 lastRecordedTotalAssets_, uint256 susdsBalance_) internal {
        strategy.__setLastRecordedTotalAssets(lastRecordedTotalAssets_);
        savingsUsds.__setBalanceOf(address(strategy), susdsBalance_);
        usds.mint(address(savingsUsds), susdsBalance_ * savingsUsds.susdsRedeemExchangeRate() / 1e18);
    }

}
