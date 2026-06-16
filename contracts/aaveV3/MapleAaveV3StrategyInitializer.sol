// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { IMapleAaveV3StrategyInitializer } from "../interfaces/IMapleAaveV3StrategyInitializer.sol";
import {
    IAaveTokenLike,
    IGlobalsLike,
    IProxyFactoryLike,
    IStrategyManagerLike
} from "../interfaces/Interfaces.sol";

import { MapleAaveV3StrategyStorage } from "./MapleAaveV3StrategyStorage.sol";

contract MapleAaveV3StrategyInitializer is IMapleAaveV3StrategyInitializer, MapleAaveV3StrategyStorage {

    function _initialize(address strategyManager_, IMapleAaveV3StrategyInitializer.Parameters memory params_) internal {
        require(strategyManager_  != address(0), "MAV3SI:I:ZERO_STRATEGY_MANAGER");
        require(params_.aaveToken != address(0), "MAV3SI:I:ZERO_AAVE_TOKEN");

        require(params_.strategyDelegateFeeRate + params_.strategyProtocolFeeRate <= 1e6, "MAV3SI:I:INVALID_SUM_FEE_RATE");

        address factory_    = IStrategyManagerLike(strategyManager_).factory();
        address globals_    = IProxyFactoryLike(msg.sender).mapleGlobals();
        address fundsAsset_ = IAaveTokenLike(params_.aaveToken).UNDERLYING_ASSET_ADDRESS();

        require(IGlobalsLike(globals_).isInstanceOf("STRATEGY_MANAGER_FACTORY", factory_),    "MAV3SI:I:INVALID_FACTORY");
        require(IProxyFactoryLike(factory_).isInstance(strategyManager_),                     "MAV3SI:I:INVALID_INSTANCE");
        require(IStrategyManagerLike(strategyManager_).underlyingStrategy() == address(this), "MAV3SI:I:INVALID_UNDERLYING");

        require(IGlobalsLike(globals_).isInstanceOf("STRATEGY_VAULT", params_.aaveToken), "MAV3SI:I:INVALID_STRATEGY_VAULT");
        require(IGlobalsLike(globals_).isPoolAsset(fundsAsset_),                          "MAV3SI:I:INVALID_ASSET");

        strategyManager = strategyManager_;
        fundsAsset      = fundsAsset_;
        aavePool        = IAaveTokenLike(params_.aaveToken).POOL();
        aaveToken       = params_.aaveToken;

        strategyDelegateFeeRate = params_.strategyDelegateFeeRate;
        strategyProtocolFeeRate = params_.strategyProtocolFeeRate;
        referralCode            = params_.referralCode;

        _locked = 1;

        emit Initialized(strategyManager_, params_);
    }

    fallback() external {
        address           strategyManager_ = abi.decode(msg.data[:32], (address));
        Parameters memory params_          = abi.decode(msg.data[32:], (Parameters));

        _initialize(strategyManager_, params_);
    }

}
