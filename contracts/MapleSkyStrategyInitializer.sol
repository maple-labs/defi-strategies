// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { IMapleSkyStrategyInitializer } from "./interfaces/IMapleSkyStrategyInitializer.sol";

import { MapleSkyStrategyStorage } from "./MapleSkyStrategyStorage.sol";

contract MapleSkyStrategyInitializer is IMapleSkyStrategyInitializer, MapleSkyStrategyStorage {

    function _initialize(IMapleSkyStrategyInitializer.Parameters memory params_) internal {
        manager = params_.manager;

        emit Initialized(params_);
    }

    fallback() external {
        _initialize(abi.decode(msg.data, (Parameters)));
    }

}
