// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.4.24;

import "./safemath.sol";

contract TicTacToe {
    // fee per game per person
    uint256 coinFee = 0.1 ether;
    uint256 coinsPerGame = 1;

    // safemath
    using SafeMath for uint256;
    // a game instance
    struct TicTacToeGame {
        uint8[9] board;
        address player1;
        address player2;
        address activePlayer;
        address winner;
        bool finished;
        uint256 coinPrize;
    }
    // internal coin: 1 coins = 0.1 ETH
    mapping (address => uint256) public coinsOfPlayer;
    // list of all registered players
    address[] public allPlayer;
    // all ticTacToe games ever played
    TicTacToeGame[] public allGames;

    event NewPlayerAdded();
    event NewMatchCreated(address indexed _player1, address indexed _player2);  
    event GameFieldChanged(uint indexed _gameId, address indexed _nextPlayer);
    event GameFinished(uint indexed _gameId, address indexed _winner);



    function getLengthOfArrayAllPlayer() external view returns(uint){
        return allPlayer.length;
    }

    function getLengthOfArrayAllGames() external view returns(uint){
        return allGames.length;
    }

    function getBoard(uint _gameId) external view returns(uint8 [9] memory){
        return allGames[_gameId].board;
    }

    function addressNotYetRegistered(address _a) internal view returns(bool){
        for (uint i=0; i<allPlayer.length; i++) {
            if(allPlayer[i] == _a) {
                return false;
            }
        }
        return true;
    }

    function depositEtherForCoins() external payable {
        // each game costs a certain amount of coins, assure that correct amount is deposited
        require(msg.value.mod(coinFee) == 0);
        // coins of player (1 coins equals one game)
        uint coins  = msg.value.div(coinFee);
        // add coins to players account
        coinsOfPlayer[msg.sender] = coinsOfPlayer[msg.sender].add(coins);
        // if player not in list "allPlayer" add player
        if(addressNotYetRegistered(msg.sender)){
            allPlayer.push(msg.sender);
            emit NewPlayerAdded();
        }
    }

    function startNewGame(address _player2) external returns(uint){
        // check that both player have enough coins
        require(coinsOfPlayer[msg.sender] >= coinsPerGame);
        require(coinsOfPlayer[_player2] >= coinsPerGame);
        // withdraw coins from both players
        coinsOfPlayer[msg.sender] = coinsOfPlayer[msg.sender].sub(coinsPerGame);
        coinsOfPlayer[_player2] = coinsOfPlayer[_player2].sub(coinsPerGame);
        // create new Game Instance
        uint gameId;
        gameId = allGames.push( TicTacToeGame([0,0,0,0,0,0,0,0,0], msg.sender, _player2, msg.sender, address(0), false, coinsPerGame.mul(2)) ).sub(1);
        // emit event
        emit NewMatchCreated(msg.sender, _player2);
        // return gameId (position in array for new game)
        return gameId;
    }

    function makeMove(uint _gameId, uint8 _pos) external {
        // check input
        require(_pos < 9);
        require(_gameId < allGames.length);
        // check that game is not finished
        require(allGames[_gameId].finished == false);
        // determine current player who has to make a move
        address currentPlayer = allGames[_gameId].activePlayer;
        // check that sender is current player
        require(msg.sender == currentPlayer);
        // set marker for game field
        uint8 marker;
        uint8 markerOfNextPlayer;
        address nextPlayer;
        if(currentPlayer == allGames[_gameId].player1) {
            marker = 1;
            markerOfNextPlayer = 2;
            nextPlayer = allGames[_gameId].player2;
        } else {
            marker = 2;
            markerOfNextPlayer = 1;
            nextPlayer = allGames[_gameId].player1;
        }
        // check that player can make a valid move
        require(allGames[_gameId].board[_pos] == 0);
        // make move
        allGames[_gameId].board[_pos] = marker;
        // check for winner
        if(currentPlayerWon(_gameId, marker)){
            allGames[_gameId].finished = true;
            allGames[_gameId].winner = currentPlayer;
            // send ether to winner
            bool success = currentPlayer.call.value(allGames[_gameId].coinPrize.mul(coinFee))("");
            require(success);
            // emit event (gameId, winner, price)
            emit GameFinished(_gameId, currentPlayer);

        } else if (isDraw(_gameId)) {
            // game ended, draw => return coins to players
            allGames[_gameId].finished = true;
            // winner remians address(0)
            // return coins
            uint coinsPerPlayer = allGames[_gameId].coinPrize.div(2);
            coinsOfPlayer[allGames[_gameId].player1] = coinsOfPlayer[allGames[_gameId].player1].add(coinsPerPlayer);
            coinsOfPlayer[allGames[_gameId].player2] = coinsOfPlayer[allGames[_gameId].player2].add(coinsPerPlayer);
            // emit event
            emit GameFinished(_gameId, address(0));
            
        } else {
            // now other player must make a move
            allGames[_gameId].activePlayer = nextPlayer;
            // event
            emit GameFieldChanged(_gameId, nextPlayer);
        }
    }

    function currentPlayerWon(uint _gameId, uint8 _m) internal view returns(bool) {
        // storage means pointer to that
        uint8[9] storage gF = allGames[_gameId].board;
        if(
            (gF[0]==_m && gF[3]==_m && gF[6]==_m)||
            (gF[1]==_m && gF[4]==_m && gF[7]==_m)||
            (gF[2]==_m && gF[5]==_m && gF[8]==_m)||
            (gF[0]==_m && gF[1]==_m && gF[2]==_m)||
            (gF[3]==_m && gF[4]==_m && gF[5]==_m)||
            (gF[6]==_m && gF[7]==_m && gF[8]==_m)||
            (gF[0]==_m && gF[4]==_m && gF[8]==_m)||
            (gF[2]==_m && gF[4]==_m && gF[6]==_m))
        {
            // winner
            return true;
        }
        // no winner
        return false;
    }

    function isDraw(uint _gameId) internal view returns(bool){
        uint8[9] storage gF = allGames[_gameId].board;
        return (gF[0] != 0 && gF[1] != 0 && gF[2] != 0 && gF[3] != 0 && gF[4] != 0 && gF[5] != 0 && gF[6] != 0 && gF[7] != 0 && gF[8] != 0);
    }
}
