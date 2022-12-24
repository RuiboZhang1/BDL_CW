// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

/**
    Game Process

    1. Player Registration
    - player A call RegisterPlayerA(), sending a hashvalue of the secretNumber
    - player B call RegisterPlayerB(), sending a hashvalue of the secretNumber
    2. Deposit
    - player need to deposit the money to the game balance. The value of deposit should larger than the gas fee.
    3. Roll Dice
    - player A call StartRoll(), with the secretNumber as a proof of authentication.
    - player B call StartRoll(), with the secretNumber as a proof of authentication.
    - The balance for both players should greater than 3 eth.
    4. reset and restart the game
    - reset the dice without withdrowing the money
    5. reset and withdrowing the money
    - reset the dice with withdrowing the money


*/

contract DiceRoll {
    mapping(address => uint256) balance;
    mapping(address => bytes32) commitment;
    mapping(address => uint256) randomNumber;

    address playerA;
    address playerB;
    uint256 dice = 0;

    event Registration(address player);
    event Deposit(address player, string message);
    event Roll(uint256 dice);
    

    function registerPlayerA(bytes32 hashvalue) public {
        require(hashvalue != 0, "please enter your commitment");
        require(playerA == address(0), "Player A has been registered");
        require(playerB != msg.sender, "You has been registered as player B");

        playerA = msg.sender;
        commitment[msg.sender] = hashvalue;
        emit Registration(msg.sender);
    }

    function registerPlayerB(bytes32 hashvalue) public {
        require(hashvalue != 0, "please enter your commitment");
        require(playerB == address(0), "Player B has been registered");
        require(playerA != msg.sender, "You has been registered as player A");

        playerB = msg.sender;
        commitment[msg.sender] = hashvalue;
        emit Registration(msg.sender);
    }

    // players deposit their money to start the game
    function deposit(string memory message) public payable {
        require(playerA == msg.sender || playerB == msg.sender, "You are not registered as a player");
        
        balance[msg.sender] += msg.value;
        emit Deposit(msg.sender, message);
    }

    function roll(uint256 secretNumber) public returns (uint256) {
        require(balance[msg.sender] > 3 ether, "You must have at least 3 eth to start the game");
        require(commitment[msg.sender] == getSecretHash(secretNumber), "Wrong secretNumber");
        require(playerA != address(0), "PlayerA not registered");
        require(playerB != address(0), "PlayerB not registered");

        require(dice == 0, "Game cannot start until all players reset");

        // store the secretNumber for generating random Dice value later
        randomNumber[msg.sender] = secretNumber;
        
        // rolling will not start until two players confirm
        if(randomNumber[playerA] == 0 || randomNumber[playerB] == 0) {
            return 0;
        }

        // roll the dice using hash function
        dice = 1 + uint256(keccak256(abi.encodePacked(randomNumber[playerA] ^ randomNumber[playerB]))) % 6;

        // Loser's deposit will be give to the winner
        if (dice < 4) {
            balance[playerA] += dice * (1 ether);
            balance[playerB] -= dice * (1 ether);
        } else {
            balance[playerA] -= (dice - 3) * (1 ether);
            balance[playerB] += (dice - 3) * (1 ether);
        }
        return dice;
    }

    function getResult() public view returns (uint256) {
        return balance[msg.sender];
    }

    function resetGame(bool withdraw) public {
        if(msg.sender == playerA){
            playerA = address(0);
            commitment[playerA] = 0;
            randomNumber[playerA] = 0;
        } else if (msg.sender == playerB){
            playerB = address(0);
            commitment[playerB] = 0;
            randomNumber[playerB] = 0;
        }

        if (playerA == address(0) && playerB == address(0)) {
            dice = 0;
        }

        if (withdraw == true) {
            uint256 value = balance[msg.sender];
            balance[msg.sender] = 0;
            payable(msg.sender).transfer(value);
        }
    }


    function getSecretHash(uint256 secretNumber) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(secretNumber));
    }
}