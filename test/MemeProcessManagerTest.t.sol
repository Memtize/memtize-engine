// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MemeCoinMinter} from "../src/MemeCoinMinter.sol";
import {MemeCoinDexer} from "../src/MemeCoinDexer.sol";
import {MemeProcessManager} from "../src/MemeProcessManager.sol";
import {InvalidRecipient} from "../test/mocks/InvalidRecipient.sol";
import {DeployMCM} from "../script/DeployMCM.s.sol";
import {DeployMCD} from "../script/DeployMCD.s.sol";
import {DeployMPM} from "../script/DeployMPM.s.sol";

contract MemeProcessManagerTest is Test {
    event MemeCreated(uint indexed id, address indexed creator, string name, string symbol);
    event MemeFunded(uint indexed id, uint indexed value);
    event RefundPerformed(address indexed funder, uint indexed amount);
    event MemeKilled(uint indexed id);
    event MemeHyped(uint indexed id);
    event TransferSuccessfull(uint indexed amount);
    event MemesProcessed(bool indexed performed);

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
    address private USER_TWO = makeAddr("user_two");
    address private USER_THREE = makeAddr("user_three");
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
        deal(USER_TWO, STARTING_BALANCE);
        deal(USER_THREE, STARTING_BALANCE);
    }

    function test_Constructor() public {}

    function test_CreateMeme() public skipFork {
        vm.expectEmit(true, true, true, true, address(memeProcessManager));
        emit MemeCreated(0, USER, "Hexur The Memer", "HEX");
        vm.prank(USER);
        memeProcessManager.createMeme("Hexur The Memer", "HEX");

        vm.expectEmit(true, true, true, true, address(memeProcessManager));
        emit MemeCreated(1, OWNER, "Hastur User Fool", "HUF");
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
        assertEq(timeLeft, block.timestamp + 30 days);
        assertEq(totalFunds, 0);
        assertEq(funders.length, 0);
        assertEq(funds.length, 0);
        assert(status == MemeProcessManager.MemeStatus.ALIVE);

        (creator, name, symbol, timeLeft, totalFunds, funders, funds, status) = memeProcessManager.getMemeData(1);

        assertEq(creator, OWNER);
        assertEq(name, "Hastur User Fool");
        assertEq(symbol, "HUF");
        assertEq(timeLeft, block.timestamp + 30 days);
        assertEq(totalFunds, 0);
        assertEq(funders.length, 0);
        assertEq(funds.length, 0);
        assert(status == MemeProcessManager.MemeStatus.ALIVE);

        vm.expectRevert(MemeProcessManager.MPM__InvalidMeme.selector);
        (creator, name, symbol, timeLeft, totalFunds, funders, funds, status) = memeProcessManager.getMemeData(2);

        uint[] memory unprocessedMemes = memeProcessManager.getUnprocessedMemes();
        assertEq(unprocessedMemes[0], 0);
        assertEq(unprocessedMemes[1], 1);
    }

    function test_FundMeme() public skipFork {
        memeProcessManager.createMeme("Hexur The Memer", "HEX");

        vm.expectRevert(MemeProcessManager.MPM__ZeroAmount.selector);
        vm.prank(USER);
        memeProcessManager.fundMeme{value: 0}(0);

        vm.expectRevert(MemeProcessManager.MPM__InvalidMeme.selector);
        vm.prank(USER);
        memeProcessManager.fundMeme{value: 1 ether}(1);

        vm.expectEmit(true, true, true, true, address(memeProcessManager));
        emit MemeFunded(0, 1 ether);
        vm.prank(USER);
        memeProcessManager.fundMeme{value: 1 ether}(0);

        vm.expectEmit(true, true, true, true, address(memeProcessManager));
        emit MemeFunded(0, 3 ether);
        vm.prank(OWNER);
        memeProcessManager.fundMeme{value: 3 ether}(0);

        (, , , , uint totalFunds, address[] memory funders, uint[] memory funds, ) = memeProcessManager.getMemeData(0);

        assertEq(totalFunds, 4 ether);
        assertEq(funders[0], USER);
        assertEq(funders[1], OWNER);
        assertEq(funds[0], 1 ether);
        assertEq(funds[1], 3 ether);
    }

    function test_Refund() public skipFork {
        vm.expectRevert(MemeProcessManager.MPM__NothingToRefund.selector);
        memeProcessManager.refund();

        memeProcessManager.createMeme("Hexur The Memer", "HEX");

        vm.prank(USER);
        memeProcessManager.fundMeme{value: 1 ether}(0);

        vm.expectRevert(MemeProcessManager.MPM__NothingToRefund.selector);
        memeProcessManager.refund();
    }

    function test_CheckUpkeepIsFalse() public skipFork {
        bool upkeepNeeded;

        (upkeepNeeded, ) = memeProcessManager.checkUpkeep("");
        assertEq(upkeepNeeded, false);

        vm.warp(block.timestamp + 300);
        vm.roll(block.number + 1);

        (upkeepNeeded, ) = memeProcessManager.checkUpkeep("");
        assertEq(upkeepNeeded, false);
    }

    function test_CheckUpkeepIsTrue() public skipFork {
        memeProcessManager.createMeme("Hexur The Memer", "HEX");

        bool upkeepNeeded;

        (upkeepNeeded, ) = memeProcessManager.checkUpkeep("");
        assertEq(upkeepNeeded, false);

        vm.warp(block.timestamp + 32);
        vm.roll(block.number + 1);

        (upkeepNeeded, ) = memeProcessManager.checkUpkeep("");
        assertEq(upkeepNeeded, true);
    }

    function test_CantPerformUpkeep() public skipFork {
        vm.expectRevert(MemeProcessManager.MPM__UpkeepNotNeeded.selector);
        memeProcessManager.performUpkeep("");
    }

    function test_CanKillMeme() public skipFork {
        memeProcessManager.createMeme("Hexur The Memer", "HEX");
        memeProcessManager.createMeme("Osteo Pedro", "PDR");
        memeProcessManager.createMeme("Joke Joker", "JOK");

        vm.prank(USER);
        memeProcessManager.fundMeme{value: 0.44 ether}(0);

        vm.prank(OWNER);
        memeProcessManager.fundMeme{value: 0.55 ether}(0);

        uint firstTimeStamp = memeProcessManager.getLastTimeStamp();

        vm.warp(block.timestamp + 30 days + 1);
        vm.roll(block.number + 1);

        vm.expectEmit(true, true, true, true, address(memeProcessManager));
        emit MemeKilled(0);
        memeProcessManager.performUpkeep("");

        MemeProcessManager.MemeStatus status;

        (, , , , , , , status) = memeProcessManager.getMemeData(0);
        assert(status == MemeProcessManager.MemeStatus.DEAD);

        (, , , , , , , status) = memeProcessManager.getMemeData(1);
        assert(status == MemeProcessManager.MemeStatus.DEAD);

        (, , , , , , , status) = memeProcessManager.getMemeData(2);
        assert(status == MemeProcessManager.MemeStatus.DEAD);

        uint[] memory unprocessedMemes = memeProcessManager.getUnprocessedMemes();
        assertEq(unprocessedMemes.length, 0);

        uint lastTimeStamp = memeProcessManager.getLastTimeStamp();
        assertEq(block.timestamp, lastTimeStamp);
        assert(firstTimeStamp < lastTimeStamp);

        vm.prank(USER);
        vm.expectRevert(MemeProcessManager.MPM__MemeDead.selector);
        memeProcessManager.fundMeme{value: 0.55 ether}(1);
    }

    function test_CanRefund() public skipFork {
        vm.prank(USER_THREE);
        memeProcessManager.createMeme("Hexur The Memer", "HEX");

        vm.prank(OWNER);
        memeProcessManager.fundMeme{value: 0.55 ether}(0);

        vm.prank(USER);
        memeProcessManager.fundMeme{value: 0.44 ether}(0);

        uint ownerBalance = OWNER.balance;
        uint userBalance = USER.balance;

        vm.warp(block.timestamp + 30 days + 1);
        vm.roll(block.number + 1);

        memeProcessManager.performUpkeep("");

        vm.expectEmit(true, true, true, true, address(memeProcessManager));
        emit RefundPerformed(OWNER, 0.55 ether);
        vm.prank(OWNER);
        memeProcessManager.refund();

        vm.prank(USER);
        memeProcessManager.refund();

        assertEq(OWNER.balance, ownerBalance + 0.55 ether);
        assertEq(USER.balance, userBalance + 0.44 ether);
    }

    function test_CantRefundToInvalidRecipient() public skipFork {
        vm.prank(USER_TWO);
        memeProcessManager.createMeme("Hexur The Memer", "HEX");

        InvalidRecipient invalidRecipient = new InvalidRecipient();
        deal(address(invalidRecipient), STARTING_BALANCE);

        vm.prank(address(invalidRecipient));
        memeProcessManager.fundMeme{value: 0.55 ether}(0);

        vm.warp(block.timestamp + 30 days + 1);
        vm.roll(block.number + 1);

        memeProcessManager.performUpkeep("");

        vm.prank(address(invalidRecipient));
        vm.expectRevert(MemeProcessManager.MPM__TransferFailed.selector);
        memeProcessManager.refund();

        uint invalidRecipientBalance = memeProcessManager.getFunderToFunds(address(invalidRecipient));
        assertEq(invalidRecipientBalance, 0.55 ether);
    }

    modifier skipFork() {
        /// @dev Comment below 'if' statement line to perform full coverage test with command 'make testForkSepoliaCoverage'
        // if (block.chainid != 31337) return;

        _;
    }
}
