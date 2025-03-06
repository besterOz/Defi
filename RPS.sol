// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract RPSLS {
    uint public numPlayer = 0;
    uint public reward = 0;
    mapping (address => uint) public player_choice;
    mapping(address => bool) public player_not_played;
    address[] public players;
    uint public numInput = 0;

    // อนุญาตให้เล่นได้เฉพาะ 4 Accounts นี้
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
        if (numPlayer > 0) {
            require(msg.sender != players[0], "Player already in game");
        }
        require(msg.value == 1 ether, "Must send 1 ether");

        reward += msg.value;
        player_not_played[msg.sender] = true;
        players.push(msg.sender);
        numPlayer++;
    }

    function input(uint choice) public onlyAllowedPlayers {
        require(numPlayer == 2, "Not enough players");
        require(player_not_played[msg.sender], "Already played");
        require(choice >= 0 && choice <= 4, "Invalid choice");  // อนุญาตให้เลือก 0-4 เท่านั้น

        player_choice[msg.sender] = choice;
        player_not_played[msg.sender] = false;
        numInput++;

        if (numInput == 2) {
            _checkWinnerAndPay();
        }
    }

    function _checkWinnerAndPay() private {
    uint p0Choice = player_choice[players[0]];
    uint p1Choice = player_choice[players[1]];
    address payable account0 = payable(players[0]);
    address payable account1 = payable(players[1]);

    uint result = (p0Choice - p1Choice + 5) % 5;

    if (result == 1 || result == 3) {
        account0.transfer(reward);  // ผู้เล่น 0 ชนะ
    } else if (result == 2 || result == 4) {
        account1.transfer(reward);  // ผู้เล่น 1 ชนะ
    } else {
        account0.transfer(reward / 2);  // เสมอ
        account1.transfer(reward / 2);
    }

    _resetGame();
}


    function _resetGame() private {
        delete player_choice[players[0]];
        delete player_choice[players[1]];
        delete player_not_played[players[0]];
        delete player_not_played[players[1]];
        delete players;
        numPlayer = 0;
        numInput = 0;
        reward = 0;
    }
}
