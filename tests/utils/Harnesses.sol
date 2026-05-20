// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MapleSkyStrategy }            from "../../contracts/MapleSkyStrategy.sol";
import { MapleSkyStrategyInitializer } from "../../contracts/MapleSkyStrategyInitializer.sol";

contract MapleSkyStrategyHarness is MapleSkyStrategy {

    function locked() external view returns (uint256 locked_) {
        locked_ = _locked;
    }

    function __setLastRecordedTotalAssets(uint256 lastRecordedTotalAssets_) external {
        lastRecordedTotalAssets = lastRecordedTotalAssets_;
    }

    function __setLocked(uint256 locked_) external {
        _locked = locked_;
    }

    function __setReferralCode(uint16 referralCode_) external {
        referralCode = referralCode_;
    }

    function __setStrategyDelegateFeeRate(uint32 strategyDelegateFeeRate_) external {
        strategyDelegateFeeRate = strategyDelegateFeeRate_;
    }

    function __setStrategyProtocolFeeRate(uint32 strategyProtocolFeeRate_) external {
        strategyProtocolFeeRate = strategyProtocolFeeRate_;
    }

}

contract MapleSkyStrategyInitializerHarness is MapleSkyStrategyInitializer {

    function __initialize(Parameters memory params_) external {
        _initialize(params_);
    }

    function locked() external view returns (uint256 locked_) {
        locked_ = _locked;
    }

}
