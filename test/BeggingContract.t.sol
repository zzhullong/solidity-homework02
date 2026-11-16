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

    function testDonationEvent() public {
        vm.expectEmit(true, false, false, true, address(begging));
        emit BeggingContract.Donation(alice, 1 ether);
        vm.prank(alice);
        begging.donate{value: 1 ether}();
    }

    function testWithdrawalEvent() public {
        vm.prank(alice);
        begging.donate{value: 1 ether}();

        vm.expectEmit(true, false, false, true, address(begging));
        emit BeggingContract.Withdrawal(owner, 1 ether);
        vm.prank(owner);
        begging.withdraw();
    }

    function testTopDonorsEmpty() public view {
        (address[] memory addrs, uint256[] memory amounts) = begging.getTopDonors();
        assertEq(addrs.length, 0);
        assertEq(amounts.length, 0);
    }

    function testTopDonorsFewerThanThree() public {
        vm.prank(alice);
        begging.donate{value: 2 ether}();
        vm.prank(bob);
        begging.donate{value: 1 ether}();

        (address[] memory addrs, uint256[] memory amounts) = begging.getTopDonors();
        assertEq(addrs, only2(alice, bob));
        assertEq(amounts, only2(2 ether, 1 ether));
    }

    function testTopDonorsSortedDescending() public {
        address carol = address(0xCA201);
        address dave = address(0xDA7E);
        vm.deal(carol, 10 ether);
        vm.deal(dave, 10 ether);

        vm.prank(alice);
        begging.donate{value: 1 ether}();
        vm.prank(bob);
        begging.donate{value: 5 ether}();
        vm.prank(carol);
        begging.donate{value: 3 ether}();
        vm.prank(dave);
        begging.donate{value: 4 ether}();

        (address[] memory addrs, uint256[] memory amounts) = begging.getTopDonors();
        assertEq(addrs, only3(bob, dave, carol));
        assertEq(amounts, only3(5 ether, 4 ether, 3 ether));
    }

    function testTopDonorsTieKeepsEarlierFirst() public {
        address carol = address(0xCA201);
        vm.deal(carol, 10 ether);

        vm.prank(alice);
        begging.donate{value: 1 ether}();
        vm.prank(bob);
        begging.donate{value: 1 ether}();
        vm.prank(carol);
        begging.donate{value: 1 ether}();

        (address[] memory addrs, uint256[] memory amounts) = begging.getTopDonors();
        assertEq(addrs, only3(alice, bob, carol));
        assertEq(amounts, only3(1 ether, 1 ether, 1 ether));
    }

    function only2(address a, address b) private pure returns (address[] memory r) {
        r = new address[](2);
        (r[0], r[1]) = (a, b);
    }

    function only2(uint256 a, uint256 b) private pure returns (uint256[] memory r) {
        r = new uint256[](2);
        (r[0], r[1]) = (a, b);
    }

    function only3(address a, address b, address c) private pure returns (address[] memory r) {
        r = new address[](3);
        (r[0], r[1], r[2]) = (a, b, c);
    }

    function only3(uint256 a, uint256 b, uint256 c) private pure returns (uint256[] memory r) {
        r = new uint256[](3);
        (r[0], r[1], r[2]) = (a, b, c);
    }
}
