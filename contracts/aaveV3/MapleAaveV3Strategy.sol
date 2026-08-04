// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { ERC20Helper } from "../../modules/erc20-helper/src/ERC20Helper.sol";

import { MapleProxiedInternals } from "../../modules/proxy-factory/contracts/MapleProxiedInternals.sol";

import { IMapleAaveV3Strategy } from "../interfaces/IMapleAaveV3Strategy.sol";

import {
    IAavePoolAddressesProviderLike,
    IAavePoolDataProviderLike,
    IAavePoolLike,
    IAaveRewardsControllerLike,
    IAaveTokenLike,
    IERC20Like,
    IGlobalsLike,
    IProxyFactoryLike,
    IStrategyManagerLike
} from "../interfaces/Interfaces.sol";

import { MapleAaveV3StrategyStorage } from "./MapleAaveV3StrategyStorage.sol";

contract MapleAaveV3Strategy is IMapleAaveV3Strategy, MapleAaveV3StrategyStorage, MapleProxiedInternals {

    /**************************************************************************************************************************************/
    /*** Constants                                                                                                                      ***/
    /**************************************************************************************************************************************/

    string public constant STRATEGY_TYPE = "AAVEV3";

    uint256 public constant HUNDRED_PERCENT = 1e6;

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

    modifier whenLossNotRecognized() {
        require(!isLossRecognized, "MAV3S:LOSS_RECOGNIZED");

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

    function claimRewards(address[] calldata assets_, uint256 amount_, address rewardToken_)
        external override whenNotPaused nonReentrant onlyProtocolAdmins
    {
        address rewardsController_ = IAaveTokenLike(aaveToken).getIncentivesController();

        uint256 rewardAmount_ = IAaveRewardsControllerLike(rewardsController_).claimRewards(
            assets_,
            amount_,
            mapleTreasury(),
            rewardToken_
        );

        emit RewardsClaimed(rewardToken_, rewardAmount_);
    }

    function impair(uint256 assets_) external override whenNotPaused nonReentrant onlyProtocolAdmins whenLossNotRecognized {
        require(assets_ > 0, "MAV3S:I:ZERO");

        impairedAssets += assets_;

        emit Impaired(assets_);
    }

    function multicall(bytes[] calldata data_) external override {
        for (uint256 i = 0; i < data_.length; i++) {
            ( bool success_, bytes memory returnData_ ) = address(this).delegatecall(data_[i]);

            if (!success_) {
                assembly ("memory-safe") {
                    revert(add(32, returnData_), mload(returnData_))
                }
            }
        }
    }

    function removeImpairment(uint256 assets_) external override whenNotPaused nonReentrant onlyProtocolAdmins whenLossNotRecognized {
        require(assets_ > 0,               "MAV3S:RI:ZERO");
        require(assets_ <= impairedAssets, "MAV3S:RI:EXCEEDS_IMPAIRMENT");

        impairedAssets -= assets_;

        emit ImpairmentRemoved(assets_);
    }

    function recognizeLoss() external override whenNotPaused nonReentrant onlyProtocolAdmins whenLossNotRecognized {
        isLossRecognized        = true;
        lastRecordedTotalAssets = 0;
        impairedAssets          = 0;

        emit LossRecognized();
    }

    function recoverPosition() external override whenNotPaused nonReentrant onlyProtocolAdmins {
        require(isLossRecognized, "MAV3S:RP:LOSS_NOT_RECOGNIZED");

        address aaveToken_ = aaveToken;
        uint256 balance_   = IAaveTokenLike(aaveToken_).balanceOf(address(this));

        require(balance_ > 0,                                                "MAV3S:RP:ZERO_BALANCE");
        require(ERC20Helper.transfer(aaveToken_, mapleTreasury(), balance_), "MAV3S:RP:TRANSFER_FAILED");

        emit PositionRecovered(balance_);
    }

    function setMetadata(string calldata metadata_) external override whenNotPaused nonReentrant onlyProtocolAdmins whenLossNotRecognized {
        require(keccak256(bytes(metadata_)) != keccak256(bytes(strategyMetadata)), "MAV3S:SM:NO_CHANGE");

        strategyMetadata = metadata_;

        emit StrategyMetadataSet(metadata_);
    }

    function setReferralCode(uint16 referralCode_) external override whenNotPaused nonReentrant onlyProtocolAdmins whenLossNotRecognized {
        require(referralCode_ != referralCode, "MAV3S:SRC:NO_CHANGE");

        referralCode = referralCode_;

        emit ReferralCodeSet(referralCode_);
    }

    function setStrategyDelegateFeeRate(uint32 strategyDelegateFeeRate_)
        external override whenNotPaused nonReentrant onlyStrategyDelegate whenLossNotRecognized
    {
        require(strategyDelegateFeeRate_ != strategyDelegateFeeRate,                   "MAV3S:SSDFR:NO_CHANGE");
        require(strategyDelegateFeeRate_ <= HUNDRED_PERCENT,                           "MAV3S:SSDFR:INVALID_FEE_RATE");
        require(strategyDelegateFeeRate_ + strategyProtocolFeeRate <= HUNDRED_PERCENT, "MAV3S:SSDFR:INVALID_SUM_FEE_RATE");

        _harvestAndWithdraw(0, address(0));

        lastRecordedTotalAssets = _currentTotalAssets(aaveToken);

        strategyDelegateFeeRate = strategyDelegateFeeRate_;

        emit StrategyDelegateFeeRateSet(strategyDelegateFeeRate_);
    }

    function setStrategyProtocolFeeRate(uint32 strategyProtocolFeeRate_)
        external override whenNotPaused nonReentrant onlyProtocolAdmins whenLossNotRecognized
    {
        require(strategyProtocolFeeRate_ != strategyProtocolFeeRate,                   "MAV3S:SSPFR:NO_CHANGE");
        require(strategyProtocolFeeRate_ <= HUNDRED_PERCENT,                           "MAV3S:SSPFR:INVALID_FEE_RATE");
        require(strategyDelegateFeeRate + strategyProtocolFeeRate_ <= HUNDRED_PERCENT, "MAV3S:SSPFR:INVALID_SUM_FEE_RATE");

        _harvestAndWithdraw(0, address(0));

        lastRecordedTotalAssets = _currentTotalAssets(aaveToken);

        strategyProtocolFeeRate = strategyProtocolFeeRate_;

        emit StrategyProtocolFeeRateSet(strategyProtocolFeeRate_);
    }

    function setUseVirtualUnderlyingBalance(bool useVirtualUnderlyingBalance_)
        external override whenNotPaused nonReentrant onlyProtocolAdmins whenLossNotRecognized
    {
        require(useVirtualUnderlyingBalance_ != useVirtualUnderlyingBalance, "MAV3S:SUVUB:NO_CHANGE");

        useVirtualUnderlyingBalance = useVirtualUnderlyingBalance_;

        emit UseVirtualUnderlyingBalanceSet(useVirtualUnderlyingBalance_);
    }

    /**************************************************************************************************************************************/
    /*** Management Functions                                                                                                           ***/
    /**************************************************************************************************************************************/

    function fundUnderlyingStrategy(
        uint256 assetsIn_,
        bytes calldata /* data_ */
    )
        external override whenNotPaused nonReentrant onlyStrategyManager whenLossNotRecognized returns (uint256 deployedAssets_)
    {
        require(assetsIn_ > 0, "MAV3S:FUS:ZERO_ASSETS");

        address aavePool_   = aavePool;
        address aaveToken_  = aaveToken;
        address fundsAsset_ = fundsAsset;

        require(IGlobalsLike(globals()).isInstanceOf("STRATEGY_VAULT", aaveToken_), "MAV3S:FUS:INVALID_STRATEGY_VAULT");

        _harvestAndWithdraw(0, address(0));

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
        external override whenNotPaused nonReentrant onlyStrategyManager whenLossNotRecognized
    {
        require(destination_ != address(0), "MAV3S:WFUS:ZERO_DESTINATION");
        require(assets_       > 0,          "MAV3S:WFUS:ZERO_ASSETS");

        _harvestAndWithdraw(assets_, destination_);

        lastRecordedTotalAssets = _currentTotalAssets(aaveToken);

        emit StrategyWithdrawal(destination_, assets_);
    }

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    function availableToWithdraw() external view override returns (uint256 availableToWithdraw_) {
        if (isLossRecognized) return 0;

        address aavePool_   = aavePool;
        address aaveToken_  = aaveToken;
        address fundsAsset_ = fundsAsset;

        if (!_isAaveReserveWithdrawable(aavePool_, fundsAsset_)) return 0;

        // @AUDIT: To confirm preferred way to query AaveV3 liquidity
        uint256 aaveLiquidity_ = useVirtualUnderlyingBalance
            ? IAavePoolLike(aavePool_).getVirtualUnderlyingBalance(fundsAsset_)
            : IERC20Like(fundsAsset_).balanceOf(aaveToken_);

        uint256 currentTotalAssets_ = _currentTotalAssets(aaveToken_);
        uint256 grossAvailable_     = currentTotalAssets_ < aaveLiquidity_ ? currentTotalAssets_ : aaveLiquidity_;

        ( uint256 delegateFee_, uint256 protocolFee_ ) = _currentAccruedFees(currentTotalAssets_);

        uint256 totalFees_ = delegateFee_ + protocolFee_;

        if (grossAvailable_ > totalFees_) availableToWithdraw_ = grossAvailable_ - totalFees_;
    }

    function assetsUnderManagement() public view override returns (uint256 assetsUnderManagement_) {
        if (isLossRecognized) return 0;

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

    function unrealizedLosses() public view override returns (uint256 unrealizedLosses_) {
        unrealizedLosses_ = _min(impairedAssets, assetsUnderManagement());
    }

    /**************************************************************************************************************************************/
    /*** Internal Functions                                                                                                             ***/
    /**************************************************************************************************************************************/

    function _harvestAndWithdraw(uint256 assets_, address destination_) internal {
        address fundsAsset_ = fundsAsset;

        ( uint256 delegateFee_, uint256 protocolFee_ ) = _currentAccruedFees(_currentTotalAssets(aaveToken));

        uint256 totalToWithdraw_ = assets_ + delegateFee_ + protocolFee_;

        if (totalToWithdraw_ != 0) IAavePoolLike(aavePool).withdraw(fundsAsset_, totalToWithdraw_, address(this));

        if (delegateFee_ != 0) {
            require(ERC20Helper.transfer(fundsAsset_, strategyDelegate(), delegateFee_), "MAV3S:HAW:DELEGATE_TRANSFER_FAIL");
        }

        if (protocolFee_ != 0) {
            require(ERC20Helper.transfer(fundsAsset_, mapleTreasury(), protocolFee_), "MAV3S:HAW:PROTOCOL_TRANSFER_FAIL");
        }

        emit StrategyFeesCollected(delegateFee_, protocolFee_);

        if (assets_ != 0 && destination_ != address(0)) {
            require(ERC20Helper.transfer(fundsAsset_, destination_, assets_), "MAV3S:HAW:ASSET_TRANSFER_FAIL");
        }
    }

    /**************************************************************************************************************************************/
    /*** Internal Helper Functions                                                                                                      ***/
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
        if (isLossRecognized) return 0;

        currentTotalAssets_ = IAaveTokenLike(aaveToken_).balanceOf(address(this));
    }

    // @AUDIT: To confirm Aave V3 and Spark validateWithdraw logic is the same
    function _isAaveReserveWithdrawable(address aavePool_, address fundsAsset_) internal view returns (bool isWithdrawable_) {
        address addressesProvider_ = IAavePoolLike(aavePool_).ADDRESSES_PROVIDER();
        address poolDataProvider_  = IAavePoolAddressesProviderLike(addressesProvider_).getPoolDataProvider();

        IAavePoolDataProviderLike poolDataProviderContract_ = IAavePoolDataProviderLike(poolDataProvider_);

        ( , , , , , , , , bool isActive_, ) = poolDataProviderContract_.getReserveConfigurationData(fundsAsset_);

        bool isPaused_ = poolDataProviderContract_.getPaused(fundsAsset_);

        isWithdrawable_ = isActive_ && !isPaused_;
    }

    function _min(uint256 x_, uint256 y_) internal pure returns (uint256 min_) {
        min_ = x_ < y_ ? x_ : y_;
    }

}
