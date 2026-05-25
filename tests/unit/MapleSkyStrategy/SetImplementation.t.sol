// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MapleSkyStrategy } from "../../../contracts/sky/MapleSkyStrategy.sol";

import { SkyTestBase } from "../../utils/SkyTestBase.sol";

contract SkySetImplementationTests is SkyTestBase {

    address internal newImplementation;

    function setUp() public override {
        super.setUp();

        newImplementation = address(new MapleSkyStrategy());
    }

    function test_setImplementation_revert_protocolPaused() external {
        globals.__setIsFunctionPaused(MapleSkyStrategy.setImplementation.selector, true);

        vm.expectRevert("MSS:PAUSED");
        strategy.setImplementation(newImplementation);
    }

    function test_setImplementation_revert_notFactory() external {
        vm.expectRevert("MSS:NOT_FACTORY");
        strategy.setImplementation(newImplementation);
    }

    function test_setImplementation_success() external {
        assertEq(strategy.implementation(), implementation);

        vm.prank(address(factory));
        strategy.setImplementation(newImplementation);

        assertEq(strategy.implementation(), newImplementation);
    }

}
