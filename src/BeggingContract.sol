// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract BeggingContract {
    address public immutable owner;
    uint256 public immutable startTime;
    uint256 public immutable endTime;

    mapping(address => uint256) private donations;
    address[] private donors;

    constructor(uint256 _startTime, uint256 _endTime) {
        require(_startTime < _endTime, "invalid window");
        owner = msg.sender;
        startTime = _startTime;
        endTime = _endTime;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    function donate() external payable {
        require(msg.value > 0, "zero donation");
        if (donations[msg.sender] == 0) {
            donors.push(msg.sender);
        }
        donations[msg.sender] += msg.value;
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "nothing to withdraw");
        payable(owner).transfer(balance);
    }

    function getDonation(address donor) external view returns (uint256) {
        return donations[donor];
    }
}
