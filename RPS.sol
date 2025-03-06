// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

contract RPSLS_CommitReveal {
    uint public numPlayer = 0;
    uint public reward = 0;
    
    struct Commit {
        bytes32 commitHash;
        uint choice;
        bool hasCommitted;
        bool hasRevealed;
    }

    mapping(address => Commit) public commits;
    address[] public players;
    uint public numCommit = 0;
    uint public numReveal = 0;

    address[4] private allowedPlayers = [
        0x5B38Da6a701c568545dCfcB03FcB875f56beddC4,
        0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,
        0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db,
        0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB
    ];

    modifier onlyAllowedPlayers() {
        bool isAllowed = false;
        for (uint i = 0; i < allowedPlayers.length; i++) {
            if (msg.sender == allowedPlayers[i]) {
                isAllowed = true;
                break;
            }
        }
        require(isAllowed, "Not an allowed player");
        _;
    }

    function addPlayer() public payable onlyAllowedPlayers {
        require(numPlayer < 2, "Game is full");
        require(!commits[msg.sender].hasCommitted, "Player already in game");
        require(msg.value == 1 ether, "Must send 1 ether");

        reward += msg.value;
        players.push(msg.sender);
        numPlayer++;
    }

    function commit(bytes32 dataHash) public onlyAllowedPlayers {
        require(numPlayer == 2, "Not enough players");
        require(!commits[msg.sender].hasCommitted, "Already committed");

        commits[msg.sender].commitHash = dataHash;
        commits[msg.sender].hasCommitted = true;
        numCommit++;

        if (numCommit == 2) {
            emit AllPlayersCommitted();
        }
    }

    event AllPlayersCommitted();

    function reveal(uint choice, bytes32 secret) public onlyAllowedPlayers {
        require(numCommit == 2, "Both players must commit first");
        require(!commits[msg.sender].hasRevealed, "Already revealed");
        require(choice >= 0 && choice <= 4, "Invalid choice");

        bytes32 calculatedHash = keccak256(abi.encodePacked(choice, secret));
        require(commits[msg.sender].commitHash == calculatedHash, "Invalid reveal");

        commits[msg.sender].choice = choice;
        commits[msg.sender].hasRevealed = true;
        numReveal++;

        if (numReveal == 2) {
            _checkWinnerAndPay();
        }
    }

    function _checkWinnerAndPay() private {
        uint p0Choice = commits[players[0]].choice;
        uint p1Choice = commits[players[1]].choice;
        address payable account0 = payable(players[0]);
        address payable account1 = payable(players[1]);

        uint result = (p0Choice - p1Choice + 5) % 5;

        if (result == 1 || result == 3) {
            account0.transfer(reward);
        } else if (result == 2 || result == 4) {
            account1.transfer(reward);
        } else {
            account0.transfer(reward / 2);
            account1.transfer(reward / 2);
        }

        _resetGame();
    }

    function _resetGame() private {
        delete commits[players[0]];
        delete commits[players[1]];
        delete players;
        numPlayer = 0;
        numCommit = 0;
        numReveal = 0;
        reward = 0;
    }

    function getHash(uint choice, bytes32 secret) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(choice, secret));
    }
}
