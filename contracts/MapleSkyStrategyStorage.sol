// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { IMapleSkyStrategyStorage } from "./interfaces/IMapleSkyStrategyStorage.sol";

contract MapleSkyStrategyStorage is IMapleSkyStrategyStorage {

    uint256 internal _locked;  // Used as a reentrancy guard.

    address public override strategyManager;
    address public override fundsAsset;
    address public override psm;
    address public override savingsUsds;
    address public override usds;

    uint32 public override strategyDelegateFeeRate;
    uint32 public override strategyProtocolFeeRate;

    uint16 public override referralCode;

}
