// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./OSPOracle.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract OpenSourcePizza is OSPOracleClient {
  bool public disabled = true;

  uint8 public projectOwnerWeight = 50;

  mapping(uint16 => uint16[]) public projectDependencies;

  mapping(uint16 => address) public projectOwners;

  /// requestID to projectID mapping.
  mapping(uint16 => uint16) public sponsorRequests;
  /// requestID to total sponsor amount mapping.
  mapping(uint16 => uint256) public sponsorRequestAmounts;
  /// requestID to remaining undistributed amount mapping.
  mapping(uint16 => uint256) public undistributedAmounts;

  mapping(uint16 => uint256) public distribution;

  /// Addresses for locked project fund to be transferred out in case of contract migration.
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

  function updateOracle(address oc) override public onlyOwner {
    oracle = oc;
  }

  function disableContract() public onlyOwner {
    disabled = true;
  }

  function enableContract() public onlyOwner {
    require(oracle != address(0));
    disabled = false;
  }

  function register(uint16 projectID) public onlyEnabled {
    requestRegisterFromOracle(projectID);
  }

  function donateToProject(uint16 projectID, uint16 requestID) public payable onlyEnabled {
    require(msg.value > 0);
    require(sponsorRequests[requestID] == uint16(0));
    require(sponsorRequestAmounts[requestID] == uint16(0));
    require(undistributedAmounts[requestID] == uint16(0));

    sponsorRequests[requestID] = projectID;
    sponsorRequestAmounts[requestID] = msg.value;
    undistributedAmounts[requestID] = msg.value;
    requestDonateFromOracle(requestID);
  }

  function redeem(uint16 projectID) public payable onlyEnabled {
    require(projectOwners[projectID] == msg.sender);
    require(distribution[projectID] > 0);

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
  /// @param fromDepIdx the starting index of the dependent projectID to distribute the fund to
  /// @param toDepIdx the ending index of the dependent projectID to distribute the fund to
  function distribute(uint16 requestID, uint16 split, uint fromDepIdx, uint toDepIdx) public override onlyOracle onlyEnabled {
    // Make sure there's undistributed fund for this sponsor request.
    require(sponsorRequests[requestID] > 0);
    require(sponsorRequestAmounts[requestID] > 0);
    require(undistributedAmounts[requestID] > 0);

    uint16 sourceProjectID = sponsorRequests[requestID];
    if (split > 0) {
      // When this function is called multiple times for a single request.
      // Checks when this function is called for multiple times for a single sponsorship request.
      // Make sure the distribution has valid dependent receivers.
      require(projectDependencies[sponsorRequests[requestID]].length <= toDepIdx);
    } else {
      // Distribute among the entire dependency list.
      fromDepIdx = 0;
      toDepIdx = projectDependencies[sourceProjectID].length;
    }

    // Distribute to maximum 100 dependent projects in a single transaction.
    require(toDepIdx - fromDepIdx <= 100);
 
    uint256 remaining = undistributedAmounts[requestID];
    for (uint i = fromDepIdx; i < toDepIdx; i++) {
      uint256 singleDepShare = sponsorRequestAmounts[requestID] / split / (toDepIdx - fromDepIdx);
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
    if (toDepIdx == projectDependencies[sourceProjectID].length) {
      // Give source project the remaining fund, only if distribution among dependents are successful.
      (bool ok, uint256 newBalance) = SafeMath.tryAdd(distribution[sourceProjectID], remaining);
      require(ok, "distribute remaining balance error");
      distribution[sourceProjectID] = newBalance;

      // Reset request params.
      sponsorRequests[requestID] = 0;
      sponsorRequestAmounts[requestID] = 0;
      undistributedAmounts[requestID] = 0;
    }
  }

  function updateDeps(
    uint16 projectID,
    uint16[] calldata deps,
    bool isReplace
  ) external override onlyOracle onlyEnabled {
    require(deps.length <= 100);

    // Replace dependencies.
    if (isReplace) {
      projectDependencies[projectID] = deps;
      return;
    }

    // Append to existing dependencies
    for (uint i = 0; i < deps.length; i++) {
      projectDependencies[projectID].push(deps[i]);
    }
  }

  // Set up migration addresses for locked fund to be transferred out.
  function updateMigrationAddress(uint16 projectID, address mAddr) public {
    require(projectOwners[projectID] == msg.sender);

    fundMigrations[projectID] = mAddr;
  }

  // Transfer locked fund in case of contract migration.
  function migrateFunds(uint16 projectID) public onlyOwner {
    require(disabled);
    require(distribution[projectID] > 0);
    require(fundMigrations[projectID] != address(0));

    (bool ok, bytes memory result) = payable(fundMigrations[projectID]).call{value: distribution[projectID]}("");
    require(ok, "fund migration error");
  }
}
