// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./OSPOracle.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract OpenSourcePizza is OSPOracleClient {
  address public owner;

  bool public disabled = false;

  uint public projectOwnerWeight = 50;

  mapping(uint16 => uint16[]) public projectDependencies;

  mapping(uint16 => address) public projectOwners;

  mapping(uint16 => uint256) public undistributedFunds;
  mapping(uint16 => uint256) public distribution;

  // Addresses for locked project fund to be transferred out in case of contract migration.
  mapping(uint16 => address) public fundMigrations;

  modifier onlyOwner {
    require(msg.sender == owner);
    _;
  }

  modifier onlyOracle {
    require(msg.sender == oracle);
    _;
  }

  modifier onlyEnabled {
    require(disabled == false);
    _;
  }

  constructor(address oc) OSPOracleClient(oc) {
    owner = msg.sender;
  }

  function updateOracle(address oc) external onlyOwner {
    oracle = oc;
  }

  function disableContract() external onlyOwner {
    disabled = true;
  }

  function enableContract() external onlyOwner {
    disabled = false;
  }

  function register(uint16 projectID) external onlyEnabled {
    requestRegisterFromOracle(projectID);
  }

  function donateToProject(uint16 projectID) external payable onlyEnabled {
    require(msg.value > 0);

    (bool ok, uint256 newBalance) = SafeMath.tryAdd(distribution[projectID], msg.value);
    require(ok, "add balance error");

    distribution[projectID] = newBalance;
    requestDonateFromOracle(projectID);
  }

  function redeem(uint16 projectID) external payable onlyEnabled {
    require(projectOwners[projectID] == msg.sender);
    require(distribution[projectID] > 0);

    uint256 transferValue = distribution[projectID];
    (bool ok, uint256 newBalance) = SafeMath.trySub(distribution[projectID], transferValue);
    require(ok, "subtract balance error");

    distribution[projectID] = newBalance;
    (bool redeemOK, bytes memory result) =  msg.sender.call{value: transferValue}("");
    require(redeemOK, "redeem transaction error");
  }

  function registerProject(uint16 projectID, address addr) external override onlyOracle onlyEnabled {
    projectOwners[projectID] = addr;
  }

  function distribute(uint16 projectID) public override onlyOracle onlyEnabled {
    require(undistributedFunds[projectID] > 0);

    uint256 remaining = undistributedFunds[projectID];
    uint16[] memory dependencies = projectDependencies[projectID];
    if (dependencies.length > 0) {
      // Distribute among dependents first.
      (bool depsTotalOK, uint256 dependentsShare) = SafeMath.tryMul(remaining, (100 - projectOwnerWeight) / 100);
      require(depsTotalOK, "calculate total error");
  
      (bool singleShareOK, uint256 singleShare) = SafeMath.tryDiv(dependentsShare, dependencies.length);
      require(singleShareOK, "calculate single share error");

      for (uint i = 0; i < dependencies.length; i++) {
        (bool addOK, uint256 newDepBalance) = SafeMath.tryAdd(distribution[dependencies[i]], singleShare);
        require(addOK, "distribute balance error");
        distribution[dependencies[i]] = newDepBalance;

        (bool subOK, uint256 newRemaining) = SafeMath.trySub(remaining, singleShare);
        require(subOK, "calculate remaining balance error");
        remaining = newRemaining;
      }
    }

    // Give parent project the remaining fund, only if distribution among dependents are successful.
    (bool ok, uint256 newBalance) = SafeMath.tryAdd(distribution[projectID], remaining);
    require(ok, "distribute remaining balance error");
    distribution[projectID] = newBalance;
  }

  function updateDepsAndDistribute(uint16 projectID, uint16[] calldata deps) external override onlyOracle onlyEnabled {
    // TODO: limit number of dependencies
    require(undistributedFunds[projectID] > 0);

    // Update dependencies.
    projectDependencies[projectID] = deps;

    distribute(projectID);
  }

  // Set up migration addresses for locked fund to be transferred out.
  function updateMigrationAddress(uint16 projectID, address mAddr) external {
    require(projectOwners[projectID] == msg.sender);

    fundMigrations[projectID] = mAddr;
  }

  // Transfer locked fund in case of contract migration.
  function migrateFunds(uint16 projectID) external onlyOwner {
    require(disabled);
    require(distribution[projectID] > 0);
    require(fundMigrations[projectID] != address(0));

    (bool ok, bytes memory result) = payable(fundMigrations[projectID]).call{value: distribution[projectID]}("");
    require(ok, "fund migration error");
  }
}
