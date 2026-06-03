// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { ERC20Helper } from "../../modules/erc20-helper/src/ERC20Helper.sol";

import { MapleProxiedInternals } from "../../modules/proxy-factory/contracts/MapleProxiedInternals.sol";

import { IMapleSkyStrategy } from "../interfaces/IMapleSkyStrategy.sol";

import {
    IERC4626Like,
    IGlobalsLike,
    IPSMLike,
    IProxyFactoryLike,
    IStrategyManagerLike
} from "../interfaces/Interfaces.sol";

import { MapleSkyStrategyStorage } from "./MapleSkyStrategyStorage.sol";

contract MapleSkyStrategy is IMapleSkyStrategy, MapleSkyStrategyStorage, MapleProxiedInternals {

    /**************************************************************************************************************************************/
    /*** Constants                                                                                                                      ***/
    /**************************************************************************************************************************************/

    // TODO: Add strategy type constant

    uint256 internal constant WAD = 1e18;

    uint256 public constant HUNDRED_PERCENT = 1_000_000;

    /**************************************************************************************************************************************/
    /*** Modifiers                                                                                                                      ***/
    /**************************************************************************************************************************************/

    modifier nonReentrant() {
        require(_locked == 1, "MSS:LOCKED");

        _locked = 2;

        _;

        _locked = 1;
    }

    modifier onlyFactory() {
        require(msg.sender == _factory(), "MSS:NOT_FACTORY");

        _;
    }

    modifier onlyProtocolAdmins() {
        address globals_ = globals();

        require(
            msg.sender == IGlobalsLike(globals_).governor() ||
            msg.sender == IGlobalsLike(globals_).operationalAdmin(),
            "MSS:NOT_ADMIN"
        );

        _;
    }

    modifier onlyStrategyDelegate() {
        require(msg.sender == strategyDelegate(), "MSS:NOT_STRATEGY_DELEGATE");

        _;
    }

    modifier onlyStrategyManager() {
        require(msg.sender == strategyManager, "MSS:NOT_STRATEGY_MANAGER");

        _;
    }

    modifier whenNotPaused() {
        require(!IGlobalsLike(globals()).isFunctionPaused(msg.sig), "MSS:PAUSED");

        _;
    }

    /**************************************************************************************************************************************/
    /*** Proxy Functions                                                                                                                ***/
    /**************************************************************************************************************************************/

    function migrate(address migrator_, bytes calldata arguments_) external override whenNotPaused onlyFactory {
        require(_migrate(migrator_, arguments_), "MSS:M:FAILED");
    }

    function setImplementation(address implementation_) external override whenNotPaused onlyFactory {
        _setImplementation(implementation_);
    }

    function upgrade(uint256 version_, bytes calldata arguments_) external override whenNotPaused {
        require(msg.sender == securityAdmin(), "MSS:U:NOT_AUTHORIZED");

        IProxyFactoryLike(_factory()).upgradeInstance(version_, arguments_);

        emit Upgraded(version_, arguments_);
    }

    /**************************************************************************************************************************************/
    /*** Admin Functions                                                                                                                ***/
    /**************************************************************************************************************************************/

    function setStrategyDelegateFeeRate(uint32 strategyDelegateFeeRate_) external override whenNotPaused nonReentrant onlyStrategyDelegate {
        require(strategyDelegateFeeRate_ + strategyProtocolFeeRate <= HUNDRED_PERCENT, "MSS:SSDFR:INVALID_SUM_FEE_RATE");

        address psm_         = psm;
        address savingsUsds_ = savingsUsds;

        _accrueFees(psm_, savingsUsds_);

        lastRecordedTotalAssets = _currentTotalAssets(psm_, savingsUsds_);

        strategyDelegateFeeRate = strategyDelegateFeeRate_;

        emit StrategyDelegateFeeRateSet(strategyDelegateFeeRate_);
    }

    function setStrategyProtocolFeeRate(uint32 strategyProtocolFeeRate_) external override whenNotPaused nonReentrant onlyProtocolAdmins {
        require(strategyDelegateFeeRate + strategyProtocolFeeRate_ <= HUNDRED_PERCENT, "MSS:SSPFR:INVALID_SUM_FEE_RATE");

        address psm_         = psm;
        address savingsUsds_ = savingsUsds;

        _accrueFees(psm_, savingsUsds_);

        lastRecordedTotalAssets = _currentTotalAssets(psm_, savingsUsds_);

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
        require(assetsIn_ > 0, "MSS:FUS:ZERO_ASSETS");

        address globals_     = globals();
        address psm_         = psm;
        address savingsUsds_ = savingsUsds;

        require(IGlobalsLike(globals_).isInstanceOf("STRATEGY_VAULT", savingsUsds_), "MSS:FUS:INVALID_STRATEGY_VAULT");
        require(IGlobalsLike(globals_).isInstanceOf("PSM",            psm_),         "MSS:FUS:INVALID_PSM");

        _accrueFees(psm_, savingsUsds_);

        uint256 aumBefore_ = _currentTotalAssets(psm_, savingsUsds_);

        require(ERC20Helper.approve(fundsAsset, psm_, assetsIn_), "MSS:FUS:GEM_APPROVE_FAIL");

        uint256 usdsOut_ = IPSMLike(psm_).sellGem(address(this), assetsIn_);

        require(ERC20Helper.approve(usds, savingsUsds_, usdsOut_), "MSS:FUS:USDS_APPROVE_FAIL");

        uint256 sharesMinted_ = IERC4626Like(savingsUsds_).deposit(usdsOut_, address(this), referralCode);
        uint256 aumAfter_     = _currentTotalAssets(psm_, savingsUsds_);

        lastRecordedTotalAssets = aumAfter_;
        deployedAssets_         = aumAfter_ - aumBefore_;

        emit StrategyFunded(msg.sender, assetsIn_, sharesMinted_, deployedAssets_);
    }

    function withdrawFromUnderlyingStrategy(
        address destination_,
        uint256 assets_,
        bytes calldata /* data_ */
    )
        external override whenNotPaused nonReentrant onlyStrategyManager
    {
        require(destination_ != address(0), "MSS:WFUS:ZERO_DESTINATION");
        require(assets_       > 0,          "MSS:WFUS:ZERO_ASSETS");

        address psm_         = psm;
        address savingsUsds_ = savingsUsds;

        _accrueFees(psm_, savingsUsds_);

        uint256 sharesBurned_ = _withdraw(psm_, savingsUsds_, assets_, destination_);

        lastRecordedTotalAssets = _currentTotalAssets(psm_, savingsUsds_);

        // TODO: remove strategyManager from event?
        emit StrategyWithdrawal(msg.sender, destination_, sharesBurned_, assets_);
    }

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    function assetsUnderManagement() public view override returns (uint256 assetsUnderManagement_) {
        uint256 currentTotalAssets_ = _currentTotalAssets(psm, savingsUsds);

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

    function _accrueFees(address psm_, address savingsUsds_) internal {
        uint256 currentTotalAssets_ = _currentTotalAssets(psm_, savingsUsds_);

        ( uint256 delegateFee_, uint256 protocolFee_ ) = _currentAccruedFees(currentTotalAssets_);

        if (delegateFee_ != 0) _withdraw(psm_, savingsUsds_, delegateFee_, strategyDelegate());
        if (protocolFee_ != 0) _withdraw(psm_, savingsUsds_, protocolFee_, mapleTreasury());

        emit StrategyFeesCollected(delegateFee_, protocolFee_);
    }

    function _withdraw(
        address psm_,
        address savingsUsds_,
        uint256 assets_,
        address destination_
    )
        internal returns (uint256 sharesBurned_)
    {
        uint256 requiredUsds_ = _usdsForGem(psm_, assets_);

        sharesBurned_ = IERC4626Like(savingsUsds_).withdraw(requiredUsds_, address(this), address(this));

        require(ERC20Helper.approve(usds, psm_, requiredUsds_), "MSS:W:USDS_APPROVE_FAIL");

        IPSMLike(psm_).buyGem(destination_, assets_);
    }

    /**************************************************************************************************************************************/
    /*** Internal View Functions                                                                                                        ***/
    /**************************************************************************************************************************************/

    function _currentAccruedFees(uint256 currentTotalAssets_) internal view returns (uint256 delegateFee_, uint256 protocolFee_) {
        uint256 lastRecordedTotalAssets_ = lastRecordedTotalAssets;

        if (currentTotalAssets_ <= lastRecordedTotalAssets_) return (0, 0);

        uint256 yieldAccrued_ = currentTotalAssets_ - lastRecordedTotalAssets_;

        delegateFee_ = yieldAccrued_ * strategyDelegateFeeRate / HUNDRED_PERCENT;
        protocolFee_ = yieldAccrued_ * strategyProtocolFeeRate / HUNDRED_PERCENT;
    }

    function _currentTotalAssets(address psm_, address savingsUsds_)
        internal view returns (uint256 currentTotalAssets_)
    {
        currentTotalAssets_ = _gemForUsds(
            psm_,
            IERC4626Like(savingsUsds_).previewRedeem(IERC4626Like(savingsUsds_).balanceOf(address(this)))
        );
    }

    function _gemForUsds(address psm_, uint256 usdsAmount_) internal view returns (uint256 gemAmount_) {
        uint256 tout_                 = IPSMLike(psm_).tout();
        uint256 to18ConversionFactor_ = IPSMLike(psm_).to18ConversionFactor();

        gemAmount_ = (usdsAmount_ * WAD) / (to18ConversionFactor_ * (WAD + tout_));
    }

    function _usdsForGem(address psm_, uint256 gemAmount_) internal view returns (uint256 usdsAmount_) {
        uint256 tout_                 = IPSMLike(psm_).tout();
        uint256 to18ConversionFactor_ = IPSMLike(psm_).to18ConversionFactor();
        uint256 gemAmt18_             = gemAmount_ * to18ConversionFactor_;

        usdsAmount_ = gemAmt18_ + gemAmt18_ * tout_ / WAD;
    }

}
