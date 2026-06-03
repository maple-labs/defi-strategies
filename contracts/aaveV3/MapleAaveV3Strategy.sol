// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { ERC20Helper } from "../../modules/erc20-helper/src/ERC20Helper.sol";

import { MapleProxiedInternals } from "../../modules/proxy-factory/contracts/MapleProxiedInternals.sol";

import { IMapleAaveV3Strategy } from "../interfaces/IMapleAaveV3Strategy.sol";

import {
    IAavePoolLike,
    IAaveTokenLike,
    IGlobalsLike,
    IProxyFactoryLike,
    IStrategyManagerLike
} from "../interfaces/Interfaces.sol";

import { MapleAaveV3StrategyStorage } from "./MapleAaveV3StrategyStorage.sol";

contract MapleAaveV3Strategy is IMapleAaveV3Strategy, MapleAaveV3StrategyStorage, MapleProxiedInternals {

    /**************************************************************************************************************************************/
    /*** Constants                                                                                                                      ***/
    /**************************************************************************************************************************************/

    // TODO: Add strategy type constant

    uint256 public constant HUNDRED_PERCENT = 1_000_000;

    /**************************************************************************************************************************************/
    /*** Modifiers                                                                                                                      ***/
    /**************************************************************************************************************************************/

    modifier nonReentrant() {
        require(_locked == 1, "MAV3S:LOCKED");

        _locked = 2;

        _;

        _locked = 1;
    }

    modifier onlyFactory() {
        require(msg.sender == _factory(), "MAV3S:NOT_FACTORY");

        _;
    }

    modifier onlyProtocolAdmins() {
        address globals_ = globals();

        require(
            msg.sender == IGlobalsLike(globals_).governor() ||
            msg.sender == IGlobalsLike(globals_).operationalAdmin(),
            "MAV3S:NOT_ADMIN"
        );

        _;
    }

    modifier onlyStrategyDelegate() {
        require(msg.sender == strategyDelegate(), "MAV3S:NOT_STRATEGY_DELEGATE");

        _;
    }

    modifier onlyStrategyManager() {
        require(msg.sender == strategyManager, "MAV3S:NOT_STRATEGY_MANAGER");

        _;
    }

    modifier whenNotPaused() {
        require(!IGlobalsLike(globals()).isFunctionPaused(msg.sig), "MAV3S:PAUSED");

        _;
    }

    /**************************************************************************************************************************************/
    /*** Proxy Functions                                                                                                                ***/
    /**************************************************************************************************************************************/

    function migrate(address migrator_, bytes calldata arguments_) external override whenNotPaused onlyFactory {
        require(_migrate(migrator_, arguments_), "MAV3S:M:FAILED");
    }

    function setImplementation(address implementation_) external override whenNotPaused onlyFactory {
        _setImplementation(implementation_);
    }

    function upgrade(uint256 version_, bytes calldata arguments_) external override whenNotPaused {
        require(msg.sender == securityAdmin(), "MAV3S:U:NOT_AUTHORIZED");

        IProxyFactoryLike(_factory()).upgradeInstance(version_, arguments_);

        emit Upgraded(version_, arguments_);
    }

    /**************************************************************************************************************************************/
    /*** Admin Functions                                                                                                                ***/
    /**************************************************************************************************************************************/

    function setStrategyDelegateFeeRate(uint32 strategyDelegateFeeRate_) external override whenNotPaused nonReentrant onlyStrategyDelegate {
        require(strategyDelegateFeeRate_ + strategyProtocolFeeRate <= HUNDRED_PERCENT, "MAV3S:SSDFR:INVALID_SUM_FEE_RATE");

        address aaveToken_  = aaveToken;

        _accrueFees(aavePool, aaveToken_, fundsAsset);

        lastRecordedTotalAssets = _currentTotalAssets(aaveToken_);

        strategyDelegateFeeRate = strategyDelegateFeeRate_;

        emit StrategyDelegateFeeRateSet(strategyDelegateFeeRate_);
    }

    function setStrategyProtocolFeeRate(uint32 strategyProtocolFeeRate_) external override whenNotPaused nonReentrant onlyProtocolAdmins {
        require(strategyDelegateFeeRate + strategyProtocolFeeRate_ <= HUNDRED_PERCENT, "MAV3S:SSPFR:INVALID_SUM_FEE_RATE");

        address aaveToken_  = aaveToken;

        _accrueFees(aavePool, aaveToken_, fundsAsset);

        lastRecordedTotalAssets = _currentTotalAssets(aaveToken_);

        strategyProtocolFeeRate = strategyProtocolFeeRate_;

        emit StrategyProtocolFeeRateSet(strategyProtocolFeeRate_);
    }

    /**************************************************************************************************************************************/
    /*** State-Changing Functions                                                                                                       ***/
    /**************************************************************************************************************************************/

    // TODO: Should other actors be able to call this function?
    // TODO: Reconsider need for aum diff for deployedAssets_ return var
    function fundUnderlyingStrategy(
        uint256 assetsIn_,
        bytes calldata /* data_ */
    )
        external override whenNotPaused nonReentrant onlyStrategyManager returns (uint256 deployedAssets_)
    {
        require(assetsIn_ > 0, "MAV3S:FUS:ZERO_ASSETS");

        address aavePool_   = aavePool;
        address aaveToken_  = aaveToken;
        address fundsAsset_ = fundsAsset;

        require(IGlobalsLike(globals()).isInstanceOf("STRATEGY_VAULT", aaveToken_), "MAV3S:FUS:INVALID_STRATEGY_VAULT");

        _accrueFees(aavePool_, aaveToken_, fundsAsset_);

        uint256 aumBefore_ = _currentTotalAssets(aaveToken_);

        require(ERC20Helper.approve(fundsAsset_, aavePool_, assetsIn_), "MAV3S:FUS:ASSET_APPROVE_FAIL");

        IAavePoolLike(aavePool_).supply(fundsAsset_, assetsIn_, address(this), referralCode);

        uint256 aumAfter_ = _currentTotalAssets(aaveToken_);

        lastRecordedTotalAssets = aumAfter_;
        deployedAssets_         = aumAfter_ - aumBefore_;

        emit StrategyFunded(msg.sender, assetsIn_, deployedAssets_);
    }

    function withdrawFromUnderlyingStrategy(
        address destination_,
        uint256 assets_,
        bytes calldata /* data_ */
    )
        external override whenNotPaused nonReentrant onlyStrategyManager
    {
        require(destination_ != address(0), "MAV3S:WFUS:ZERO_DESTINATION");
        require(assets_       > 0,          "MAV3S:WFUS:ZERO_ASSETS");

        address aavePool_   = aavePool;
        address aaveToken_  = aaveToken;
        address fundsAsset_ = fundsAsset;

        _accrueFees(aavePool_, aaveToken_, fundsAsset_);

        uint256 assetsOut_ = IAavePoolLike(aavePool_).withdraw(fundsAsset_, assets_, destination_);

        lastRecordedTotalAssets = _currentTotalAssets(aaveToken_);

        // TODO: remove strategyManager from event?
        emit StrategyWithdrawal(msg.sender, destination_, assetsOut_);
    }

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    function assetsUnderManagement() external view override returns (uint256 assetsUnderManagement_) {
        uint256 currentTotalAssets_ = _currentTotalAssets(aaveToken);

        ( uint256 delegateFee_, uint256 protocolFee_ ) = _currentAccruedFees(currentTotalAssets_);

        assetsUnderManagement_ = currentTotalAssets_ - delegateFee_ - protocolFee_;
    }

    function factory() external view override returns (address factory_) {
        factory_ = _factory();
    }

    function globals() public view override returns (address globals_) {
        globals_ = IProxyFactoryLike(_factory()).mapleGlobals();
    }

    function implementation() external view override returns (address implementation_) {
        implementation_ = _implementation();
    }

    function mapleTreasury() public view override returns (address mapleTreasury_) {
        mapleTreasury_ = IGlobalsLike(globals()).mapleTreasury();
    }

    function securityAdmin() public view override returns (address securityAdmin_) {
        securityAdmin_ = IGlobalsLike(globals()).securityAdmin();
    }

    function strategyDelegate() public view override returns (address strategyDelegate_) {
        strategyDelegate_ = IStrategyManagerLike(strategyManager).strategyDelegate();
    }

    /**************************************************************************************************************************************/
    /*** Internal Functions                                                                                                             ***/
    /**************************************************************************************************************************************/

    function _accrueFees(address aavePool_, address aaveToken_, address fundsAsset_) internal {
        uint256 currentTotalAssets_ = _currentTotalAssets(aaveToken_);

        ( uint256 delegateFee_, uint256 protocolFee_ ) = _currentAccruedFees(currentTotalAssets_);

        if (delegateFee_ != 0) IAavePoolLike(aavePool_).withdraw(fundsAsset_, delegateFee_, strategyDelegate());
        if (protocolFee_ != 0) IAavePoolLike(aavePool_).withdraw(fundsAsset_, protocolFee_, mapleTreasury());

        emit StrategyFeesCollected(delegateFee_, protocolFee_);
    }

    /**************************************************************************************************************************************/
    /*** Internal View Functions                                                                                                        ***/
    /**************************************************************************************************************************************/

    function _currentAccruedFees(uint256 currentTotalAssets_) internal view returns (uint256 delegateFee_, uint256 protocolFee_) {
        uint256 lastRecordedTotalAssets_ = lastRecordedTotalAssets;

        if (currentTotalAssets_ <= lastRecordedTotalAssets_) return (0, 0);

        uint256 yieldAccrued_ = currentTotalAssets_ - lastRecordedTotalAssets_;
        // It is acknowledged that delegateFee_ & protocolFee_ may be rounded down to 0 if yieldAccrued_ * FeeRate_ < HUNDRED_PERCENT.
        delegateFee_ = yieldAccrued_ * strategyDelegateFeeRate / HUNDRED_PERCENT;
        protocolFee_ = yieldAccrued_ * strategyProtocolFeeRate / HUNDRED_PERCENT;
    }

    function _currentTotalAssets(address aaveToken_) internal view returns (uint256 currentTotalAssets_) {
        currentTotalAssets_ = IAaveTokenLike(aaveToken_).balanceOf(address(this));
    }

}
