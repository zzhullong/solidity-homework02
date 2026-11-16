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

    function testDonateBeforeStartReverts() public {
        vm.warp(begging.startTime() - 1);
        vm.prank(alice);
        vm.expectRevert();
        begging.donate{value: 1 ether}();
    }

    function testDonateAtStartSucceeds() public {
        vm.warp(begging.startTime());
        vm.prank(alice);
        begging.donate{value: 1 ether}();
        assertEq(begging.getDonation(alice), 1 ether);
    }

    function testDonateAtEndSucceeds() public {
        vm.warp(begging.endTime());
        vm.prank(alice);
        begging.donate{value: 1 ether}();
        assertEq(begging.getDonation(alice), 1 ether);
    }

    function testDonateAfterEndReverts() public {
        vm.warp(begging.endTime() + 1);
        vm.prank(alice);
        vm.expectRevert();
        begging.donate{value: 1 ether}();
    }

    function testConstructorRejectsInvalidWindow() public {
        vm.expectRevert();
        new BeggingContract(100, 100);
    }

    function testFuzzRepeatedDonationsKeepAccounting(uint96 a1, uint96 a2, uint96 a3, uint96 a4, uint96 a5) public {
        a1 = uint96(bound(a1, 1, 2 ether));
        a2 = uint96(bound(a2, 1, 2 ether));
        a3 = uint96(bound(a3, 1, 2 ether));
        a4 = uint96(bound(a4, 1, 2 ether));
        a5 = uint96(bound(a5, 1, 2 ether));

        address carol = address(0xCA201);
        vm.deal(carol, 10 ether);

        vm.prank(alice);
        begging.donate{value: a1}();
        vm.prank(bob);
        begging.donate{value: a2}();
        vm.prank(alice);
        begging.donate{value: a3}();
        vm.prank(carol);
        begging.donate{value: a4}();
        vm.prank(alice);
        begging.donate{value: a5}();

        assertEq(begging.getDonation(alice), uint256(a1) + uint256(a3) + uint256(a5));
        assertEq(begging.getDonation(bob), a2);
        assertEq(begging.getDonation(carol), a4);
        assertEq(address(begging).balance, uint256(a1) + uint256(a2) + uint256(a3) + uint256(a4) + uint256(a5));
    }

    function testTopDonorsRepeatDonorAppearsOnce() public {
        vm.prank(alice);
        begging.donate{value: 1 ether}();
        vm.prank(alice);
        begging.donate{value: 4 ether}();
        vm.prank(bob);
        begging.donate{value: 3 ether}();

        (address[] memory addrs, uint256[] memory amounts) = begging.getTopDonors();
        assertEq(addrs, only2(alice, bob));
        assertEq(amounts, only2(5 ether, 3 ether));
    }

    function testTopDonorsLaterDonationChangesRank() public {
        address carol = address(0xCA201);
        address dave = address(0xDA7E);
        vm.deal(alice, 20 ether);
        vm.deal(carol, 10 ether);
        vm.deal(dave, 10 ether);

        vm.prank(alice);
        begging.donate{value: 2 ether}();
        vm.prank(bob);
        begging.donate{value: 3 ether}();
        vm.prank(carol);
        begging.donate{value: 5 ether}();
        vm.prank(dave);
        begging.donate{value: 4 ether}();

        (address[] memory beforeAddrs,) = begging.getTopDonors();
        assertEq(beforeAddrs, only3(carol, dave, bob));

        vm.prank(alice);
        begging.donate{value: 10 ether}();

        (address[] memory afterAddrs, uint256[] memory afterAmounts) = begging.getTopDonors();
        assertEq(afterAddrs, only3(alice, carol, dave));
        assertEq(afterAmounts, only3(12 ether, 5 ether, 4 ether));
    }

    function testWithdrawKeepsDonationRecords() public {
        vm.prank(alice);
        begging.donate{value: 1 ether}();

        vm.prank(owner);
        begging.withdraw();

        assertEq(begging.getDonation(alice), 1 ether);
        assertEq(address(begging).balance, 0);
    }

    function testSecondWithdrawReverts() public {
        vm.prank(alice);
        begging.donate{value: 1 ether}();
        vm.prank(owner);
        begging.withdraw();

        vm.prank(owner);
        vm.expectRevert();
        begging.withdraw();
    }
}
