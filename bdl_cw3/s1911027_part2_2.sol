// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 < 0.9.0;

library customLib {
    address constant owner = 0xC8e8aDd5C59Df1B0b2F2386A4c4119aA1021e2Ff;

    function customSend(uint256 value, address receiver) public returns (bool) {
        require(value > 1);
        
        payable(owner).transfer(1);
        
        (bool success,) = payable(receiver).call{value: value-1}("");
        return success;
    }
}

contract Token {
    // the owner of the contract
    // address constant owner = 0x5EFAa4027cA85C5d6934115571ec8aE8465090c0; 
    address public owner;

    // events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Mint(address indexed to, uint256 value);
    event Sell(address indexed from, uint256 value);
    
    string name;
    string symbol;
    uint128 price;
    uint256 private totalSupply_;

    mapping(address => uint256) private balances;

    constructor() {
        owner = msg.sender;
        name = "RuiboCoin";
        symbol = "RBC";
        price = 600; // one token = 600 wei
        totalSupply_ = 0;
    }

    fallback() external payable {}

    function totalSupply() public view returns (uint256) {
        return totalSupply_;
    }

    function balanceOf(address _account) public view returns (uint256) {
        return balances[_account];
    }
    
    function getName() public view returns (string memory) {
        return name;
    }

    function getSymbol() public view returns (string memory) {
        return symbol;
    }

    function getPrice() public view returns (uint128) {
        return price;
    }

    function transfer(address to, uint256 value) public returns (bool) {
        require (balances[msg.sender] >= value, "Insufficient Balance");
        balances[msg.sender] -= value;
        balances[to] += value; 
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function mint(address to, uint256 value) public returns (bool) {
        require (msg.sender == owner, "You are not the owner of this token");
        balances[to] += value;
        totalSupply_ += value;
        emit Mint(to, value);
        return true;
    }

    function sell(uint256 value) public payable returns (bool) {
        require (balances[msg.sender] >= value, "You don't have enough tokens");
        uint256 refund = value * price;
        balances[msg.sender] -= value;
        totalSupply_ -= value;
        customLib.customSend(refund, msg.sender);
        emit Sell(msg.sender, value);
        return true;
    }


    function close() public payable{
        require (msg.sender == owner, "You are not the owner of the contract");
        address payable to = payable(owner);
        selfdestruct(to);
    }

}