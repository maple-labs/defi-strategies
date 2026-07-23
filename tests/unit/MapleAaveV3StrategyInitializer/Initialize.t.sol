// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleAaveV3StrategyInitializer } from "../../../contracts/interfaces/IMapleAaveV3StrategyInitializer.sol";

import { MapleAaveV3StrategyInitializerHarness } from "../../utils/Harnesses.sol";
import { AaveV3TestBase }                        from "../../utils/AaveV3TestBase.sol";

contract AaveV3InitializeTests is AaveV3TestBase {

    MapleAaveV3StrategyInitializerHarness proxy = MapleAaveV3StrategyInitializerHarness(initializer);

    function setUp() public override {
        super.setUp();

        strategyManager.__setUnderlyingStrategy(address(proxy));
    }

    function test_initialize_revert_zeroStrategyManager() external {
        vm.prank(address(factory));
        vm.expectRevert("MAV3SI:I:ZERO_STRATEGY_MANAGER");
        proxy.__initialize(address(0), params);
    }

    function test_initialize_revert_zeroAaveToken() external {
        params.aaveToken = address(0);

        vm.prank(address(factory));
        vm.expectRevert("MAV3SI:I:ZERO_AAVE_TOKEN");
        proxy.__initialize(address(strategyManager), params);
    }

    function test_initialize_revert_invalidSumFeeRate() external {
        params.strategyDelegateFeeRate = 0.5e6;
        params.strategyProtocolFeeRate = 0.5e6 + 1;

        vm.prank(address(factory));
        vm.expectRevert("MAV3SI:I:INVALID_SUM_FEE_RATE");
        proxy.__initialize(address(strategyManager), params);
    }

    function test_initialize_revert_invalidFactory() external {
        globals.__setIsInstanceOf("STRATEGY_MANAGER_FACTORY", address(managerFactory), false);

        vm.prank(address(factory));
        vm.expectRevert("MAV3SI:I:INVALID_FACTORY");
        proxy.__initialize(address(strategyManager), params);
    }

    function test_initialize_revert_invalidInstance() external {
        managerFactory.__setIsInstance(address(strategyManager), false);

        vm.prank(address(factory));
        vm.expectRevert("MAV3SI:I:INVALID_INSTANCE");
        proxy.__initialize(address(strategyManager), params);
    }

    function test_initialize_revert_invalidUnderlyingStrategy() external {
        strategyManager.__setUnderlyingStrategy(makeAddr("invalidStrategy"));

        vm.prank(address(factory));
        vm.expectRevert("MAV3SI:I:INVALID_UNDERLYING");
        proxy.__initialize(address(strategyManager), params);
    }

    function test_initialize_revert_invalidStrategyVault() external {
        globals.__setIsInstanceOf("STRATEGY_VAULT", params.aaveToken, false);

        vm.prank(address(factory));
        vm.expectRevert("MAV3SI:I:INVALID_STRATEGY_VAULT");
        proxy.__initialize(address(strategyManager), params);
    }

    function test_initialize_revert_invalidAsset() external {
        globals.__setIsPoolAsset(address(asset), false);

        vm.prank(address(factory));
        vm.expectRevert("MAV3SI:I:INVALID_ASSET");
        proxy.__initialize(address(strategyManager), params);
    }

    function test_initialize_success() external {
        vm.expectEmit();
        emit IMapleAaveV3StrategyInitializer.Initialized(address(strategyManager), params);

        vm.prank(address(factory));
        proxy.__initialize(address(strategyManager), params);

        assertEq(proxy.strategyManager(), address(strategyManager));
        assertEq(proxy.fundsAsset(),      address(asset));
        assertEq(proxy.aavePool(),        aavePool);
        assertEq(proxy.aaveToken(),       address(aaveToken));
        assertEq(proxy.locked(),          1);

        assertEq(proxy.strategyDelegateFeeRate(),     0.02e6);
        assertEq(proxy.strategyProtocolFeeRate(),     0.03e6);
        assertEq(proxy.strategyMetadata(),            INITIAL_STRATEGY_METADATA);
        assertEq(proxy.referralCode(),                123);
        assertEq(proxy.useVirtualUnderlyingBalance(), true);
    }

    function test_initialize_success_useRawLiquidity() external {
        params.useVirtualUnderlyingBalance = false;

        vm.expectEmit();
        emit IMapleAaveV3StrategyInitializer.Initialized(address(strategyManager), params);

        vm.prank(address(factory));
        proxy.__initialize(address(strategyManager), params);

        assertEq(proxy.strategyManager(), address(strategyManager));
        assertEq(proxy.fundsAsset(),      address(asset));
        assertEq(proxy.aavePool(),        aavePool);
        assertEq(proxy.aaveToken(),       address(aaveToken));
        assertEq(proxy.locked(),          1);

        assertEq(proxy.strategyDelegateFeeRate(),     0.02e6);
        assertEq(proxy.strategyProtocolFeeRate(),     0.03e6);
        assertEq(proxy.strategyMetadata(),            INITIAL_STRATEGY_METADATA);
        assertEq(proxy.referralCode(),                123);
        assertEq(proxy.useVirtualUnderlyingBalance(), false);
    }

}
