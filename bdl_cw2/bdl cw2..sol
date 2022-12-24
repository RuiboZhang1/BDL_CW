// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

/**
    1. enter process: 
    - A call enterA(), transfer + ciphertext
    - B call enterB(), transfer + ciphertext
    2. roll process: 
    - A call roll(), value
    - B call roll(), value -> execute roll dice
    3. result
    - A call getResult(), B call getResult()
    4. reset or reset and withdraw 
    - A call reset() / resetAndWithdraw()
    - B call reset() / resetAndWithdraw()
    5. new round of game...
 
    TODO:
    if A and B send the same value 
    emit event
*/
contract DiceGame {
    // unit
    uint256 unitETH = 1e18;
    // balance
    mapping(address => uint256) balance;
    // commitment scheme - commitment
    mapping(bytes32 => address) commitment;
    // commitment scheme - value
    mapping(address => uint256) random_value;

    address playerA;
    address playerB;

    uint256 dice = 0;

    /**
        for playerA to attend 
        ciphertext: commitment scheme - commitment
    **/
    function enterA(bytes32 ciphertext) public payable{
        // check
        require(msg.value + balance[msg.sender] >= 3e18, "value + balance must >= 3eth");
        require(ciphertext != 0, "please submit the commitment");
        require(playerA == address(0), "A has entered !");
        require(playerB != msg.sender, "you have entered as playerB !");
        // update
        playerA = msg.sender;
        commitment[ciphertext] = msg.sender;
        balance[msg.sender] += msg.value;
    }

    /**
        for playerB to attend 
        ciphertext: commitment scheme - commitment
    **/
    function enterB(bytes32 ciphertext) public payable{
        // check
        require(msg.value + balance[msg.sender] >= 3e18, "value + balance must >= 3eth");
        require(ciphertext != 0, "please submit the commitment");
        require(playerB == address(0), "B has entered !");
        require(playerA != msg.sender, "you have entered as playerA !");
        // update
        playerB = msg.sender;
        commitment[ciphertext] = msg.sender;
        balance[msg.sender] += msg.value;
    }

    /**
        roll the dice
        value: commitment scheme - value -> generate random number safely
        wait for A and B both call the function, then roll the dice.
    **/
    function roll(uint256 value) public returns (uint256){
        // check
        require(commitment[keccak256(abi.encodePacked(value))] == msg.sender, "Not found!");
        require(playerA != address(0), "wait for playerA");
        require(playerB != address(0), "wait for playerB");
        require(dice == 0, "don't repeat until all users reset");
        // update
        commitment[keccak256(abi.encodePacked(value))] = address(0);
        random_value[msg.sender] = value;
        if(random_value[playerA] == 0){
            return 0;
        }
        if(random_value[playerB] == 0){
            return 0;
        }
        // execute
        dice = 1 + uint256(keccak256(abi.encodePacked(random_value[playerA] ^ random_value[playerB]))) % 6;
        if(dice > 3){
            uint256 reward = (dice - 3)*unitETH;
            balance[playerA] -= reward;
            balance[playerB] += reward;
        }else{
            uint256 reward = dice*unitETH;
            balance[playerA] += reward;
            balance[playerB] -= reward;
        } 
        return dice;
    }

    /**
        fetch result and balance
    **/
    function getResultAndFund() public view returns (uint256) {
        return balance[msg.sender];
    }

    /**
        reset to start a new game
        wait for A and B both call the function, then reset the dice
    **/
    function reset() public {
        if(msg.sender == playerA){
            playerA = address(0);
            random_value[playerA] = 0;
        } else if (msg.sender == playerB){
            playerB = address(0);
            random_value[playerB] = 0;
        }
        if(playerA == address(0) && playerB == address(0)){
            dice = 0;
        }
    }

    /**
        reset and withdraw the balance
        which means A/B can reset and play the new game without withdrawing the balance
    **/
    function resetAndWithdraw() public {
        // update
        reset();
        uint256 b = balance[msg.sender];
        balance[msg.sender] = 0;
        // interact
        payable(msg.sender).transfer(b);
    }

    function getHash(uint256 value) public view returns (bytes32){
        return keccak256(abi.encodePacked(value));
    }
}