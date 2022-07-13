// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

interface OSPOracleInterface {
  function requestRegister(uint16 projectID) external;
  function requestDepsSync(uint16 projectID) external;
}

abstract contract OSPOracle is OSPOracleInterface {
  address caller;

  event RegisterEvent(uint16 projectID);
  event SyncEvent(uint16 projectID);

  constructor(address c) {
    caller = c;
  }
 
  function requestRegister(uint16 projectID) external {
    emit RegisterEvent(projectID);
  }

  function requestDepsSync(uint16 projectID) external {
    emit SyncEvent(projectID);
  }

  function replyRegister(uint16 projectID, address addr) external {
    OSPOracleClient(caller).registerProject(projectID, addr);
  }

  function replySyncDistribute(uint16 projectID) external {
    OSPOracleClient(caller).distribute(projectID);
  }

  function replySyncUpdateAndDistribute(uint16 projectID, uint16[] calldata deps) external {
    OSPOracleClient(caller).updateDepsAndDistribute(projectID, deps);
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

  function requestDonateFromOracle(uint16 projectID) internal {
    OSPOracleInterface(oracle).requestDepsSync(projectID);
  }

  function registerProject(uint16 projectID, address addr) external virtual;
  function distribute(uint16 projectID) public virtual;
  function updateDepsAndDistribute(uint16 projectID, uint16[] calldata deps) external virtual;
}