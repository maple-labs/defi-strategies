// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { IMapleAaveV3StrategyStorage } from "../interfaces/IMapleAaveV3StrategyStorage.sol";

contract MapleAaveV3StrategyStorage is IMapleAaveV3StrategyStorage {

    uint256 internal _locked;

    address public override aavePool;
    address public override aaveToken;
    address public override fundsAsset;
    address public override strategyManager;

}
