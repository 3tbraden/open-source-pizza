// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./OSPOracle.sol";

contract OpenSourcePizza is OSPOracleClient {
  address public _owner;
  address public _oracle;

  uint public projectOwnerWeight = 50;

  mapping(uint16 => uint16[]) public projectDependencies;

  mapping(uint16 => address) public projectOwners;

  mapping(uint16 => uint256) public undistributedFunds;
  mapping(uint16 => uint256) public distribution;

  modifier onlyOracle {
    require(msg.sender == _oracle);
    _;
  }

  constructor(address oracle) OSPOracleClient(oracle) {
    _owner = msg.sender;
    _oracle = oracle;
  }

  function register(uint16 projectID) external {
    requestRegisterFromOracle(projectID);
  }

  function donateToProject(uint16 projectID) external payable {
    require(msg.value > 0);

    undistributedFunds[projectID] += msg.value;
    requestDonateFromOracle(projectID);
  }

  function redeem(uint16 projectID) external payable {
    require(projectOwners[projectID] == msg.sender);
    require(distribution[projectID] > 0);

    uint256 transferValue = distribution[projectID];
    // TODO: safeMath.sol
    distribution[projectID] -= transferValue ;
    payable(msg.sender).transfer(transferValue);
  }

  function registerProject(uint16 projectID, address addr) external override onlyOracle {
    projectOwners[projectID] = addr;
  }

  function distribute(uint16 projectID) public override onlyOracle {
    require(undistributedFunds[projectID] > 0);

    uint256 remaining = undistributedFunds[projectID];
    uint16[] memory dependencies = projectDependencies[projectID];
    if (dependencies.length > 0) {
      // TODO: safeMath.sol
      // Distribute among dependents first.
      uint256 dependentsShare = remaining * (1 - projectOwnerWeight) / 100;
      uint256 singleShare = dependentsShare / dependencies.length;

      for (uint i = 0; i < dependencies.length; i++) {
        distribution[dependencies[i]] += singleShare;
        remaining -= singleShare;
      }
    }
    // Give parent project the remaining fund.
    distribution[projectID] += remaining;
  }

  function updateDepsAndDistribute(uint16 projectID, uint16[] calldata deps) external override onlyOracle {
    // TODO: limit number of dependencies
    require(undistributedFunds[projectID] > 0);

    // Update dependencies.
    projectDependencies[projectID] = deps;

    distribute(projectID);
  }
}
