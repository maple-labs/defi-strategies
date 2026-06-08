// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MockERC20 } from "../../modules/erc20/contracts/test/mocks/MockERC20.sol";

import { MapleAaveV3StrategyStorage } from "../../contracts/aaveV3/MapleAaveV3StrategyStorage.sol";

import { MapleSkyStrategyStorage } from "../../contracts/sky/MapleSkyStrategyStorage.sol";

contract MockAsset is MockERC20("Asset", "A", 6) {

    mapping(address spender => bool approveReverts) public approveReverts;

    bool transferReverts;
    bool transferFromReverts;

    function __setApproveReverts(address spender_, bool approveReverts_) external {
        approveReverts[spender_] = approveReverts_;
    }

    function __setTransferReverts(bool transferReverts_) external {
        transferReverts = transferReverts_;
    }

    function __setTransferFromReverts(bool transferFromReverts_) external {
        transferFromReverts = transferFromReverts_;
    }

    function approve(address spender_, uint256 amount_) public override returns (bool success_) {
        require(!approveReverts[spender_]);

        success_ = super.approve(spender_, amount_);
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

contract MockAaveToken {

    address public incentivesController;
    address public POOL;
    address public UNDERLYING_ASSET_ADDRESS;

    mapping(address account => uint256 balance) public balanceOf;

    function __setIncentivesController(address incentivesController_) external {
        incentivesController = incentivesController_;
    }

    function __setPool(address pool_) external {
        POOL = pool_;
    }

    function __setUnderlyingAsset(address underlyingAsset_) external {
        UNDERLYING_ASSET_ADDRESS = underlyingAsset_;
    }

    function __setBalanceOf(address account_, uint256 balance_) external {
        balanceOf[account_] = balance_;
    }

    function burn(address account_, uint256 amount_) external {
        require(balanceOf[account_] >= amount_, "MOCK_AAVE_TOKEN:BURN:INSUFFICIENT_BALANCE");

        balanceOf[account_] -= amount_;
    }

    function getIncentivesController() external view returns (address incentivesController_) {
        incentivesController_ = incentivesController;
    }

    function mint(address account_, uint256 amount_) external {
        balanceOf[account_] += amount_;
    }

}

contract MockAaveRewardsController {

    uint256 public rewardAmount;

    function __setRewardAmount(uint256 rewardAmount_) external {
        rewardAmount = rewardAmount_;
    }

    function claimRewards(address[] calldata, uint256, address to_, address rewardToken_) external returns (uint256 rewardAmount_) {
        rewardAmount_ = rewardAmount;

        MockERC20(rewardToken_).mint(to_, rewardAmount_);
    }

}

contract MockAavePool {

    address public aaveToken;

    mapping(address => uint128) public virtualUnderlyingBalance;

    function __setAaveToken(address aaveToken_) external {
        aaveToken = aaveToken_;
    }

    function __setATokenBalance(address asset_, address account_, uint256 aaveTokenBalance_) external {
        uint256 currentATokenBalance_ = MockAaveToken(aaveToken).balanceOf(account_);

        if (aaveTokenBalance_ > currentATokenBalance_) MockERC20(asset_).mint(aaveToken, aaveTokenBalance_ - currentATokenBalance_);
        if (aaveTokenBalance_ < currentATokenBalance_) MockERC20(asset_).burn(aaveToken, currentATokenBalance_ - aaveTokenBalance_);

        MockAaveToken(aaveToken).__setBalanceOf(account_, aaveTokenBalance_);
    }

    function __setVirtualUnderlyingBalance(address asset_, uint256 liquidity_) external {
        uint256 currentLiquidity_ = MockERC20(asset_).balanceOf(aaveToken);

        if (liquidity_ > currentLiquidity_) MockERC20(asset_).mint(aaveToken, liquidity_ - currentLiquidity_);
        if (liquidity_ < currentLiquidity_) MockERC20(asset_).burn(aaveToken, currentLiquidity_ - liquidity_);

        virtualUnderlyingBalance[asset_] = uint128(liquidity_);
    }

    function getVirtualUnderlyingBalance(address asset_) external view returns (uint128 balance_) {
        balance_ = virtualUnderlyingBalance[asset_];
    }

    function supply(address asset_, uint256 amount_, address onBehalfOf_, uint16) external {
        MockERC20(asset_).transferFrom(msg.sender, aaveToken, amount_);

        MockAaveToken(aaveToken).mint(onBehalfOf_, amount_);
    }

    function withdraw(address asset_, uint256 amount_, address to_) external returns (uint256 withdrawn_) {
        MockAaveToken(aaveToken).burn(msg.sender, amount_);

        MockERC20(asset_).burn(aaveToken, amount_);
        MockERC20(asset_).mint(to_, amount_);

        withdrawn_ = amount_;
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
    address public mapleTreasury;
    address public operationalAdmin;
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

    function __setMapleTreasury(address mapleTreasury_) external {
        mapleTreasury = mapleTreasury_;
    }

    function __setOperationalAdmin(address operationalAdmin_) external {
        operationalAdmin = operationalAdmin_;
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
    address public strategyDelegate;
    address public underlyingStrategy;

    function __setFactory(address factory_) external {
        factory = factory_;
    }

    function __setStrategyDelegate(address strategyDelegate_) external {
        strategyDelegate = strategyDelegate_;
    }

    function __setUnderlyingStrategy(address underlyingStrategy_) external {
        underlyingStrategy = underlyingStrategy_;
    }

}

contract MockPsm {

    address public gem;
    address public usds;

    uint256 public tout;
    uint256 public to18ConversionFactor;

    uint256 public usdsDepositExchangeRate;
    uint256 public usdsRedeemExchangeRate;

    function __setGem(address gem_) external {
        gem = gem_;
    }

    function __setTo18ConversionFactor(uint256 to18ConversionFactor_) external {
        to18ConversionFactor = to18ConversionFactor_;
    }

    function __setTout(uint256 tout_) external {
        tout = tout_;
    }

    function __setUsds(address usds_) external {
        usds = usds_;
    }

    function __setUsdsDepositExchangeRate(uint256 rate_) external {
        usdsDepositExchangeRate = rate_;
    }

    function __setUsdsRedeemExchangeRate(uint256 rate_) external {
        usdsRedeemExchangeRate = rate_;
    }

    function buyGem(address usr_, uint256 gemAmount_) external returns (uint256 usdsIn_) {
        usdsIn_ = gemAmount_ * to18ConversionFactor * usdsRedeemExchangeRate / 1e18;

        MockERC20(usds).transferFrom(msg.sender, address(this), usdsIn_);
        MockERC20(gem).mint(usr_, gemAmount_);
    }

    function sellGem(address usr_, uint256 gemAmount_) external returns (uint256 usdsOut_) {
        usdsOut_ = gemAmount_ * to18ConversionFactor * usdsDepositExchangeRate / 1e18;

        MockERC20(gem).transferFrom(msg.sender, address(this), gemAmount_);
        MockERC20(usds).mint(usr_, usdsOut_);
    }

}

contract MockSavingsUsds {

    address public asset;

    uint256 public susdsDepositExchangeRate;
    uint256 public susdsRedeemExchangeRate;

    mapping(address account => uint256 balance) public balanceOf;

    function __setAsset(address asset_) external {
        asset = asset_;
    }

    function __setBalanceOf(address account_, uint256 balance_) external {
        balanceOf[account_] = balance_;
    }

    function __setSusdsDepositExchangeRate(uint256 rate_) external {
        susdsDepositExchangeRate = rate_;
    }

    function __setSusdsRedeemExchangeRate(uint256 rate_) external {
        susdsRedeemExchangeRate = rate_;
    }

    function transfer(address to_, uint256 shares_) external returns (bool success_) {
        balanceOf[msg.sender] -= shares_;
        balanceOf[to_]        += shares_;

        success_ = true;
    }

    function deposit(uint256 assets_, address receiver_, uint16) external returns (uint256 shares_) {
        shares_ = assets_ * susdsDepositExchangeRate / 1e18;
        balanceOf[receiver_] += shares_;

        MockERC20(asset).transferFrom(msg.sender, address(this), assets_);
    }

    function previewRedeem(uint256 shares_) external view returns (uint256 assets_) {
        assets_ = shares_ * susdsRedeemExchangeRate / 1e18;
    }

    function withdraw(uint256 assets_, address receiver_, address owner_) external returns (uint256 shares_) {
        shares_ = assets_ * 1e18 / susdsRedeemExchangeRate;
        balanceOf[owner_] -= shares_;

        MockERC20(asset).transfer(receiver_, assets_);
    }

}

contract MockMigrator is MapleSkyStrategyStorage {

    fallback() external {
        strategyManager = abi.decode(msg.data, (address));
    }

}

contract MockAaveV3Migrator is MapleAaveV3StrategyStorage {

    fallback() external {
        strategyManager = abi.decode(msg.data, (address));
    }

}
