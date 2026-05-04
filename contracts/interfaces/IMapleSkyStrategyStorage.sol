// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 *  @title Defines the storage layout of a Maple Sky strategy.
 */
interface IMapleSkyStrategyStorage {

    /**
     *  @dev    Returns the address of the strategy manager contract.
     *  @return manager Address of the strategy manager.
     */
    function manager() external view returns (address manager);

}
