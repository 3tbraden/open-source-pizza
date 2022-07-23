// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./OSPOracle.sol";

contract OpenSourcePizzaOracle is OSPOracle {
  modifier onlyOwner {
    require(msg.sender == owner, "owner only");
    _;
  }

  constructor(address caller) OSPOracle(caller) {}

  function updateCaller(address c) public onlyOwner {
    caller = c;
  }

  function replyRegister(uint16 projectID, address addr) override public onlyOwner {
    OSPOracleClient(caller).registerProject(projectID, addr);
  }

  function replyDonateUpdateDeps(uint16 projectID, uint16[] calldata deps, bool isReplace) override public onlyOwner {
    OSPOracleClient(caller).updateDeps(projectID, deps, isReplace);
  }

  function replyDonateDistribute(uint16 requestID, uint fromDepIdx, uint toDepIdx) override public onlyOwner {
    OSPOracleClient(caller).distribute(requestID, fromDepIdx, toDepIdx);
  }

  function shutdown() external onlyOwner {
    selfdestruct(payable(owner));
  }
}
