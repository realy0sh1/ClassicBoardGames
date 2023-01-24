// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.4.24;

import "./safemath.sol";

contract Checkers {
    // fee per game per person
    uint256 coinFee = 0.1 ether;
    uint256 coinsPerGame = 1;

    // safemath
    using SafeMath for uint256;
    // a game instance
    struct CheckersGame {
        uint8[8][8] board;
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
    CheckersGame[] public allGames;

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

    function getBoard(uint _gameId) external view returns(uint8 [8][8] memory){
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
        // 1 means player 1 (WHITE)
        // 2 means player 2 (BLACK)
        // 0 means empty
        gameId = allGames.push( CheckersGame([[1,0,1,0,1,0,1,0],[0,1,0,1,0,1,0,1],[1,0,1,0,1,0,1,0],[0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0],[0,2,0,2,0,2,0,2],[2,0,2,0,2,0,2,0],[0,2,0,2,0,2,0,2]], msg.sender, _player2, msg.sender, address(0), false, coinsPerGame.mul(2)) ).sub(1);
        // emit event
        emit NewMatchCreated(msg.sender, _player2);
        // return gameId (position in array for new game)
        return gameId;
    }

    function makeMove(uint _gameId, uint8 _fromN, uint8 _fromC, uint8 _toN, uint8 _toC) external {
        // check input
        require(_fromN < 8);
        require(_fromC < 8);
        require(_toN < 8);
        require(_toC < 8);
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
        // check if move is possible
        require(checkIfMovePosible(_gameId, _fromN, _fromC, _toN, _toC, marker, markerOfNextPlayer));
        // make move
        if(executeMove(_gameId, _fromN, _fromC, _toN, _toC)){
            nextPlayer = currentPlayer;
        }
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
            // only draw if two kings left. The case that a player cannot do any valid move is not implemented
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

    function checkIfMovePosible(uint _gameId, uint8 _fromN, uint8 _fromC, uint8 _toN, uint8 _toC, uint8 _currentPlayer, uint8 _nextPlayer) internal view returns(bool){
        uint8[8][8] storage gF = allGames[_gameId].board;

        require(gF[_fromN][_fromC] % 2 == _currentPlayer);
        require(gF[_fromN][_fromC] != 0);
        require(gF[_toN][_toC] == 0);
        if(((gF[_fromN][_fromC] - 1) / 2) == 0){
            return checkMoveMan(_gameId, _fromN, _fromC, _toN, _toC, _currentPlayer, _nextPlayer);
        }
        else if(((gF[_fromN][_fromC] - 1) / 2) == 1){
            return checkMoveKing(_gameId, _fromN, _fromC, _toN, _toC, _currentPlayer, _nextPlayer);
        }

        return false;
    }

    function checkMoveMan(uint _gameId, uint8 _fromN, uint8 _fromC, uint8 _toN, uint8 _toC, uint8 _currentPlayer, uint8 _nextPlayer) internal view returns(bool){
        uint8[8][8] storage gF = allGames[_gameId].board;
        
        if((_toN == _fromN + 1 || _toN == _fromN - 1) && _fromC + 1 == _toC){
            return true;
        }
        else if((_toN == _fromN + 2 || _toN == _fromN - 2) && _fromC + 2 == _toC){
            require(gF[(_fromN + _toN) / 2][(_fromC + _toC) / 2] == 3 - _currentPlayer);
        }
    }

    function checkMoveKing(uint _gameId, uint8 _fromN, uint8 _fromC, uint8 _toN, uint8 _toC, uint8 _currentPlayer, uint8 _nextPlayer) internal view returns(bool){
        uint8[8][8] storage gF = allGames[_gameId].board;
        
        if((_toN == _fromN + 1 || _toN == _fromN - 1) && _fromC + 1 == _toC){
            return true;
        }
        else if((_toN == _fromN + 2 || _toN == _fromN - 2) && _fromC + 2 == _toC){
            require(gF[(_fromN + _toN) / 2][(_fromC + _toC) / 2] == 3 - _currentPlayer);
        }
        else if((_toN == _fromN + 1 || _toN == _fromN - 1) && _fromC - 1 == _toC){
            return true;
        }
        else if((_toN == _fromN + 2 || _toN == _fromN - 2) && _fromC - 2 == _toC){
            require(gF[(_fromN + _toN) / 2][(_fromC + _toC) / 2] == 3 - _currentPlayer);
        }
    }

    function executeMove(uint _gameId, uint8 _fromN, uint8 _fromC, uint8 _toN, uint8 _toC) internal returns(bool){
        uint8[8][8] storage gF = allGames[_gameId].board;
        uint8 figure = gF[_fromN][_fromC];
        bool hasNextMove = false;
        //move from
        gF[_fromN][_fromC] = 0;
        // In case you hit a figure
        if(_fromC + 2 == _toC || _fromC - 2 == _toC){
            gF[(_fromN + _toN) / 2][(_fromC + _toC) / 2] = 0;
            hasNextMove = true;
        }
        // In case a man gets crowned
        if(figure < 3 && _toC == (2 - figure)*8){
            figure += 2;
            hasNextMove = false;
        }
        // move to
        gF[_toN][_toC] = figure;
        return hasNextMove;
    }

    function currentPlayerWon(uint _gameId, uint8 _m) internal view returns(bool) {
        // _m is marker of current player (1 white and 2 black)
        // storage means pointer to that
        uint8[8][8] storage gF = allGames[_gameId].board;

        for (uint i=0; i<8; i++) {
            for (uint j=0; j<8; j++) {
                if((gF[i][j] % 2 != _m % 2)&&(gF[i][j] != 0)){
                    // current player does not win, because other king is still alive
                    return false;
                }
            }
        }

        return false;
    }

    function isDraw(uint _gameId) internal view returns(bool){
        uint8[8][8] storage gF = allGames[_gameId].board;
        return false;
    }
}

