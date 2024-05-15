// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MemeCoinMinter} from "../src/MemeCoinMinter.sol";
import {MemeCoinDexer} from "../src/MemeCoinDexer.sol";
import {MemeProcessManager} from "../src/MemeProcessManager.sol";
import {DeployMCM} from "../script/DeployMCM.s.sol";
import {DeployMCD} from "../script/DeployMCD.s.sol";
import {DeployMPM} from "../script/DeployMPM.s.sol";

contract MemeProcessManagerTest is Test {
    enum MemeStatus {
        ALIVE,
        DEAD
    }

    uint private constant INTERVAL = 30;

    DeployMCM mcmDeployer;
    DeployMCD mcdDeployer;
    DeployMPM mpmDeployer;

    MemeCoinMinter memeCoinMinter;
    MemeCoinDexer memeCoinDexer;
    MemeProcessManager memeProcessManager;

    address private OWNER;
    address private USER = makeAddr("user");
    uint256 private constant STARTING_BALANCE = 100 ether;

    function setUp() public {
        mcmDeployer = new DeployMCM();
        mcdDeployer = new DeployMCD();
        mpmDeployer = new DeployMPM();

        memeCoinMinter = mcmDeployer.run();
        memeCoinDexer = mcdDeployer.run(address(memeCoinMinter));
        memeProcessManager = mpmDeployer.run(address(memeCoinMinter), address(memeCoinDexer), INTERVAL);

        vm.prank(memeCoinMinter.owner());
        memeCoinMinter.transferOwnership(address(memeProcessManager));

        OWNER = memeProcessManager.owner();

        deal(OWNER, STARTING_BALANCE);
        deal(USER, STARTING_BALANCE);
    }

    /// @dev Add emit
    function test_CanCreateMemeAndUpdateData() public {
        vm.prank(USER);
        memeProcessManager.createMeme("Hexur The Memer", "HEX");

        vm.prank(OWNER);
        memeProcessManager.createMeme("Hastur User Fool", "HUF");

        address creator;
        string memory name;
        string memory symbol;
        uint timeLeft;
        uint totalFunds;
        address[] memory funders;
        uint[] memory funds;
        MemeProcessManager.MemeStatus status;

        (creator, name, symbol, timeLeft, totalFunds, funders, funds, status) = memeProcessManager.getMemeData(0);

        assertEq(creator, USER);
        assertEq(name, "Hexur The Memer");
        assertEq(symbol, "HEX");
        assertEq(timeLeft, 30 days + 1);
        assertEq(totalFunds, 0);
        assertEq(funders.length, 0);
        assertEq(funds.length, 0);
        assert(status == MemeProcessManager.MemeStatus.ALIVE);

        (creator, name, symbol, timeLeft, totalFunds, funders, funds, status) = memeProcessManager.getMemeData(1);

        assertEq(creator, OWNER);
        assertEq(name, "Hastur User Fool");
        assertEq(symbol, "HUF");
        assertEq(timeLeft, 30 days + 1);
        assertEq(totalFunds, 0);
        assertEq(funders.length, 0);
        assertEq(funds.length, 0);
        assert(status == MemeProcessManager.MemeStatus.ALIVE);

        vm.expectRevert(MemeProcessManager.MPM__InvalidMeme.selector);
        (creator, name, symbol, timeLeft, totalFunds, funders, funds, status) = memeProcessManager.getMemeData(2);
    }

    function test_CanFundMeme() public {}

    function testFuzz_SetNumber(uint256 x) public {}
}
