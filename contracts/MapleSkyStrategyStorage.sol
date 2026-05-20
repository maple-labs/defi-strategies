// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { IMapleSkyStrategyStorage } from "./interfaces/IMapleSkyStrategyStorage.sol";

contract MapleSkyStrategyStorage is IMapleSkyStrategyStorage {

    uint256 internal _locked;

    address public override fundsAsset;
    address public override psm;
    address public override strategyManager;
    address public override savingsUsds;
    address public override usds;

    uint256 public override lastRecordedTotalAssets;

    uint32 public override strategyDelegateFeeRate;
    uint32 public override strategyProtocolFeeRate;

    uint16 public override referralCode;

}
