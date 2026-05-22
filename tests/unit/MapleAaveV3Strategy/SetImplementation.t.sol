// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MapleAaveV3Strategy } from "../../../contracts/aaveV3/MapleAaveV3Strategy.sol";

import { AaveV3TestBase } from "../../utils/AaveV3TestBase.sol";

contract AaveV3SetImplementationTests is AaveV3TestBase {

    address internal newImplementation;

    function setUp() public override {
        super.setUp();

        newImplementation = address(new MapleAaveV3Strategy());
    }

    function test_setImplementation_revert_notFactory() external {
        vm.expectRevert("MAV3S:NOT_FACTORY");
        strategy.setImplementation(newImplementation);
    }

    function test_setImplementation_revert_protocolPaused() external {
        globals.__setIsFunctionPaused(MapleAaveV3Strategy.setImplementation.selector, true);

        vm.expectRevert("MAV3S:PAUSED");
        strategy.setImplementation(newImplementation);
    }

    function test_setImplementation_success() external {
        assertEq(strategy.implementation(), implementation);

        vm.prank(address(factory));
        strategy.setImplementation(newImplementation);

        assertEq(strategy.implementation(), newImplementation);
    }

}
