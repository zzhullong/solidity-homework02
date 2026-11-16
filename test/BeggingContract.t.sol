// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {BeggingContract} from "../src/BeggingContract.sol";

contract BeggingContractTest is Test {
    BeggingContract begging;
    address owner;
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public {
        vm.warp(1_000_000);
        owner = address(0xB0B0);
        vm.prank(owner);
        begging = new BeggingContract(block.timestamp, block.timestamp + 7 days);
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function testDonateRecordsAmount() public {
        vm.prank(alice);
        begging.donate{value: 1 ether}();
        assertEq(begging.getDonation(alice), 1 ether);
    }

    function testDonateAccumulates() public {
        vm.startPrank(alice);
        begging.donate{value: 1 ether}();
        begging.donate{value: 2 ether}();
        vm.stopPrank();
        assertEq(begging.getDonation(alice), 3 ether);
    }

    function testDonateZeroReverts() public {
        vm.prank(alice);
        vm.expectRevert();
        begging.donate{value: 0}();
    }

    function testGetDonationUnknownReturnsZero() public view {
        assertEq(begging.getDonation(address(0xCAFE)), 0);
    }

    function testWithdrawByOwnerTransfersAll() public {
        vm.prank(alice);
        begging.donate{value: 1 ether}();
        vm.prank(bob);
        begging.donate{value: 2 ether}();

        uint256 before = owner.balance;
        vm.prank(owner);
        begging.withdraw();

        assertEq(address(begging).balance, 0);
        assertEq(owner.balance, before + 3 ether);
    }

    function testWithdrawOnlyOwnerReverts() public {
        vm.prank(alice);
        begging.donate{value: 1 ether}();

        vm.prank(alice);
        vm.expectRevert();
        begging.withdraw();
    }

    function testWithdrawEmptyBalanceReverts() public {
        vm.prank(owner);
        vm.expectRevert();
        begging.withdraw();
    }

    function testFuzzBalanceMatchesDonations(uint96 a, uint96 b) public {
        a = uint96(bound(a, 1, 5 ether));
        b = uint96(bound(b, 1, 5 ether));

        vm.prank(alice);
        begging.donate{value: a}();
        vm.prank(bob);
        begging.donate{value: b}();

        assertEq(address(begging).balance, uint256(a) + uint256(b));
        assertEq(begging.getDonation(alice), a);
        assertEq(begging.getDonation(bob), b);
    }
}
