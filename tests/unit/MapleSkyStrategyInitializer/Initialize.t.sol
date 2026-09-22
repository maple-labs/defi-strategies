// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleSkyStrategyInitializer } from "../../../contracts/interfaces/IMapleSkyStrategyInitializer.sol";

import { MapleSkyStrategyInitializerHarness } from "../../utils/Harnesses.sol";
import { SkyTestBase } from "../../utils/SkyTestBase.sol";

contract SkyInitializeTests is SkyTestBase {

    MapleSkyStrategyInitializerHarness proxy = MapleSkyStrategyInitializerHarness(initializer);

    function setUp() public override {
        super.setUp();

        strategyManager.__setUnderlyingStrategy(address(proxy));
    }

    function test_initialize_revert_zeroStrategyManager() external {
        vm.prank(address(factory));
        vm.expectRevert("MSSI:I:ZERO_STRATEGY_MANAGER");
        proxy.__initialize(address(0), params);
    }

    function test_initialize_revert_zeroSavingsUsds() external {
        params.savingsUsds = address(0);

        vm.prank(address(factory));
        vm.expectRevert("MSSI:I:ZERO_SAVINGS_USDS");
        proxy.__initialize(address(strategyManager), params);
    }

    function test_initialize_revert_zeroPsm() external {
        params.psm = address(0);

        vm.prank(address(factory));
        vm.expectRevert("MSSI:I:ZERO_PSM");
        proxy.__initialize(address(strategyManager), params);
    }

    function test_initialize_revert_invalidSumFeeRate() external {
        params.strategyDelegateFeeRate = 0.5e6;
        params.strategyProtocolFeeRate = 0.5e6 + 1;

        vm.prank(address(factory));
        vm.expectRevert("MSSI:I:INVALID_SUM_FEE_RATE");
        proxy.__initialize(address(strategyManager), params);
    }

    function test_initialize_revert_invalidAsset() external {
        globals.__setIsPoolAsset(params.fundsAsset, false);

        vm.prank(address(factory));
        vm.expectRevert("MSSI:I:INVALID_ASSET");
        proxy.__initialize(address(strategyManager), params);
    }

    function test_initialize_revert_invalidFactory() external {
        globals.__setIsInstanceOf("STRATEGY_MANAGER_FACTORY", address(managerFactory), false);

        vm.prank(address(factory));
        vm.expectRevert("MSSI:I:INVALID_FACTORY");
        proxy.__initialize(address(strategyManager), params);
    }

    function test_initialize_revert_invalidInstance() external {
        managerFactory.__setIsInstance(address(strategyManager), false);

        vm.prank(address(factory));
        vm.expectRevert("MSSI:I:INVALID_INSTANCE");
        proxy.__initialize(address(strategyManager), params);
    }

    function test_initialize_revert_invalidUnderlyingStrategy() external {
        strategyManager.__setUnderlyingStrategy(makeAddr("invalidStrategy"));

        vm.prank(address(factory));
        vm.expectRevert("MSSI:I:INVALID_UNDERLYING");
        proxy.__initialize(address(strategyManager), params);
    }

    function test_initialize_revert_invalidStrategyVault() external {
        globals.__setIsInstanceOf("STRATEGY_VAULT", params.savingsUsds, false);

        vm.prank(address(factory));
        vm.expectRevert("MSSI:I:INVALID_STRATEGY_VAULT");
        proxy.__initialize(address(strategyManager), params);
    }

    function test_initialize_revert_invalidPsm() external {
        globals.__setIsInstanceOf("PSM", params.psm, false);

        vm.prank(address(factory));
        vm.expectRevert("MSSI:I:INVALID_PSM");
        proxy.__initialize(address(strategyManager), params);
    }

    function test_initialize_revert_invalidPsmGem() external {
        psm.__setGem(makeAddr("invalidGem"));

        vm.prank(address(factory));
        vm.expectRevert("MSSI:I:INVALID_GEM_PSM");
        proxy.__initialize(address(strategyManager), params);
    }

    function test_initialize_revert_invalidPsmUsds() external {
        psm.__setUsds(makeAddr("invalidUsds"));

        vm.prank(address(factory));
        vm.expectRevert("MSSI:I:INVALID_USDS_PSM");
        proxy.__initialize(address(strategyManager), params);
    }

    function test_initialize_revert_invalidPsmPocket() external {
        psm.__setPocket(address(0));

        vm.prank(address(factory));
        vm.expectRevert("MSSI:I:INVALID_POCKET_PSM");
        proxy.__initialize(address(strategyManager), params);
    }

    function test_initialize_success() external {
        vm.expectEmit();
        emit IMapleSkyStrategyInitializer.Initialized(address(strategyManager), params);

        vm.prank(address(factory));
        proxy.__initialize(address(strategyManager), params);

        assertEq(proxy.strategyManager(), address(strategyManager));
        assertEq(proxy.fundsAsset(),      address(asset));
        assertEq(proxy.psm(),             address(psm));
        assertEq(proxy.savingsUsds(),     address(savingsUsds));
        assertEq(proxy.usds(),            address(usds));
        assertEq(proxy.locked(),          1);

        assertEq(proxy.strategyDelegateFeeRate(), 0.02e6);
        assertEq(proxy.strategyProtocolFeeRate(), 0.03e6);
        assertEq(proxy.strategyMetadata(),        INITIAL_STRATEGY_METADATA);
        assertEq(proxy.referralCode(),            123);
    }

}
