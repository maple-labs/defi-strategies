// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MapleSkyStrategy }            from "../../contracts/MapleSkyStrategy.sol";
import { MapleSkyStrategyInitializer } from "../../contracts/MapleSkyStrategyInitializer.sol";

contract MapleSkyStrategyHarness is MapleSkyStrategy {

    function locked() external view returns (uint256 locked_) {
        locked_ = _locked;
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
