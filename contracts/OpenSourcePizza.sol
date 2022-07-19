// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./OSPOracle.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract OpenSourcePizza is OSPOracleClient {
  bool public disabled = true;

  uint8 public projectOwnerWeight = 50;
  uint public singleCallMaxDepsSize = 100;

  // projectID to projectIDs mapping for project dependencies.
  mapping(uint16 => uint16[]) public projectDependencies;

  /// projectID to project owner address mapping.
  mapping(uint16 => address) public projectOwners;

  /// requestID to projectID mapping.
  mapping(uint16 => uint16) public sponsorRequests;
  /// requestID to total sponsor amount mapping.
  mapping(uint16 => uint256) public sponsorRequestAmounts;
  /// requestID to remaining undistributed amount mapping.
  mapping(uint16 => uint256) public undistributedAmounts;
  /// projectIDs mapping for projects that are in the process of fund distribution.
  mapping(uint16 => bool) public distributionInProgress;

  mapping(uint16 => uint256) public distribution;

  /// Addresses for locked project fund to be transferred out in case of contract migration.
  mapping(uint16 => address) public fundMigrations;

  modifier onlyOwner {
    require(msg.sender == owner, "owner only");
    _;
  }

  modifier onlyOracle {
    require(msg.sender == oracle, "oracle only");
    _;
  }

  modifier onlyProjectOwner(uint16 projectID) {
    require(projectOwners[projectID] == msg.sender, "project owner only");
    _;
  }

  modifier onlyEnabled {
    require(disabled == false, "contract is disabled");
    _;
  }

  modifier notDistributing(uint16 projectID) {
    require(distributionInProgress[projectID] == false, "another distribution in progress for project");
    _;
  }

  function updateOracle(address oc) override public onlyOwner {
    oracle = oc;
  }

  function updateSingleCallMaxDepsSize(uint size) public onlyOwner {
    singleCallMaxDepsSize = size;
  }

  function disableContract() public onlyOwner {
    disabled = true;
  }

  function enableContract() public onlyOwner {
    require(oracle != address(0), "oracle should be different from owner");
    disabled = false;
  }

  function register(uint16 projectID) public onlyEnabled {
    requestRegisterFromOracle(projectID);
  }

  function donateToProject(uint16 projectID, uint16 requestID) public payable onlyEnabled {
    require(msg.value > 0, "no fund to donate");
    require(sponsorRequests[requestID] == uint16(0), "existing sponsorship request");
    require(sponsorRequestAmounts[requestID] == uint16(0), "existing sponsorship request");
    require(undistributedAmounts[requestID] == uint16(0), "existing sponsorship request");

    sponsorRequests[requestID] = projectID;
    sponsorRequestAmounts[requestID] = msg.value;
    undistributedAmounts[requestID] = msg.value;
    requestDonateFromOracle(requestID);
  }

  function redeem(uint16 projectID) public payable onlyEnabled onlyProjectOwner(projectID) {
    require(distribution[projectID] > 0, "no fund for project");

    uint256 transferValue = distribution[projectID];
    (bool ok, uint256 newBalance) = SafeMath.trySub(distribution[projectID], transferValue);
    require(ok, "subtract balance error");

    distribution[projectID] = newBalance;
    (bool redeemOK, bytes memory result) =  msg.sender.call{value: transferValue}("");
    require(redeemOK, "redeem transaction error");
  }

  function registerProject(uint16 projectID, address addr) public override onlyOracle onlyEnabled {
    projectOwners[projectID] = addr;
  }

  /// Updates the distribution mapping from the sponsor request amount,
  /// so that project owners can later redeem the fund.
  /// This function may be called several times for a given sponsorship request,
  /// in case the dependency list of the project is too large to be handled in a single transaction.
  /// @param split the number of iterations this distribute function will be called for a request
  /// @param fromDepIdx the starting index(inclusive) of the dependent projectID to distribute the fund to
  /// @param toDepIdx the ending index(inclusive) of the dependent projectID to distribute the fund to
  function distribute(uint16 requestID, uint16 split, uint fromDepIdx, uint toDepIdx) public override onlyOracle onlyEnabled notDistributing(sponsorRequests[requestID]) {
    // Make sure there's undistributed fund for this sponsor request.
    require(sponsorRequests[requestID] > 0, "invalid sponsorship request");
    require(sponsorRequestAmounts[requestID] > 0, "invalid sponsorship request");
    require(undistributedAmounts[requestID] > 0, "invalid sponsorship request");

    uint16 sourceProjectID = sponsorRequests[requestID];
    if (split > 0) {
      // When this function is called multiple times for a single request.
      // Checks when this function is called for multiple times for a single sponsorship request.
      // Make sure the distribution has valid dependent receivers, i.e. dep indice.
      require(toDepIdx < projectDependencies[sourceProjectID].length, "toDepIdx out of range");
      distributionInProgress[requestID] = true;
    } else {
      // Distribute among the entire dependency list.
      fromDepIdx = 0;
      toDepIdx = projectDependencies[sourceProjectID].length;
    }

    // Distribute to a maximum number of dependent projects in a single transaction.
    require(toDepIdx - fromDepIdx + 1 <= singleCallMaxDepsSize, "dep size is over allowed size");
 
    uint256 remaining = undistributedAmounts[requestID];
    for (uint i = fromDepIdx; i <= toDepIdx; i++) {
      uint256 singleDepShare = sponsorRequestAmounts[requestID] * (1 - projectOwnerWeight / 100) / (toDepIdx - fromDepIdx + 1);
      uint16 depProjectID = projectDependencies[sourceProjectID][i];
      (bool addOK, uint256 newDepBalance) = SafeMath.tryAdd(distribution[depProjectID], singleDepShare);
      require(addOK, "distribute balance error");
      distribution[depProjectID] = newDepBalance;

      (bool subOK, uint256 newRemaining) = SafeMath.trySub(remaining, singleDepShare);
      require(subOK, "calculate remaining balance error");
      remaining = newRemaining;
    }
    undistributedAmounts[requestID] = remaining;

    // Only distributes to source project when all dependent funds have been distributed.
    if (toDepIdx == projectDependencies[sourceProjectID].length - 1) {
      // Give source project the remaining fund, only if distribution among dependents are successful.
      (bool ok, uint256 newBalance) = SafeMath.tryAdd(distribution[sourceProjectID], remaining);
      require(ok, "distribute remaining balance error");
      distribution[sourceProjectID] = newBalance;

      // Reset request params.
      sponsorRequests[requestID] = 0;
      sponsorRequestAmounts[requestID] = 0;
      undistributedAmounts[requestID] = 0;
      distributionInProgress[requestID] = false;
    }
  }

  function updateDeps(
    uint16 projectID,
    uint16[] calldata deps,
    bool isReplace
  ) external override onlyOracle onlyEnabled notDistributing(projectID) {
    require(deps.length <= singleCallMaxDepsSize, "dep size is over allowed size");

    // Replace dependencies.
    if (isReplace || projectDependencies[projectID].length == 0) {
      projectDependencies[projectID] = deps;
      return;
    }

    // Append to existing dependencies
    for (uint i = 0; i < deps.length; i++) {
      projectDependencies[projectID].push(deps[i]);
    }
  }

  // Set up migration addresses for locked fund to be transferred out.
  function updateMigrationAddress(uint16 projectID, address mAddr) public onlyProjectOwner(projectID) {
    fundMigrations[projectID] = mAddr;
  }

  // Transfer locked fund in case of contract migration.
  function migrateFunds(uint16 projectID) public onlyOwner {
    require(disabled, "when contract is disabled only");
    require(distribution[projectID] > 0, "no fund for project");
    require(fundMigrations[projectID] != address(0), "invalid migration address");

    (bool ok, bytes memory result) = payable(fundMigrations[projectID]).call{value: distribution[projectID]}("");
    require(ok, "fund migration error");
  }
}
