// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { MapleProxiedInternals } from "../../modules/proxy-factory/contracts/MapleProxiedInternals.sol";

import { IMapleAaveV3Strategy } from "../interfaces/IMapleAaveV3Strategy.sol";

import {
    IGlobalsLike,
    IProxyFactoryLike
} from "../interfaces/Interfaces.sol";

import { MapleAaveV3StrategyStorage } from "./MapleAaveV3StrategyStorage.sol";

contract MapleAaveV3Strategy is IMapleAaveV3Strategy, MapleAaveV3StrategyStorage, MapleProxiedInternals {

    /**************************************************************************************************************************************/
    /*** Modifiers                                                                                                                      ***/
    /**************************************************************************************************************************************/

    modifier onlyFactory() {
        require(msg.sender == _factory(), "MAV3S:NOT_FACTORY");

        _;
    }

    modifier whenNotPaused() {
        require(!IGlobalsLike(globals()).isFunctionPaused(msg.sig), "MAV3S:PAUSED");

        _;
    }

    /**************************************************************************************************************************************/
    /*** Proxy Functions                                                                                                                ***/
    /**************************************************************************************************************************************/

    function migrate(address migrator_, bytes calldata arguments_) external override whenNotPaused onlyFactory {
        require(_migrate(migrator_, arguments_), "MAV3S:M:FAILED");
    }

    function setImplementation(address implementation_) external override whenNotPaused onlyFactory {
        _setImplementation(implementation_);
    }

    function upgrade(uint256 version_, bytes calldata arguments_) external override whenNotPaused {
        require(msg.sender == securityAdmin(), "MAV3S:U:NOT_AUTHORIZED");

        IProxyFactoryLike(_factory()).upgradeInstance(version_, arguments_);

        emit Upgraded(version_, arguments_);
    }

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    function factory() external view override returns (address factory_) {
        factory_ = _factory();
    }

    function globals() public view override returns (address globals_) {
        globals_ = IProxyFactoryLike(_factory()).mapleGlobals();
    }

    function implementation() external view override returns (address implementation_) {
        implementation_ = _implementation();
    }

    function mapleTreasury() public view override returns (address mapleTreasury_) {
        mapleTreasury_ = IGlobalsLike(globals()).mapleTreasury();
    }

    function securityAdmin() public view override returns (address securityAdmin_) {
        securityAdmin_ = IGlobalsLike(globals()).securityAdmin();
    }

}
