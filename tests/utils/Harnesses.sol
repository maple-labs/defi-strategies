// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MapleAaveV3Strategy }            from "../../contracts/aaveV3/MapleAaveV3Strategy.sol";
import { MapleAaveV3StrategyInitializer } from "../../contracts/aaveV3/MapleAaveV3StrategyInitializer.sol";

import { AaveV3StrategyInitializerParams } from "../../contracts/interfaces/IMapleAaveV3StrategyInitializer.sol";
import { SkyStrategyInitializerParams }    from "../../contracts/interfaces/IMapleSkyStrategyInitializer.sol";

import { MapleSkyStrategy }            from "../../contracts/sky/MapleSkyStrategy.sol";
import { MapleSkyStrategyInitializer } from "../../contracts/sky/MapleSkyStrategyInitializer.sol";

contract MapleAaveV3StrategyHarness is MapleAaveV3Strategy {

    function locked() external view returns (uint256 locked_) {
        locked_ = _locked;
    }

    function __setIsLossRecognized(bool isLossRecognized_) external {
        isLossRecognized = isLossRecognized_;
    }

    function __setLastRecordedTotalAssets(uint256 lastRecordedTotalAssets_) external {
        lastRecordedTotalAssets = lastRecordedTotalAssets_;
    }

    function __setImpairedAssets(uint256 impairedAssets_) external {
        impairedAssets = impairedAssets_;
    }

    function __setLocked(uint256 locked_) external {
        _locked = locked_;
    }

    function __setStrategyDelegateFeeRate(uint32 strategyDelegateFeeRate_) external {
        strategyDelegateFeeRate = strategyDelegateFeeRate_;
    }

    function __setStrategyProtocolFeeRate(uint32 strategyProtocolFeeRate_) external {
        strategyProtocolFeeRate = strategyProtocolFeeRate_;
    }

    function __setUseVirtualUnderlyingBalance(bool useVirtualUnderlyingBalance_) external {
        useVirtualUnderlyingBalance = useVirtualUnderlyingBalance_;
    }

}

contract MapleAaveV3StrategyInitializerHarness is MapleAaveV3StrategyInitializer {

    function __initialize(address strategyManager_, AaveV3StrategyInitializerParams memory params_) external {
        _initialize(strategyManager_, params_);
    }

    function locked() external view returns (uint256 locked_) {
        locked_ = _locked;
    }

}

contract MapleSkyStrategyHarness is MapleSkyStrategy {

    function locked() external view returns (uint256 locked_) {
        locked_ = _locked;
    }

    function __setFallbackTout(uint256 fallbackTout_) external {
        fallbackTout = fallbackTout_;
    }

    function __setIsLossRecognized(bool isLossRecognized_) external {
        isLossRecognized = isLossRecognized_;
    }

    function __setLastRecordedTotalAssets(uint256 lastRecordedTotalAssets_) external {
        lastRecordedTotalAssets = lastRecordedTotalAssets_;
    }

    function __setLocked(uint256 locked_) external {
        _locked = locked_;
    }

    function __setStrategyDelegateFeeRate(uint32 strategyDelegateFeeRate_) external {
        strategyDelegateFeeRate = strategyDelegateFeeRate_;
    }

    function __setStrategyProtocolFeeRate(uint32 strategyProtocolFeeRate_) external {
        strategyProtocolFeeRate = strategyProtocolFeeRate_;
    }

    function __setImpairedAssets(uint256 impairedAssets_) external {
        impairedAssets = impairedAssets_;
    }

}

contract MapleSkyStrategyInitializerHarness is MapleSkyStrategyInitializer {

    function __initialize(address strategyManager_, SkyStrategyInitializerParams memory params_) external {
        _initialize(strategyManager_, params_);
    }

    function locked() external view returns (uint256 locked_) {
        locked_ = _locked;
    }

}
