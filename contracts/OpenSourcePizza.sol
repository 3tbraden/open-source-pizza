// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./OSPOracle.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract OpenSourcePizza is OSPOracleClient {
  bool public disabled = true;

  uint8 public projectOwnerWeight = 50;
  uint public singleCallMaxDepsSize = 100;

  // projectID to projectIDs mapping for project dependencies.
  mapping(uint32 => uint32[]) public projectDependencies;

  /// projectID to project owner address mapping.
  mapping(uint32 => address) public projectOwners;

  /// requestID to projectID mapping.
  mapping(uint32 => uint32) public sponsorRequests;
  /// requestID to total sponsor amount mapping.
  mapping(uint32 => uint256) public sponsorRequestAmounts;
  /// requestID to remaining undistributed amount mapping.
  mapping(uint32 => uint256) public undistributedAmounts;
  /// projectIDs mapping for projects that are in the process of fund distribution, value in # of distribution currently in process.
  mapping(uint32 => uint8) public distributionInProgress;

  mapping(uint32 => uint256) public distribution;

  /// Addresses for locked project fund to be transferred out in case of contract migration.
  mapping(uint32 => address) public fundMigrations;

  modifier onlyOwner {
    require(msg.sender == owner, "owner only");
    _;
  }

  modifier onlyOracle {
    require(msg.sender == oracle, "oracle only");
    _;
  }

  modifier onlyProjectOwner(uint32 projectID) {
    require(projectOwners[projectID] == msg.sender, "project owner only");
    _;
  }

  modifier onlyEnabled {
    require(disabled == false, "contract is disabled");
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
    require(oracle != address(0), "oracle is missing");
    disabled = false;
  }

  function register(uint32 projectID) public onlyEnabled {
    requestRegisterFromOracle(projectID);
  }

  function donateToProject(uint32 projectID, uint32 requestID) public payable onlyEnabled {
    require(msg.value > 0, "no fund to donate");
    require(projectID > 0, "projectID should be larger than 0");
    require(sponsorRequests[requestID] == uint32(0), "existing sponsorship request");
    require(sponsorRequestAmounts[requestID] == uint32(0), "existing sponsorship request");
    require(undistributedAmounts[requestID] == uint32(0), "existing sponsorship request");

    sponsorRequests[requestID] = projectID;
    sponsorRequestAmounts[requestID] = msg.value;
    undistributedAmounts[requestID] = msg.value;
    requestDonateFromOracle(requestID);
  }

  function redeem(uint32 projectID) public payable onlyEnabled onlyProjectOwner(projectID) {
    require(distribution[projectID] > 0, "no fund for project");

    uint256 transferValue = distribution[projectID];
    (bool ok, uint256 newBalance) = SafeMath.trySub(distribution[projectID], transferValue);
    require(ok, "subtract balance error");

    distribution[projectID] = newBalance;
    (bool redeemOK, bytes memory result) =  msg.sender.call{value: transferValue}("");
    require(redeemOK, "redeem transaction error");
  }

  function registerProject(uint32 projectID, address addr) public override onlyOracle onlyEnabled {
    projectOwners[projectID] = addr;
  }

  /// Updates the distribution mapping from the sponsor request amount,
  /// so that project owners can later redeem the fund.
  /// This function may be called several times for a given sponsorship request,
  /// in case the dependency list of the project is too large to be handled in a single transaction.
  /// @param requestID is the request to distribute locked fund for.
  /// @param fromDepIdx the starting index(inclusive) of the dependent projectID to distribute the fund to.
  /// @param toDepIdx the ending index(inclusive) of the dependent projectID to distribute the fund to.
  function distribute(uint32 requestID, uint fromDepIdx, uint toDepIdx) public override onlyOracle onlyEnabled {
    // Make sure there's undistributed fund for this sponsor request.
    require(sponsorRequests[requestID] > 0, "invalid sponsorship request");
    require(sponsorRequestAmounts[requestID] > 0, "invalid sponsorship request");
    require(undistributedAmounts[requestID] > 0, "invalid sponsorship request");

    uint32 sourceProjectID = sponsorRequests[requestID];
    if (toDepIdx == 0) {
      // Distribute among the entire dependency list.
      fromDepIdx = 0;
      toDepIdx = projectDependencies[sourceProjectID].length - 1;
    }
    // Distribute to a maximum number of dependent projects in a single transaction.
    require(toDepIdx - fromDepIdx + 1 <= singleCallMaxDepsSize, "dep size is over allowed size");
    distributionInProgress[sourceProjectID] += 1;
 
    uint256 remaining = undistributedAmounts[requestID];
    uint256 singleDepShare = sponsorRequestAmounts[requestID] * (100 - projectOwnerWeight) / 100 / projectDependencies[sourceProjectID].length;
    for (uint i = fromDepIdx; i <= toDepIdx; i++) {
      uint32 depProjectID = projectDependencies[sourceProjectID][i];
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
      distributionInProgress[sourceProjectID] -= 1;
    }
  }

  function updateDeps(
    uint32 projectID,
    uint32[] calldata deps,
    bool isReplace
  ) external override onlyOracle onlyEnabled {
    require(deps.length <= singleCallMaxDepsSize, "dep size is over allowed size");
    require(distributionInProgress[projectID] == 0, "sponsorship distribution in progress for project");

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
  function updateMigrationAddress(uint32 projectID, address mAddr) public onlyProjectOwner(projectID) {
    fundMigrations[projectID] = mAddr;
  }

  // Transfer locked fund in case of contract migration.
  function migrateFunds(uint32 requestID) public payable onlyOwner {
    require(disabled, "when contract is disabled only");
    uint32 projectID = sponsorRequests[requestID];
    require(projectID > 0, "no project for request");
    require(undistributedAmounts[requestID] > 0, "no locked fund for request");
    require(fundMigrations[projectID] != address(0), "invalid migration address");

    (bool ok, bytes memory result) = payable(payable(fundMigrations[projectID])).call{value: undistributedAmounts[requestID]}("");
    require(ok, "fund migration error");
  }
}
