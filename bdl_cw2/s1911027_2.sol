// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

/**
    Gaming Rules

    1. Create Game
    - Host input Secret Number into the getHash() function, return the hashvalue
    - Host can create a public game with the hashvalue or a private game with the guest address and the hashvalue.
    2. Join Game
    - Guest input Secret Number into the getHash() function, return the hashvalue
    - Guest join a game with the host address and the hashvalue
    3. Verification
    - Both players need to verify their identity before rolling the dice by input their secretNum to the function
    4. Roll
    - The dice value will be generated based on the hash of players' secretNum and the last modified block number
    - After rolling, the game will be reset
    
    Additional Functions
        A. Terminate Game
        - The game can be terminate without rolling the dice in 4 conditions
            1. The host can terminate the game if no guest join after 3 blocks
            2. The host can terminate the game if the guest not verified the identity after 20 blocks, and get 1 eth from the guest as compensation.
            3. The guest can terminate the game if the host not verified the identity after 20 blocks, and get 1 eth from the host as compensation.
            4. Both player can terminate the game if both player not verified the identity ater 20 blocks
        B. Withdraw
        - Players cannot withdraw until the dice rolled.
        
*/
contract DiceGame {
    // the owner of the contract
    address private owner = 0xed047bbD6CdbF009Bd7788eB93192b630baB4a5e; 

    // store the balance and the host address of the game for the player in the game.
    struct Player {
        uint256 balance;
        address hostAddress;
    }

    // store the status of a game.
    struct Game{
        address host;   // address of the creator of the game
        bytes32 hostHash; // hash value of the host secretNum
        uint256 hostSecretNumber;   // store the host secretNum for verifying the commitment and for generating dice number
        address guest;  // address of the guest player
        bytes32 guestHash; // hash value of the guest secretNum
        uint256 guestSecretNumber;  // store the guest secretNum for verifying the commitment and for generating dice number
        uint256 lastBlock; // record the last block when the Game status being modified
        bool withdrawPermit; // permisson for withdraw the deposit
    }

    // store the data for each player and each game
    mapping(address => Player) public Players;
    mapping(address => Game) public Games;


    // Host create a public game that any guest can join
    function createPublicGame(bytes32 hostHash) payable public {
        require(Players[msg.sender].hostAddress == address(0), "You already in a game");
        require(Players[msg.sender].balance + msg.value >= 3 ether, "You should have at least 3 eth to start the game");
        Game memory newGame = Game(msg.sender, hostHash, 0, address(0), 0, 0, block.number, false);
        Games[msg.sender] = newGame;
        Players[msg.sender].balance += msg.value;
        Players[msg.sender].hostAddress = msg.sender;
    }

    // Host create the game, only selected guest can join
    function createPrivateGame(address guestAddress, bytes32 hostHash) payable public{
        require(Players[msg.sender].hostAddress == address(0), "You already in a game");
        require(guestAddress != msg.sender, "You can not play against yourself");
        require(Players[msg.sender].balance + msg.value >= 3 ether, "You should have at least 3 eth to start the game");
        
        Game memory newGame = Game(msg.sender, hostHash, 0, address(0), 0, 0, block.number, false);
        Games[msg.sender] = newGame;
        Players[msg.sender].balance += msg.value;
        Players[msg.sender].hostAddress = msg.sender;
    }

    // The guest join the game, with the host address and the hash value of the secret number
    function joinGame(address hostAddress, bytes32 guestHash) payable public {
        require(Players[msg.sender].hostAddress == address(0), "You already in a game");
        require(hostAddress != msg.sender, "You can not play against yourself");
        require(Games[hostAddress].host == hostAddress, "The user didn't create a game");
        require(Games[hostAddress].guest == msg.sender || Games[hostAddress].guest == address(0) , "Your are not welcome to participate this game");
        require(Games[hostAddress].hostHash != guestHash, "Hash collision, please use other value");
        require(Players[msg.sender].balance + msg.value >= 3 ether, "You should have at least 3 eth to start the game");

        Games[hostAddress].guest = msg.sender;
        Games[hostAddress].guestHash = guestHash;
        Games[hostAddress].lastBlock = block.number;
        Players[msg.sender].balance += msg.value;
        Players[msg.sender].hostAddress = hostAddress;
    }

    // Verify the secretNumber with the hash value for each player.
    function verification(uint256 secretNumber) public {

        // Players can start to verify until all players join the game
        require(Games[Players[msg.sender].hostAddress].guest != address(0), "Waiting for guest to join the game");
        require(Games[Players[msg.sender].hostAddress].host != address(0), "Can not find the host of your game");

        // verification for host
        if (Games[Players[msg.sender].hostAddress].host == msg.sender) {
            require(Games[Players[msg.sender].hostAddress].hostSecretNumber == 0, "The secret number of host has verified");
            if (Games[Players[msg.sender].hostAddress].hostHash == getHash(secretNumber)) {
                Games[Players[msg.sender].hostAddress].hostSecretNumber = secretNumber;
            } else {
                revert("The secretNumber of host does not match");
            }
        } else if (Games[Players[msg.sender].hostAddress].guest == msg.sender) { // verification for guest
            require(Games[Players[msg.sender].hostAddress].guestSecretNumber == 0, "The secret number of guest has verified");
            if (Games[Players[msg.sender].hostAddress].guestHash == getHash(secretNumber)) {
                Games[Players[msg.sender].hostAddress].guestSecretNumber = secretNumber;
            } else {
                revert("The secretNumber of guest does not match");
            }
        }
        Games[Players[msg.sender].hostAddress].lastBlock = block.number;
    }

    function roll() public {
        // check if all the players are joining to the game and verified
        require(Games[Players[msg.sender].hostAddress].host != address(0), "You are not in a game");
        require(Games[Players[msg.sender].hostAddress].guest != address(0), "no guest join the game");
        require(Games[Players[msg.sender].hostAddress].hostSecretNumber != 0, "The host is not verified");
        require(Games[Players[msg.sender].hostAddress].guestSecretNumber != 0, "The guest is not verified");
        require(block.number - Games[Players[msg.sender].hostAddress].lastBlock >= 3, "Wait more blocks for start rolling");
        
        uint256 lastModifiedBlock = Games[Players[msg.sender].hostAddress].lastBlock + 3;
        Game memory currGame = Games[Players[msg.sender].hostAddress];

        uint256 dice = 1 + uint256(keccak256(abi.encodePacked(currGame.hostSecretNumber ^ currGame.guestSecretNumber, lastModifiedBlock))) % 6;

        if (dice < 4) {
            Players[currGame.host].balance += dice * 1 ether;
            Players[currGame.guest].balance -= dice * 1 ether;
        } else {
            Players[currGame.host].balance -= (dice - 3) * 1 ether;
            Players[currGame.guest].balance += (dice - 3) * 1 ether;
        }
        resetGame(currGame.host);
    }

    
    function resetGame(address _hostAddress) private {
        Players[Games[_hostAddress].host].hostAddress = address(0);
        Players[Games[_hostAddress].guest].hostAddress = address(0);
        Games[_hostAddress].withdrawPermit = true;
    }

    function terminateGame() public {
        require(Players[msg.sender].hostAddress != address(0), "You are not in a game");

        Game memory currGame = Games[Players[msg.sender].hostAddress];

        // host can cancel the game if no guest join
        if (currGame.guestHash == 0) {
            require(block.number - currGame.lastBlock >= 3, "You cannot terminate the game now, check 1");
            resetGame(Players[msg.sender].hostAddress);
        } else if (currGame.guestSecretNumber == 0) {    // host can cancel the game if the guest join but not verify
            require(block.number - currGame.lastBlock >= 20, "You cannot terminate the game now, check 2");
            if (currGame.hostSecretNumber != 0) { // host verified, guest not verified, host get guest deposit and terminate the game
                Players[currGame.guest].balance -= 1 ether;
                Players[currGame.host].balance += 1 ether;
                resetGame(Players[msg.sender].hostAddress);
            } else // host and guest both not verified, they get the refund and terminate the game
                resetGame(Players[msg.sender].hostAddress);
        }

        // guest can cancel the game if the host not verified for a long time
        if (currGame.hostSecretNumber == 0) 
            require(block.number - currGame.lastBlock >= 20, "You cannot terminate the game now, check 3");
            if (currGame.guestSecretNumber != 0) {
                Players[currGame.host].balance -= 1 ether;
                Players[currGame.guest].balance += 1 ether;
                resetGame(Players[msg.sender].hostAddress);
            } else {
                resetGame(Players[msg.sender].hostAddress);
            }
        }


    // withdraw the money back to the account, no permit to withdraw until dice rolled or resetted.
    function withdraw(address previousHostAddress) public payable{
        require(Players[msg.sender].balance > 0 ether, "No money in balance");
        require(Games[previousHostAddress].withdrawPermit == true, "Cannot withdraw during the game");

        uint256 reward = Players[msg.sender].balance;
        Players[msg.sender].balance = 0;
        payable(msg.sender).transfer(reward);
    }


    // generate the hash value for creating or joining the game
    function getHash(uint256 secretNumber) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(secretNumber));
    }

}