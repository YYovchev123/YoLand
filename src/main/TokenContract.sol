// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.18;

import {Errors} from "../libraries/Errors.sol";

contract TokenContract {
    /*///////////////////////////////////////////////
                        EVENTS
    ///////////////////////////////////////////////*/
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Deposit(address indexed from, uint256 amount);
    event Withdraw(address indexed to, uint256 amount);

    /*///////////////////////////////////////////////
                    STORAGE VARIABLES
    ///////////////////////////////////////////////*/
    string public s_name;
    string public s_symbol;
    uint8 public immutable i_decimals;
    uint256 public s_totalSupply;

    mapping(address account => uint256 balance) public s_balanceOf;
    mapping(address owner => mapping(address spender => uint256 amount)) public s_allowance;

    /*///////////////////////////////////////////////
                    CONSTRUCTOR
    ///////////////////////////////////////////////*/
    // @dev consider adding some checks
    constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 _totalSupply) {
        s_name = _name;
        s_symbol = _symbol;
        i_decimals = _decimals;
        s_totalSupply = _totalSupply;
    }
    /*///////////////////////////////////////////////
                    EXTERNAL FUNCTIONS
    ///////////////////////////////////////////////*/

    function deposit(uint256 _amount) external returns (bool) {
        if (_amount <= 0) revert Errors.InsufficientDeposit();

        unchecked {
            s_balanceOf[msg.sender] += _amount;
            s_totalSupply += _amount;
        }

        emit Deposit(msg.sender, _amount);

        return true;
    }

    function withdraw(uint256 _amount) external returns (bool) {
        if (s_balanceOf[msg.sender] > _amount) revert Errors.InsufficientBalance();

        s_balanceOf[msg.sender] += _amount;
        s_totalSupply += _amount;

        emit Withdraw(msg.sender, _amount);

        return true;
    }

    function transfer(address _to, uint256 _amount) external returns (bool success) {
        if (s_balanceOf[msg.sender] < _amount) revert Errors.InsufficientBalance();

        s_balanceOf[msg.sender] -= _amount;
        unchecked {
            s_balanceOf[_to] += _amount;
        }

        emit Transfer(msg.sender, _to, _amount);

        return true;
    }

    function transferFrom(address _from, address _to, uint256 _amount) external returns (bool) {
        uint256 allowedAmount = s_allowance[_from][msg.sender];
        if (allowedAmount != type(uint256).max) s_allowance[_from][msg.sender] = allowedAmount - _amount;

        s_balanceOf[_from] -= _amount;

        unchecked {
            s_balanceOf[_to] += _amount;
        }

        emit Transfer(_from, _to, _amount);

        return true;
    }

    function approve(address _spender, uint256 _amount) external returns (bool) {
        s_allowance[msg.sender][_spender] = _amount;

        emit Approval(msg.sender, _spender, _amount);

        return true;
    }
    /*///////////////////////////////////////////////
                PUBLIC VIEW FUNCTIONS
    ///////////////////////////////////////////////*/

    function allowance(address _owner, address _spender) public view returns (uint256) {
        return s_allowance[_owner][_spender];
    }
}
