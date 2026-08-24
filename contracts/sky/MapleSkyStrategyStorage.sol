// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import { IMapleSkyStrategyStorage } from "../interfaces/IMapleSkyStrategyStorage.sol";

contract MapleSkyStrategyStorage is IMapleSkyStrategyStorage {

    uint256 internal _locked;

    address public override fundsAsset;
    address public override psm;
    address public override strategyManager;
    address public override savingsUsds;
    address public override usds;

    bool public override isLossRecognized;

    uint256 public override fallbackTout;
    uint256 public override impairedAssets;
    uint256 public override lastRecordedTotalAssets;

    uint32 public override strategyDelegateFeeRate;
    uint32 public override strategyProtocolFeeRate;

    uint16 public override referralCode;

    string public override strategyMetadata;

}
