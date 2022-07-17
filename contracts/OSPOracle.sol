// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

interface OSPOracleInterface {
  function requestRegister(uint16 projectID) external;
  function requestDonate(uint16 requestID) external;
}

abstract contract OSPOracle is OSPOracleInterface {
  address caller;

  event RegisterEvent(uint16 projectID);
  event DonateEvent(uint16 requestID);

  constructor(address c) {
    caller = c;
  }
 
  function requestRegister(uint16 projectID) external {
    emit RegisterEvent(projectID);
  }

  function requestDonate(uint16 requestID) external {
    emit DonateEvent(requestID);
  }

  function replyRegister(uint16 projectID, address addr) external {
    OSPOracleClient(caller).registerProject(projectID, addr);
  }

  function replySyncUpdateDeps(uint16 projectID, uint16[] calldata deps, bool isReplace) external {
    OSPOracleClient(caller).updateDeps(projectID, deps, isReplace);
  }

  function replySyncDistribute(uint16 requestID, uint16 split, uint fromDepIdx, uint toDepIdx) external {
    OSPOracleClient(caller).distribute(requestID, split, fromDepIdx, toDepIdx);
  }
}

abstract contract OSPOracleClient {
  address oracle;

  constructor(address oc) {
    oracle = oc;
  }

  function requestRegisterFromOracle(uint16 projectID) internal {
    OSPOracleInterface(oracle).requestRegister(projectID);
  }

  function requestDonateFromOracle(uint16 requestID) internal {
    OSPOracleInterface(oracle).requestDonate(requestID);
  }

  function registerProject(uint16 projectID, address addr) external virtual;
  function distribute(uint16 requestID, uint16 split, uint fromDepIdx, uint toDepIdx) public virtual;
  function updateDeps(uint16 projectID, uint16[] calldata deps, bool isReplace) external virtual;
}