// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

interface OSPOracleInterface {
  function requestRegister(uint32 projectID) external;
  function requestDonate(uint32 requestID) external;
}

abstract contract OSPOracle is OSPOracleInterface {
  address public owner;
  address public caller;

  event RegisterEvent(uint32 projectID);
  event DonateEvent(uint32 requestID);

  constructor(address c) {
    owner = msg.sender;
    caller = c;
  }
 
  function requestRegister(uint32 projectID) override external {
    emit RegisterEvent(projectID);
  }

  function requestDonate(uint32 requestID) override external {
    emit DonateEvent(requestID);
  }

  function replyRegister(uint32 projectID, address addr) public virtual;
  function replyDonateUpdateDeps(uint32 projectID, uint32[] calldata deps, bool isReplace) public virtual;
  function replyDonateDistribute(uint32 requestID, uint fromDepIdx, uint toDepIdx) public virtual;
}

abstract contract OSPOracleClient {
  address public owner;
  address public oracle;

  constructor() {
    owner = msg.sender;
  }

  function requestRegisterFromOracle(uint32 projectID) internal {
    OSPOracleInterface(oracle).requestRegister(projectID);
  }

  function requestDonateFromOracle(uint32 requestID) internal {
    OSPOracleInterface(oracle).requestDonate(requestID);
  }

  function updateOracle(address oc) public virtual;
  function registerProject(uint32 projectID, address addr) public virtual;
  function distribute(uint32 requestID, uint fromDepIdx, uint toDepIdx) public virtual;
  function updateDeps(uint32 projectID, uint32[] calldata deps, bool isReplace) external virtual;
}
