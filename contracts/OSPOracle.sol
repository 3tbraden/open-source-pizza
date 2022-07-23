// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

interface OSPOracleInterface {
  function requestRegister(uint16 projectID) external;
  function requestDonate(uint16 requestID) external;
}

abstract contract OSPOracle is OSPOracleInterface {
  address public owner;
  address public caller;

  event RegisterEvent(uint16 projectID);
  event DonateEvent(uint16 requestID);

  constructor(address c) {
    owner = msg.sender;
    caller = c;
  }
 
  function requestRegister(uint16 projectID) override external {
    emit RegisterEvent(projectID);
  }

  function requestDonate(uint16 requestID) override external {
    emit DonateEvent(requestID);
  }

  function replyRegister(uint16 projectID, address addr) public virtual;
  function replyDonateUpdateDeps(uint16 projectID, uint16[] calldata deps, bool isReplace) public virtual;
  function replyDonateDistribute(uint16 requestID, uint fromDepIdx, uint toDepIdx) public virtual;
}

abstract contract OSPOracleClient {
  address public owner;
  address public oracle;

  constructor() {
    owner = msg.sender;
  }

  function requestRegisterFromOracle(uint16 projectID) internal {
    OSPOracleInterface(oracle).requestRegister(projectID);
  }

  function requestDonateFromOracle(uint16 requestID) internal {
    OSPOracleInterface(oracle).requestDonate(requestID);
  }

  function updateOracle(address oc) public virtual;
  function registerProject(uint16 projectID, address addr) public virtual;
  function distribute(uint16 requestID, uint fromDepIdx, uint toDepIdx) public virtual;
  function updateDeps(uint16 projectID, uint16[] calldata deps, bool isReplace) external virtual;
}
