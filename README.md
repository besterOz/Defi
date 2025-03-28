1. ตัวแปรภายใน
uint public numPlayer = 0;
uint public reward = 0;
mapping(address => bytes32) public player_commit;
mapping(address => uint) public player_choice;
mapping(address => bool) public player_not_played;
address[] public players;
uint public numInput = 0;
uint256 public startTime;
uint256 public constant TIMEOUT = 5 minutes;
numPlayer: จำนวนผู้เล่นที่เข้าร่วมเกม (สูงสุด 2 คน)
reward: จำนวน Ether ที่ผู้เล่นฝากเพื่อเข้าร่วมเกม
player_commit: เก็บค่าที่ผู้เล่นแต่ละคน commit (hash ของการเลือก)
player_choice: เก็บการเลือกตัวเลือกของผู้เล่นหลังจากเปิดเผย
player_not_played: สถานะของผู้เล่นที่ยังไม่ได้เปิดเผยการเลือก
players: อาร์เรย์ที่เก็บที่อยู่ของผู้เล่น
numInput: จำนวนผู้เล่นที่ได้เปิดเผยการเลือกแล้ว
startTime: เวลาที่เกมเริ่มต้น
TIMEOUT: เวลารอสูงสุดที่ผู้เล่นสามารถถอนตัวจากเกมได้หลังจากเริ่ม

2. ตัวแปร allowedPlayers
address[4] private allowedPlayers = [
    0x5B38Da6a701c568545dCfcB03FcB875f56beddC4,
    0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,
    0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db,
    0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB
];
allowedPlayers: เป็นที่อยู่ของผู้เล่นที่ได้รับอนุญาตให้เข้าร่วมเกม (สูงสุด 4 คน)

3. Modifier onlyAllowedPlayers
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
onlyAllowedPlayers: Modifier ที่ใช้ตรวจสอบว่าแอดเดรสของผู้เล่นที่เรียกฟังก์ชันนั้นๆ เป็นหนึ่งในที่อยู่ที่ได้รับอนุญาตหรือไม่

4. ฟังก์ชัน addPlayer
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
    
    if (numPlayer == 2) {
        startTime = block.timestamp;
    }
}
addPlayer: ฟังก์ชันที่ใช้ในการเพิ่มผู้เล่นเข้าเกม โดยผู้เล่นต้องส่ง 1 Ether เพื่อเข้าร่วม
ถ้าเกมเต็ม (2 ผู้เล่น) จะไม่สามารถเข้าร่วมได้
เมื่อมีผู้เล่นครบ 2 คน เกมจะเริ่ม

5. ฟังก์ชัน commit
function commit(bytes32 commitHash) public onlyAllowedPlayers {
    require(player_not_played[msg.sender], "Already committed");
    player_commit[msg.sender] = commitHash;
}
commit: ฟังก์ชันที่ผู้เล่นส่งค่าการเลือกตัวเลือก (แบบแฮช) ก่อนที่จะเปิดเผยตัวเลือก

6. ฟังก์ชัน reveal
function reveal(uint choice, bytes32 secret) public onlyAllowedPlayers {
    require(player_commit[msg.sender] != 0, "No commit found");
    require(keccak256(abi.encodePacked(choice, secret)) == player_commit[msg.sender], "Commit does not match");
    require(choice >= 0 && choice <= 4, "Invalid choice");
    
    player_choice[msg.sender] = choice;
    player_not_played[msg.sender] = false;
    numInput++;
    
    if (numInput == 2) {
        _checkWinnerAndPay();
    }
}
reveal: ฟังก์ชันที่ผู้เล่นเปิดเผยตัวเลือกจริงๆ โดยต้องใช้ commitHash ที่ได้ส่งไว้ก่อนหน้าเพื่อยืนยันการเลือก

7. ฟังก์ชัน _checkWinnerAndPay
function _checkWinnerAndPay() private {
    uint p0Choice = player_choice[players[0]];
    uint p1Choice = player_choice[players[1]];
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
_checkWinnerAndPay: ฟังก์ชันที่คำนวณผลการแข่งขันระหว่างผู้เล่นสองคน และจ่ายรางวัล Ether ให้แก่ผู้ชนะ
หากผลเสมอ ผู้เล่นทั้งสองจะได้รับรางวัลครึ่งหนึ่ง

8. ฟังก์ชัน forceWithdraw
function forceWithdraw() public onlyAllowedPlayers {
    require(numPlayer == 2, "Game not started");
    require(block.timestamp > startTime + TIMEOUT, "Cannot withdraw yet");

    if (player_not_played[players[0]]) {
        payable(players[1]).transfer(reward);
    } else if (player_not_played[players[1]]) {
        payable(players[0]).transfer(reward);
    }
    
    _resetGame();
}
forceWithdraw: ฟังก์ชันที่อนุญาตให้ผู้เล่นถอนตัวจากเกมหากผู้เล่นคนใดไม่เปิดเผยการเลือกภายในเวลา TIMEOUT ที่กำหนด

9. ฟังก์ชัน _resetGame
function _resetGame() private {
    delete player_commit[players[0]];
    delete player_commit[players[1]];
    delete player_choice[players[0]];
    delete player_choice[players[1]];
    delete player_not_played[players[0]];
    delete player_not_played[players[1]];
    delete players;
    numPlayer = 0;
    numInput = 0;
    reward = 0;
    startTime = 0;
}
_resetGame: ฟังก์ชันที่รีเซ็ตสถานะของเกมหลังจากจบเกมหรือยกเลิกเกม