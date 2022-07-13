// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./OSPOracle.sol";

contract OpenSourcePizzaOracle is OSPOracle {
  address owner;

  modifier onlyOwner {
    require(msg.sender == owner);
    _;
  }

  constructor(address caller) OSPOracle(caller) {
    owner = msg.sender;
  }

  function updateCaller(address c) external onlyOwner {
    caller = c;
  }

  function shutdown() external onlyOwner {
    selfdestruct(payable(owner));
  }
}