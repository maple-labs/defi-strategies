// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { IMapleSkyStrategyStorage } from "./interfaces/IMapleSkyStrategyStorage.sol";

contract MapleSkyStrategyStorage is IMapleSkyStrategyStorage {

    bool transient internal _locked;  // Used as a reentrancy guard.

    address public override manager;

}
