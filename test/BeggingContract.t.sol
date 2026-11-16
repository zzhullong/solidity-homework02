// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {BeggingContract} from "../src/BeggingContract.sol";

contract BeggingContractTest is Test {
    BeggingContract begging;
    address owner;
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    /// @dev 固定时间戳并部署合约；owner 使用 EOA 地址，贴近真实 MetaMask 部署场景
    function setUp() public {
        vm.warp(1_000_000);
        owner = address(0xB0B0);
        vm.prank(owner);
        begging = new BeggingContract(block.timestamp, block.timestamp + 7 days);
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    // ---------- 基础记账 ----------

    /// @dev 单次捐赠后金额记录正确
    function testDonateRecordsAmount() public {
        vm.prank(alice);
        begging.donate{value: 1 ether}();
        assertEq(begging.getDonation(alice), 1 ether);
    }

    /// @dev 同一地址多次捐赠金额累加
    function testDonateAccumulates() public {
        vm.startPrank(alice);
        begging.donate{value: 1 ether}();
        begging.donate{value: 2 ether}();
        vm.stopPrank();
        assertEq(begging.getDonation(alice), 3 ether);
    }

    /// @dev 捐赠 0 必须回滚，避免污染 donors 列表
    function testDonateZeroReverts() public {
        vm.prank(alice);
        vm.expectRevert("zero donation");
        begging.donate{value: 0}();
    }

    /// @dev 未捐赠过的地址查询结果为 0
    function testGetDonationUnknownReturnsZero() public view {
        assertEq(begging.getDonation(address(0xCAFE)), 0);
    }

    // ---------- 提现与权限 ----------

    /// @dev owner 提现后合约余额归零，owner 收到全部捐赠
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

    /// @dev 非 owner 提现必须回滚
    function testWithdrawOnlyOwnerReverts() public {
        vm.prank(alice);
        begging.donate{value: 1 ether}();

        vm.prank(alice);
        vm.expectRevert("not owner");
        begging.withdraw();
    }

    /// @dev 合约余额为 0 时提现必须回滚
    function testWithdrawEmptyBalanceReverts() public {
        vm.prank(owner);
        vm.expectRevert("nothing to withdraw");
        begging.withdraw();
    }

    /// @dev 提现不会清除链上捐赠记录
    function testWithdrawKeepsDonationRecords() public {
        vm.prank(alice);
        begging.donate{value: 1 ether}();

        vm.prank(owner);
        begging.withdraw();

        assertEq(begging.getDonation(alice), 1 ether);
        assertEq(address(begging).balance, 0);
    }

    /// @dev 余额已提空后再次提现必须回滚
    function testSecondWithdrawReverts() public {
        vm.prank(alice);
        begging.donate{value: 1 ether}();
        vm.prank(owner);
        begging.withdraw();

        vm.prank(owner);
        vm.expectRevert("nothing to withdraw");
        begging.withdraw();
    }

    // ---------- 事件 ----------

    /// @dev 捐赠时触发 Donation(donor, amount)
    function testDonationEvent() public {
        vm.expectEmit(true, false, false, true, address(begging));
        emit BeggingContract.Donation(alice, 1 ether);
        vm.prank(alice);
        begging.donate{value: 1 ether}();
    }

    /// @dev 提现时触发 Withdrawal(owner, amount)
    function testWithdrawalEvent() public {
        vm.prank(alice);
        begging.donate{value: 1 ether}();

        vm.expectEmit(true, false, false, true, address(begging));
        emit BeggingContract.Withdrawal(owner, 1 ether);
        vm.prank(owner);
        begging.withdraw();
    }

    // ---------- Top3 排行榜 ----------

    /// @dev 无人捐赠时返回两个空数组
    function testTopDonorsEmpty() public view {
        (address[] memory addrs, uint256[] memory amounts) = begging.getTopDonors();
        assertEq(addrs.length, 0);
        assertEq(amounts.length, 0);
    }

    /// @dev 不足 3 人时按实际人数返回，保持降序
    function testTopDonorsFewerThanThree() public {
        vm.prank(alice);
        begging.donate{value: 2 ether}();
        vm.prank(bob);
        begging.donate{value: 1 ether}();

        (address[] memory addrs, uint256[] memory amounts) = begging.getTopDonors();
        assertEq(addrs, only2(alice, bob));
        assertEq(amounts, only2(2 ether, 1 ether));
    }

    /// @dev 4 人乱序捐赠时只返回金额最高的 3 人并按降序排列
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

    /// @dev 金额相同时先捐赠者排前
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

    /// @dev 同一地址多次捐赠只出现一次，金额为累计值
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

    /// @dev 后续追加捐赠可以把捐赠者从榜外顶到第一，并挤掉原末位
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

    // ---------- 时间窗口（闭区间） ----------

    /// @dev 开始前一秒捐赠必须回滚
    function testDonateBeforeStartReverts() public {
        vm.warp(begging.startTime() - 1);
        vm.prank(alice);
        vm.expectRevert("donation window closed");
        begging.donate{value: 1 ether}();
    }

    /// @dev 恰好处于开始时刻可以捐赠
    function testDonateAtStartSucceeds() public {
        vm.warp(begging.startTime());
        vm.prank(alice);
        begging.donate{value: 1 ether}();
        assertEq(begging.getDonation(alice), 1 ether);
    }

    /// @dev 恰好处于结束时刻仍可以捐赠
    function testDonateAtEndSucceeds() public {
        vm.warp(begging.endTime());
        vm.prank(alice);
        begging.donate{value: 1 ether}();
        assertEq(begging.getDonation(alice), 1 ether);
    }

    /// @dev 结束后一秒捐赠必须回滚
    function testDonateAfterEndReverts() public {
        vm.warp(begging.endTime() + 1);
        vm.prank(alice);
        vm.expectRevert("donation window closed");
        begging.donate{value: 1 ether}();
    }

    // ---------- 构造函数校验 ----------

    /// @dev start >= end 的非法窗口必须回滚
    function testConstructorRejectsInvalidWindow() public {
        vm.expectRevert("invalid window");
        new BeggingContract(100, 100);
    }

    /// @dev 结束时间已过去的窗口必须回滚，避免部署出永远无法捐赠的合约
    function testConstructorRejectsPastEnd() public {
        vm.warp(1_000_000);
        vm.expectRevert("window already ended");
        new BeggingContract(1_000_000 - 2 days, 1_000_000 - 1 days);
    }

    // ---------- 综合 fuzz ----------

    /// @dev fuzz：5 次捐赠（含重复地址）后，各地址记录与合约余额都等于对应金额之和
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

    /// @dev fuzz：两个地址各捐赠一次后，余额为两者之和且各自记录正确
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

    // ---------- 测试辅助函数 ----------

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
