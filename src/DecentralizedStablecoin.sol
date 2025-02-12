//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC20Burnable, ERC0} from "openzeppelin-contracts/contracts/token/ERC20/extensions";
import {Ownable} from "openzeppelin-contracts/contracts/access";

contract DecentralizedStablecoin is ERC20Burnable, Ownable {
    error AmountLessThanZero();
    error ZeroAddress();
    error BurntAmountGreaterThanBalance();

    constructor() ERC20("DecentralizedStablecoin", "DSC") {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert BurntAmountLessThanZero();
        } else if (_amount > balance) {
            revert BurntAmountGreaterThanBalance();
        }
        super.burn(_amount);
    }

    function mint(
        address _to,
        uint256 _amount
    ) public onlyOwner returns (bool) {
        if (_to = address(0)) {
            revert ZeroAddress();
        }
        if (_amount <= 0) {
            revert AmountLessThanZero();
        }
        _mint(_to, _amount);
        return true;
    }
}
