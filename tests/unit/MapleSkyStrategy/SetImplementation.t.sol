// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MapleSkyStrategy } from "../../../contracts/MapleSkyStrategy.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract SetImplementationTests is TestBase {

    address internal newImplementation;

    function setUp() public override {
        super.setUp();

        newImplementation = address(new MapleSkyStrategy());
    }

    function test_setImplementation_protocolPaused() external {
        globals.__setIsFunctionPaused(MapleSkyStrategy.setImplementation.selector, true);

        vm.expectRevert("MTS:PAUSED");
        strategy.setImplementation(newImplementation);
    }

    function test_setImplementation_notFactory() external {
        vm.expectRevert("MTS:NOT_FACTORY");
        strategy.setImplementation(newImplementation);
    }

    function test_setImplementation_success() external {
        assertEq(strategy.implementation(), implementation);

        vm.prank(address(factory));
        strategy.setImplementation(newImplementation);

        assertEq(strategy.implementation(), newImplementation);
    }

}
