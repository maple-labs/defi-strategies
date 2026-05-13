// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MockERC20 } from "../../modules/erc20/contracts/test/mocks/MockERC20.sol";

import { MapleSkyStrategyStorage } from "../../contracts/MapleSkyStrategyStorage.sol";

contract MockAsset is MockERC20("Asset", "A", 6) {

    bool transferReverts;
    bool transferFromReverts;

    function __setTransferReverts(bool transferReverts_) external {
        transferReverts = transferReverts_;
    }

    function __setTransferFromReverts(bool transferFromReverts_) external {
        transferFromReverts = transferFromReverts_;
    }

    function transfer(address to_, uint256 amount_) public override returns (bool success_) {
        require(!transferReverts);

        success_ = super.transfer(to_, amount_);
    }

    function transferFrom(address from_, address to_, uint256 amount_) public override returns (bool success_) {
        require(!transferFromReverts);

        success_ = super.transferFrom(from_, to_, amount_);
    }

}

contract MockFactory {

    mapping(address => bool) public isInstance;

    function __setIsInstance(address instance_, bool isInstance_) external {
        isInstance[instance_] = isInstance_;
    }

}

contract MockGlobals {

    address public governor;
    address public securityAdmin;

    bool public protocolPaused;

    mapping(address => bool) public canDeploy;

    mapping(bytes4 => bool) public isFunctionPaused;

    mapping(bytes32 => mapping(address => bool)) public isInstanceOf;

    mapping(address => bool) public isPoolAsset;

    function __setCanDeploy(address caller_, bool canDeploy_) external {
        canDeploy[caller_] = canDeploy_;
    }

    function __setGovernor(address governor_) external {
        governor = governor_;
    }

    function __setIsFunctionPaused(bytes4 signature_, bool isFunctionPaused_) external {
        isFunctionPaused[signature_] = isFunctionPaused_;
    }

    function __setIsInstanceOf(bytes32 key_, address instance_, bool isInstanceOf_) external {
        isInstanceOf[key_][instance_] = isInstanceOf_;
    }

    function __setIsPoolAsset(address asset_, bool isPoolAsset_) external {
        isPoolAsset[asset_] = isPoolAsset_;
    }

    function __setProtocolPaused(bool protocolPaused_) external {
        protocolPaused = protocolPaused_;
    }

    function __setSecurityAdmin(address securityAdmin_) external {
        securityAdmin = securityAdmin_;
    }

}

contract MockManager {

    address public factory;
    address public underlyingStrategy;

    function __setFactory(address factory_) external {
        factory = factory_;
    }

    function __setUnderlyingStrategy(address underlyingStrategy_) external {
        underlyingStrategy = underlyingStrategy_;
    }

}

contract MockPsm {

    address public gem;

    address public usds;

    function __setGem(address gem_) external {
        gem = gem_;
    }

    function __setUsds(address usds_) external {
        usds = usds_;
    }

}

contract MockSavingsUsds {

    address public asset;

    function __setAsset(address asset_) external {
        asset = asset_;
    }

}

contract MockMigrator is MapleSkyStrategyStorage {

    fallback() external {
        strategyManager = abi.decode(msg.data, (address));
    }

}
