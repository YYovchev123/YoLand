// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.18;

/// @author Yovchev_Yoan
/// @dev Credit to Solmate(https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC20.sol)
contract yToken {
    /*///////////////////////////////////////////////
                        EVENTS
    ///////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /*///////////////////////////////////////////////
                    STORAGE VARIABLES
    ///////////////////////////////////////////////*/
    string public s_name;
    string public s_symbol;
    uint8 public immutable i_decimals;
    uint256 public s_totalSupply;

    mapping(address => uint256) public s_balanceOf;
    mapping(address => mapping(address => uint256)) public s_allowance;

    /*///////////////////////////////////////////////
                    CONSTRUCTOR
    ///////////////////////////////////////////////*/
    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        s_name = _name;
        s_symbol = _symbol;
        i_decimals = _decimals;
    }

    /*///////////////////////////////////////////////
                    EXTERNAL FUNCTIONS
    ///////////////////////////////////////////////*/

    // add Access Control
    function mint(uint256 _amount) external {}

    function redeem(uint256 _amount) external {}

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        s_allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        s_balanceOf[msg.sender] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            s_balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual returns (bool) {
        uint256 allowed = s_allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) s_allowance[from][msg.sender] = allowed - amount;

        s_balanceOf[from] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            s_balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 amount) internal virtual {
        s_totalSupply += amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            s_balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        s_balanceOf[from] -= amount;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            s_totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }
}
