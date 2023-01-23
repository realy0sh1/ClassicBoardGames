// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.4.24;

import "./safemath.sol";

contract Chess {
    // fee per game per person
    uint256 coinFee = 0.1 ether;
    uint256 coinsPerGame = 1;

    // safemath
    using SafeMath for uint256;
    // a game instance
    struct ChessGame {
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
    ChessGame[] public allGames;

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
        // 10 means player 1 (WHITE)
        // 20 means player 2 (BLACK)

        // X1 Bauer
        // X2 Turm
        // X3 Pferd
        // X4 Läufer
        // X5 Dame
        // X6 König
        gameId = allGames.push( ChessGame([[12,13,14,15,16,14,13,12],[11,11,11,11,11,11,11,11],[0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0],[21,21,21,21,21,21,21,21],[22,23,24,25,26,24,23,22]], msg.sender, _player2, msg.sender, address(0), false, coinsPerGame.mul(2)) ).sub(1);
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
            marker = 10;
            markerOfNextPlayer = 20;
            nextPlayer = allGames[_gameId].player2;
        } else {
            marker = 20;
            markerOfNextPlayer = 10;
            nextPlayer = allGames[_gameId].player1;
        }
        // check if move is possible
        checkIfMovePosible(_gameId, _fromN, _fromC, _toN, _toC, marker, markerOfNextPlayer);
        // make move
        executeMove(_gameId, _fromN, _fromC, _toN, _toC);
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
        uint8 figure = gF[_fromN][_fromC];
        uint8 figureType = figure%10;
        // check that there is a figure
        require(figure !=0);
        // check that the correct colour is moved
        require((figure-(figureType)) == _currentPlayer);
        // check that figure move
        require(!((_fromN == _toN) && (_fromC == _toC)));
        // check is movement is possible
        if((figureType)==1){
            // Bauer
            return checkMovePawn(_gameId, _fromN, _fromC, _toN, _toC);
        }else if((figureType)==2){
            // Turm
            return checkMoveRook(_gameId, _fromN, _fromC, _toN, _toC);
        }else if((figureType)==3){
            // Pferd
            return checkMoveKnight(_gameId, _fromN, _fromC, _toN, _toC);
        }else if((figureType)==4){
            // Läufer
            return checkMoveBishop(_gameId, _fromN, _fromC, _toN, _toC);
        }else if((figureType)==5){
            // Dame
            return checkMoveQueen(_gameId, _fromN, _fromC, _toN, _toC);
        }else if((figureType)==6){
            // König
            return checkMoveKing(_gameId, _fromN, _fromC, _toN, _toC);
        }else{
            // cannot happen, abord
            require(1==0);
        }
        return false;
    }

    function executeMove(uint _gameId, uint8 _fromN, uint8 _fromC, uint8 _toN, uint8 _toC) internal{
        uint8[8][8] storage gF = allGames[_gameId].board;
        uint8 figure = gF[_fromN][_fromC];
        //move from
        gF[_fromN][_fromC] = 0;
        // move to
        gF[_toN][_toC] = figure;
    }

    function checkMovePawn(uint _gameId, uint8 _fromN, uint8 _fromC, uint8 _toN, uint8 _toC) internal view returns(bool){
        uint8[8][8] storage gF = allGames[_gameId].board;
        uint8 figure = gF[_fromN][_fromC];
        uint8 figureType = figure%10;
        require(figureType == 1);
        uint8 color = figure-figureType;
        require((color == 10)||(color == 20));
        if(color == 10){
            if(_fromC == _toC){
                // nobody is at destination
                require(gF[_toN][_toC] == 0);
                // +1 or +2 
                require((_fromN+1 == _toN)||((_fromN+2 == _toN) && (_fromN == 1) && (gF[_fromN+1][_fromC] == 0)));
            } else if(_fromN+1 == _toN){
                if((_fromC+1==_toC)||(_fromC-1==_toC)){
                    // other player is on the destination field
                    require((gF[_toN][_toC]-(gF[_toN][_toC]%10))==20);
                } else{
                    // move not allowed
                    require(1==0);
                }
            } else{
                // move not allowed
                require(1==0);
            }
        }else{
            if(_fromC == _toC){
                // nobody is at destination
                require(gF[_toN][_toC] == 0);
                // +1 or +2 
                require((_fromN-1 == _toN)||((_fromN-2 == _toN) && (_fromN == 6) && (gF[_fromN-1][_fromC] == 0)));
            } else if(_fromN-1 == _toN){
                if((_fromC+1==_toC)||(_fromC-1==_toC)){
                    // other player is on the destination field
                    require((gF[_toN][_toC]-(gF[_toN][_toC]%10))==10);
                } else{
                    // move not allowed
                    require(1==0);
                }
            } else{
                // move not allowed
                require(1==0);
            }
        }
        return true;
    }

    function checkMoveRook(uint _gameId, uint8 _fromN, uint8 _fromC, uint8 _toN, uint8 _toC) internal view returns(bool){
        uint8[8][8] storage gF = allGames[_gameId].board;
        uint8 figure = gF[_fromN][_fromC];
        uint8 figureType = figure%10;
        require(figureType == 2);
        uint8 color = figure-figureType;
        require((color == 10)||(color == 20));
        // valid move
        require( (_fromN == _toN)||(_fromC == _toC) );
        // check that no other figure on way (excluding start and destination)
        uint8 startPos;
        uint8 destPos;
        if((_fromC == _toC)&&(_fromN > _toN)) {
            // case 1 move down
            startPos = _fromN-1;
            destPos = _toN;
            for(startPos;startPos>destPos; startPos--){
                require(gF[startPos][_fromC]==0);
            }
        } else if((_fromC == _toC)&&(_fromN < _toN)) {
            // case 2 move up
            startPos = _fromN+1;
            destPos = _toN;
            for(startPos;startPos<destPos; startPos++){
                require(gF[startPos][_fromC]==0);
            }
        } else if((_fromN == _toN)&&(_fromC < _toC)) {
            // case 3 move right
            startPos = _fromC+1;
            destPos = _toC;
            for(startPos;startPos<destPos; startPos++){
                require(gF[_fromN][startPos]==0);
            }
        } else if((_fromN == _toN)&&(_fromC > _toC)) {
            // case4 move left
            startPos = _fromC-1;
            destPos = _toC;
            for(startPos;startPos>destPos; startPos--){
                require(gF[_fromN][startPos]==0);
            }
        }else{
            // not valid
            require(1==0);
        }
        // assure that not own figure is on distination
        require((gF[_toN][_toC]-(gF[_toN][_toC]%10)) != color);
        return true;
    }   

    function checkMoveKnight(uint _gameId, uint8 _fromN, uint8 _fromC, uint8 _toN, uint8 _toC) internal view returns(bool){
        uint8[8][8] storage gF = allGames[_gameId].board;
        uint8 figure = gF[_fromN][_fromC];
        uint8 figureType = figure%10;
        require(figureType == 3);
        uint8 color = figure-figureType;
        require((color == 10)||(color == 20));
        // valid move
        require(( (_fromC-1==_toC) && (_fromN+2 == _toN) )||
                ( (_fromC+1==_toC) && (_fromN+2 == _toN) )||
                ( (_fromC+2==_toC) && (_fromN+1 == _toN) )||
                ( (_fromC+2==_toC) && (_fromN-1 == _toN) )||
                ( (_fromC+1==_toC) && (_fromN-2 == _toN) )||
                ( (_fromC-1==_toC) && (_fromN-2 == _toN) )||
                ( (_fromC-2==_toC) && (_fromN+1 == _toN) )||
                ( (_fromC-2==_toC) && (_fromN-1 == _toN) )
        );  
        // assure that not own figure is on distination
        require((gF[_toN][_toC]-(gF[_toN][_toC]%10)) != color);
        return true;
    }   

    function checkMoveBishop(uint _gameId, uint8 _fromN, uint8 _fromC, uint8 _toN, uint8 _toC) internal view returns(bool){
        uint8[8][8] storage gF = allGames[_gameId].board;
        uint8 figure = gF[_fromN][_fromC];
        uint8 figureType = figure%10;
        require(figureType == 4);
        uint8 color = figure-figureType;
        require((color == 10)||(color == 20));

        uint8 startPosN;
        uint8 startPosC;
        uint8 destPos;
        // check that no other figure on way (excluding start and destination)
        if((_fromN < _toN) && (_fromC < _toC)){
            // case 1: move to top right
            // valid diagonal
            require((_toN-_fromN) == (_toC-_fromC));
            // no figures in between
            startPosN = _fromN+1;
            startPosC = _fromC+1;
            destPos = _toN;
            for(startPosN;startPosN<destPos; startPosN++){
                require(gF[startPosN][startPosC]==0);
                startPosC = startPosC+1;
            }
        }else if((_fromN < _toN) && (_fromC > _toC)){
            // case 2: move to top left
            // valid diagonal
            require((_toN-_fromN) == (_fromC-_toC));
            // no figures in between
            startPosN = _fromN+1;
            startPosC = _fromC+1;
            destPos = _toN;
            for(startPosN;startPosN<destPos; startPosN++){
                require(gF[startPosN][startPosC]==0);
                startPosC = startPosC-1;
            }
        }else if((_fromN > _toN) && (_fromC < _toC)){
            // case 3: move to botton right
            // valid diagonal
            require((_fromN-_toN) == (_toC-_fromC));
            // no figures in between
            startPosN = _fromN-1;
            startPosC = _fromC+1;
            destPos = _toN;
            for(startPosN;startPosN>destPos; startPosN--){
                require(gF[startPosN][startPosC]==0);
                startPosC = startPosC+1;
            }
        }else if( (_fromN > _toN) && (_fromC > _toC) ){
            // case4: move to botton left
            // valid diagonal
            require((_fromN-_toN) == (_fromC-_toC));
            // no figures in between
            startPosN = _fromN-1;
            startPosC = _fromC-1;
            destPos = _toN;
            for(startPosN;startPosN>destPos; startPosN--){
                require(gF[startPosN][startPosC]==0);
                startPosC = startPosC-1;
            }
        }else{
            // invalid move
            require(1==0);
        }
        // assure that not own figure is on distination
        require((gF[_toN][_toC]-(gF[_toN][_toC]%10)) != color);
        return true;
    }   

    function checkMoveQueen(uint _gameId, uint8 _fromN, uint8 _fromC, uint8 _toN, uint8 _toC) internal view returns(bool){
        // combine bishop and rook
        uint8[8][8] storage gF = allGames[_gameId].board;
        uint8 figure = gF[_fromN][_fromC];
        uint8 figureType = figure%10;
        require(figureType == 5);
        uint8 color = figure-figureType;
        require((color == 10)||(color == 20));

        uint8 startPos;
        uint8 destPos;
        uint8 startPosN;
        uint8 startPosC;
        if( (_fromN == _toN)||(_fromC == _toC) ){
            // check as is rook
            // check that no other figure on way (excluding start and destination)
            if((_fromC == _toC)&&(_fromN > _toN)) {
                // case 1 move down
                startPos = _fromN-1;
                destPos = _toN;
                for(startPos;startPos>destPos; startPos--){
                    require(gF[startPos][_fromC]==0);
                }
            } else if((_fromC == _toC)&&(_fromN < _toN)) {
                // case 2 move up
                startPos = _fromN+1;
                destPos = _toN;
                for(startPos;startPos<destPos; startPos++){
                    require(gF[startPos][_fromC]==0);
                }
            } else if((_fromN == _toN)&&(_fromC < _toC)) {
                // case 3 move right
                startPos = _fromC+1;
                destPos = _toC;
                for(startPos;startPos<destPos; startPos++){
                    require(gF[_fromN][startPos]==0);
                }
            } else if((_fromN == _toN)&&(_fromC > _toC)) {
                // case4 move left
                startPos = _fromC-1;
                destPos = _toC;
                for(startPos;startPos>destPos; startPos--){
                    require(gF[_fromN][startPos]==0);
                }
            }else{
                // not valid
                require(1==0);
            }
        } else {
            // check as if bishop
            // check that no other figure on way (excluding start and destination)
            if((_fromN < _toN) && (_fromC < _toC)){
                // case 1: move to top right
                // valid diagonal
                require((_toN-_fromN) == (_toC-_fromC));
                // no figures in between
                startPosN = _fromN+1;
                startPosC = _fromC+1;
                destPos = _toN;
                for(startPosN;startPosN<destPos; startPosN++){
                    require(gF[startPosN][startPosC]==0);
                    startPosC = startPosC+1;
                }
            }else if((_fromN < _toN) && (_fromC > _toC)){
                // case 2: move to top left
                // valid diagonal
                require((_toN-_fromN) == (_fromC-_toC));
                // no figures in between
                startPosN = _fromN+1;
                startPosC = _fromC-1;
                destPos = _toN;
                for(startPosN;startPosN<destPos; startPosN++){
                    require(gF[startPosN][startPosC]==0);
                    startPosC = startPosC-1;
                }
            }else if((_fromN > _toN) && (_fromC < _toC)){
                // case 3: move to botton right
                // valid diagonal
                require((_fromN-_toN) == (_toC-_fromC));
                // no figures in between
                startPosN = _fromN-1;
                startPosC = _fromC+1;
                destPos = _toN;
                for(startPosN;startPosN>destPos; startPosN--){
                    require(gF[startPosN][startPosC]==0);
                    startPosC = startPosC+1;
                }
            }else if( (_fromN > _toN) && (_fromC > _toC) ){
                // case4: move to botton left
                // valid diagonal
                require((_fromN-_toN) == (_fromC-_toC));
                // no figures in between
                startPosN = _fromN-1;
                startPosC = _fromC-1;
                destPos = _toN;
                for(startPosN;startPosN>destPos; startPosN--){
                    require(gF[startPosN][startPosC]==0);
                    startPosC = startPosC-1;
                }
            }else{
                // invalid move
                require(1==0);
            }
        }
        // assure that not own figure is on distination
        require((gF[_toN][_toC]-(gF[_toN][_toC]%10)) != color);
        return true;
    }   

    function checkMoveKing(uint _gameId, uint8 _fromN, uint8 _fromC, uint8 _toN, uint8 _toC) internal view returns(bool){
        uint8[8][8] storage gF = allGames[_gameId].board;
        uint8 figure = gF[_fromN][_fromC];
        uint8 figureType = figure%10;
        require(figureType == 6);
        uint8 color = figure-figureType;
        require((color == 10)||(color == 20));
        // valid move
        require(    ((_fromC == _toC)&&( (_fromN+1 == _toN) || (_fromN-1 == _toN) ))||
                    ((_fromN == _toN)&&( (_fromC+1 == _toC) || (_fromC-1 == _toC) ))||
                    ((_fromN+1 == _toN)&&((_fromC+1 == _toC) || (_fromC-1 == _toC)))||
                    ((_fromN-1 == _toN)&&((_fromC+1 == _toC) || (_fromC-1 == _toC)))
                );
        require((gF[_toN][_toC]-(gF[_toN][_toC]%10)) != color);
        return true;
    }    



    function currentPlayerWon(uint _gameId, uint8 _m) internal view returns(bool) {
        // _m is marker of current player (10 white and 20 black)
        // storage means pointer to that
        uint8[8][8] storage gF = allGames[_gameId].board;
        // player 10 wins if 26 (black king is not there anymore)
        // player 20 wins if 16 (white king is not there anymore)
        for (uint i=0; i<8; i++) {
            for (uint j=0; j<8; j++) {
                if(((gF[i][j]==26)&&(_m==10))||((gF[i][j]==16)&&(_m==20))){
                    // current player does not win, because other king is still alive
                    return false;
                }
            }
        }
        // winner (no king found)
        return true;
    }

    function isDraw(uint _gameId) internal view returns(bool){
        uint8[8][8] storage gF = allGames[_gameId].board;
        // only two kings left
        for (uint i=0; i<8; i++) {
            for (uint j=0; j<8; j++) {
                if((gF[i][j]!=0)&&(gF[i][j]!=26)&&(gF[i][j]!=16)){
                    // not empty and not a king => other 
                    return false;
                }
            }
        }
        return true;
    }
}
