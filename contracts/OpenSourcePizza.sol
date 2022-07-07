// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract OpenSourcePizza {
  address private owner;
  address private oracle;

  uint public projectOwnerWeight = 50;

  mapping(uint16 => uint16[]) public dependenciesMap;

  mapping(address => uint16) public projectOwners;

  mapping(uint16 => uint256) public undistributedFunds;
  mapping(uint16 => uint256) public distribution;

  event SignUpEvent(uint16 projectID, address addr);
  event DonateEvent(uint16 projectID);

  modifier onlyOracle {
    require(msg.sender == oracle);
    _;
  }

  constructor(address oc) {
    oracle = oc;
  }

  function requestSignUp(uint16 projectID) public {
      emit SignUpEvent(projectID, msg.sender);
  }

  function donateToProject(uint16 projectID) public payable {
    require(msg.value > 0);

    undistributedFunds[projectID] += msg.value;
    emit DonateEvent(projectID);
  }

  function redeem(uint16 projectID) public payable {
    require(projectOwners[msg.sender] == projectID);
    require(distribution[projectID] > 0);

    payable(msg.sender).transfer(distribution[projectID]);
  }

  // Oracle functionalities.
  function signUp(uint16 projectID, address addr) public onlyOracle {
    projectOwners[addr] = projectID;
  }

  function distribute(uint16 projectID) public onlyOracle {
    require(undistributedFunds[projectID] > 0);

    uint256 remaining = undistributedFunds[projectID];
    uint16[] memory dependencies = dependenciesMap[projectID];
    if (dependencies.length > 0) {
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

  function updateDepsAndDistribute(uint16 projectID, uint16[] memory dependencies) public onlyOracle {
    require(undistributedFunds[projectID] > 0);

    // TODO: update dependencies

    distribute(projectID);
  }
}
