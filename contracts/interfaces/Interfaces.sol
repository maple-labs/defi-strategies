// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IGlobalsLike {

    function canDeploy(address caller) external view returns (bool);

    function governor() external view returns (address);

    function isFunctionPaused(bytes4 signature) external view returns (bool);

    function isInstanceOf(bytes32 key, address instance) external view returns (bool);

    function isPoolAsset(address asset) external view returns (bool);

    function mapleTreasury() external view returns (address);

    function operationalAdmin() external view returns (address);

    function securityAdmin() external view returns (address);

}

interface IAaveTokenLike {

    function balanceOf(address account) external view returns (uint256 balance);

    function getIncentivesController() external view returns (address incentivesController);

    function POOL() external view returns (address pool);

    function UNDERLYING_ASSET_ADDRESS() external view returns (address asset);

}

interface IAavePoolLike {

    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    function withdraw(address asset, uint256 amount, address to) external returns (uint256 withdrawn);

}

interface IERC4626Like {

    function asset() external view returns (address);

    function balanceOf(address account) external view returns (uint256);

    function deposit(uint256 assets, address receiver, uint16 referralCode) external returns (uint256 shares);

    function previewRedeem(uint256 shares) external view returns (uint256 assets);

    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);

}

interface IPSMLike {

    function buyGem(address usr, uint256 gemAmount) external returns (uint256 usdsInWad);

    function gem() external view returns (address);

    function sellGem(address usr, uint256 gemAmount) external returns (uint256 usdsOutWad);

    function to18ConversionFactor() external view returns (uint256);

    function tout() external view returns (uint256);

    function usds() external view returns (address);

}

interface IProxyFactoryLike {

    function isInstance(address instance) external view returns (bool);

    function mapleGlobals() external view returns (address);

    function upgradeInstance(uint256 version, bytes calldata arguments) external;

}

interface IStrategyManagerLike {

    function factory() external view returns (address);

    function strategyDelegate() external view returns (address);

    function underlyingStrategy() external view returns (address);

}
