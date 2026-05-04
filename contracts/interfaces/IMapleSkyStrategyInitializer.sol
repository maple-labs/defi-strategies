// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 *  @title Defines a contract used to initialize new Maple Sky strategies.
 */
interface IMapleSkyStrategyInitializer {

    /**
     *  @dev   Parameters required to initialize a Sky strategy.
     *  @param manager Address of the strategy manager contract.
     */
    struct Parameters {
        address manager;
    }

    /**
     *  @dev   Emitted when the Sky strategy proxy is initialized.
     *  @param params Sky strategy parameters set during initialization.
     */
    event Initialized(Parameters params);

}
