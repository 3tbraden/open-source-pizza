// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./OSPOracle.sol";

contract OpenSourcePizzaOracle is OSPOracle {
  address _owner;
  address _caller;

  modifier onlyOwner {
    require(msg.sender == _owner);
    _;
  }

  constructor(address caller) OSPOracle(caller) {
    _owner = msg.sender;
  }

  function updateCaller(address caller) external onlyOwner {
    _caller = caller;
  }

  function shutdown() external onlyOwner {
    selfdestruct(payable(_owner));
  }
}