// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {MemeCoinDexer} from "../src/MemeCoinDexer.sol";
import {MemeCoinMinter} from "../src/MemeCoinMinter.sol";
import {MemeProcessManager} from "../src/MemeProcessManager.sol";

/// @dev Deploys Memtize Project
contract DeployMemtize is Script {
    uint private constant INTERVAL = 30;

    function run() external returns (MemeCoinMinter, MemeCoinDexer, MemeProcessManager) {
        HelperConfig helperConfig = new HelperConfig();
        (address nftPositionManager, address wrappedNativeToken, , uint256 deployerKey) = helperConfig.activeNetworkConfig();

        vm.startBroadcast(deployerKey);
        /// @dev Deploying MemeCoinMinter
        MemeCoinMinter memeCoinMinter = new MemeCoinMinter();
        console.log("Deployed Meme Coin Minter:", address(memeCoinMinter));
        console.log("Owner: ", memeCoinMinter.owner());

        /// @dev Deploying MemeCoinDexer
        MemeCoinDexer memeCoinDexer = new MemeCoinDexer(address(memeCoinMinter), nftPositionManager, wrappedNativeToken);
        console.log("Deployed Meme Coin Dexer:", address(memeCoinDexer));
        console.log("Owner: ", memeCoinDexer.owner());

        /// @dev Deploying MemeProcessManager
        MemeProcessManager memeProcessManager = new MemeProcessManager(address(memeCoinMinter), address(memeCoinDexer), INTERVAL);
        console.log("Deployed Meme Process Manager:", address(memeProcessManager));
        console.log("Owner: ", memeProcessManager.owner());

        /// @dev Transferring ownership of MemeCoinMinter to MemeProcessManager
        memeCoinMinter.transferOwnership(address(memeProcessManager));
        console.log("Ownership of MemeCoinMinter transferred successfully to MemeProcessManager");
        vm.stopBroadcast();

        return (memeCoinMinter, memeCoinDexer, memeProcessManager);
    }
}
