// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { IMapleAaveV3StrategyInitializer } from "../interfaces/IMapleAaveV3StrategyInitializer.sol";

import { MapleAaveV3StrategyStorage } from "./MapleAaveV3StrategyStorage.sol";

contract MapleAaveV3StrategyInitializer is IMapleAaveV3StrategyInitializer, MapleAaveV3StrategyStorage {

    function _initialize(IMapleAaveV3StrategyInitializer.Parameters memory /* params_ */) internal {
        // TODO: Add Aave V3 validation and storage initialization.
    }

    fallback() external {
        _initialize(abi.decode(msg.data, (Parameters)));
    }

}
