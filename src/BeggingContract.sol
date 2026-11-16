// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract BeggingContract {
    address public immutable owner;
    uint256 public immutable startTime;
    uint256 public immutable endTime;

    mapping(address => uint256) private donations;
    address[] private donors;

    event Donation(address indexed donor, uint256 amount);
    event Withdrawal(address indexed owner, uint256 amount);

    constructor(uint256 _startTime, uint256 _endTime) {
        require(_startTime < _endTime, "invalid window");
        require(_endTime > block.timestamp, "window already ended");
        owner = msg.sender;
        startTime = _startTime;
        endTime = _endTime;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier onlyDuringDonationWindow() {
        require(block.timestamp >= startTime && block.timestamp <= endTime, "donation window closed");
        _;
    }

    function donate() external payable onlyDuringDonationWindow {
        require(msg.value > 0, "zero donation");
        if (donations[msg.sender] == 0) {
            donors.push(msg.sender);
        }
        donations[msg.sender] += msg.value;
        emit Donation(msg.sender, msg.value);
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "nothing to withdraw");
        emit Withdrawal(owner, balance);
        payable(owner).transfer(balance);
    }

    function getDonation(address donor) external view returns (uint256) {
        return donations[donor];
    }

    function getTopDonors() external view returns (address[] memory topAddresses, uint256[] memory topAmounts) {
        uint256 count = donors.length < 3 ? donors.length : 3;
        topAddresses = new address[](count);
        topAmounts = new uint256[](count);

        uint256 filled = 0;
        for (uint256 i; i < donors.length; ++i) {
            address donor = donors[i];
            uint256 amount = donations[donor];

            uint256 pos = 0;
            while (pos < filled && topAmounts[pos] >= amount) {
                ++pos;
            }
            if (pos < 3) {
                uint256 limit = filled < 3 ? filled : 2;
                for (uint256 j = limit; j > pos; --j) {
                    topAddresses[j] = topAddresses[j - 1];
                    topAmounts[j] = topAmounts[j - 1];
                }
                topAddresses[pos] = donor;
                topAmounts[pos] = amount;
                if (filled < 3) {
                    ++filled;
                }
            }
        }
    }
}
