// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { IMapleSkyStrategyInitializer } from "../interfaces/IMapleSkyStrategyInitializer.sol";
import {
    IERC4626Like,
    IGlobalsLike,
    IPSMLike,
    IProxyFactoryLike,
    IStrategyManagerLike
} from "../interfaces/Interfaces.sol";

import { MapleSkyStrategyStorage } from "./MapleSkyStrategyStorage.sol";

contract MapleSkyStrategyInitializer is IMapleSkyStrategyInitializer, MapleSkyStrategyStorage {

    function _initialize(IMapleSkyStrategyInitializer.Parameters memory params_) internal {
        require(params_.strategyManager != address(0), "MSSI:I:ZERO_STRATEGY_MANAGER");
        require(params_.savingsUsds     != address(0), "MSSI:I:ZERO_SAVINGS_USDS");
        require(params_.psm             != address(0), "MSSI:I:ZERO_PSM");

        require(params_.strategyDelegateFeeRate + params_.strategyProtocolFeeRate <= 1e6, "MSSI:I:INVALID_SUM_FEE_RATE");

        address factory_ = IStrategyManagerLike(params_.strategyManager).factory();
        address globals_ = IProxyFactoryLike(msg.sender).mapleGlobals();
        address usds_    = IERC4626Like(params_.savingsUsds).asset();

        require(IGlobalsLike(globals_).isPoolAsset(params_.fundsAsset), "MSSI:I:INVALID_ASSET");

        require(IGlobalsLike(globals_).isInstanceOf("STRATEGY_MANAGER_FACTORY", factory_),           "MSSI:I:INVALID_FACTORY");
        require(IProxyFactoryLike(factory_).isInstance(params_.strategyManager),                     "MSSI:I:INVALID_INSTANCE");
        require(IStrategyManagerLike(params_.strategyManager).underlyingStrategy() == address(this), "MSSI:I:INVALID_UNDERLYING");

        require(IGlobalsLike(globals_).isInstanceOf("STRATEGY_VAULT", params_.savingsUsds), "MSSI:I:INVALID_STRATEGY_VAULT");
        require(IGlobalsLike(globals_).isInstanceOf("PSM", params_.psm),                    "MSSI:I:INVALID_PSM");

        // Sky strategy withdrawals rely on LitePSM-compatible PSMs, where gem liquidity is held in a pocket address.
        require(IPSMLike(params_.psm).gem() == params_.fundsAsset, "MSSI:I:INVALID_GEM_PSM");
        require(IPSMLike(params_.psm).usds() == usds_,             "MSSI:I:INVALID_USDS_PSM");
        require(IPSMLike(params_.psm).pocket() != address(0),      "MSSI:I:INVALID_POCKET_PSM");

        strategyManager = params_.strategyManager;
        fundsAsset      = params_.fundsAsset;
        psm             = params_.psm;
        savingsUsds     = params_.savingsUsds;
        usds            = usds_;

        strategyDelegateFeeRate = params_.strategyDelegateFeeRate;
        strategyProtocolFeeRate = params_.strategyProtocolFeeRate;
        referralCode            = params_.referralCode;

        _locked = 1;

        emit Initialized(params_);
    }

    fallback() external {
        _initialize(abi.decode(msg.data, (Parameters)));
    }

}
