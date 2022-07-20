// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../contracts/OpenSourcePizza.sol";
import "../contracts/OpenSourcePizzaOracle.sol";

import "https://github.com/GNSPS/solidity-bytes-utils/blob/master/contracts/BytesLib.sol";

contract OpenSourcePizzaTest1 is OpenSourcePizza {
  using BytesLib for bytes;

  address acc_contract_owner;
  /// acc_oracle is the test account that we use to mock the calls from oracle in this test.
  address acc_oracle;
  /// mock_oracle is an OpenSourcePizzaOracle instance.
  address mock_oracle;
  address acc_project_owner;
  address acc_sponsor;

  /// #sender: account-1
  function beforeAll() public {
    acc_contract_owner = TestsAccounts.getAccount(0);

    acc_oracle = TestsAccounts.getAccount(1);
    OpenSourcePizzaOracle oc = new OpenSourcePizzaOracle(address(this));
    mock_oracle = address(oc);

    acc_project_owner = TestsAccounts.getAccount(2);
    acc_sponsor = TestsAccounts.getAccount(3);
  }

  function testOwner() public {
    Assert.equal(owner, acc_contract_owner, "owner should be equal to account 0");
  }

  // TODO: test updateOracle with non owner address should fail

  // TODO: test enable contract should fail here due to missing oracle

  function testUpdateOracle() public {
    updateOracle(acc_oracle);
    Assert.ok(true, "update oracle by owner should succeed");
    Assert.equal(oracle, acc_oracle, "oracle should be equal to account 1");
  }

  // TODO: test registerProject should fail here due to disabled contract

  function testEnableContract() public {
    enableContract();
    Assert.equal(disabled, false, "enable contract by owner should succeed");
  }

  // TODO: test update single call max deps size with non oracle should fail

  function testUpdateSingleCallMaxDepsSize() public {
    updateSingleCallMaxDepsSize(3);
    Assert.equal(singleCallMaxDepsSize, 3, "max deps size should be 3");
  }

  // TODO: test registerProject with non oracle address should fail

  /// #sender: account-1
  function testRegisterProject() public {
    registerProject(123, acc_project_owner);
    Assert.equal(projectOwners[123], acc_project_owner, "project 123 should map to account 2");
  }

  function testInitialBalance() public {
    Assert.equal(address(this).balance, 0, "balance should be 0 initially");
  }

  // TODO: test updateDeps with non oracle address should fail

  uint16[] deps;
  /// #sender: account-1
  function testUpdateDepsReplace() public {
    deps.push(uint16(234));
    deps.push(uint16(235));

    (bool success, bytes memory result) = address(this).delegatecall(abi.encodeWithSignature("updateDeps(uint16,uint16[],bool)", 123, deps, false));
    Assert.ok(success, "oracle calls updateDeps should succeed");
    Assert.equal(projectDependencies[123].length, 2, "project 123 has 2 dependencies");
    Assert.equal(projectDependencies[123][0], 234, "project 123 has first dep 234");
    Assert.equal(projectDependencies[123][1], 235, "project 123 has second dep 235");
  }

  /// #sender: account-1
  function testUpdateDepsAppend() public {
    deps.pop();
    deps.pop();
    deps.push(uint16(236));

    (bool success, bytes memory result) = address(this).delegatecall(abi.encodeWithSignature("updateDeps(uint16,uint16[],bool)", 123, deps, false));
    Assert.ok(success, "oracle calls updateDeps should succeed");
    Assert.equal(projectDependencies[123].length, 3, "project 123 has 3 dependencies");
    Assert.equal(projectDependencies[123][0], 234, "project 123 has first dep 234");
    Assert.equal(projectDependencies[123][1], 235, "project 123 has second dep 235");
    Assert.equal(projectDependencies[123][2], 236, "project 123 has third dep 236");
  }

  // TODO: test updateDeps with non oracle address should fail


  /// update oracle to an actually oracle instance for donateToProject test.
  function setMockOracle() public {
    updateOracle(address(mock_oracle));
  }

  /// #sender: account-3
  /// #value: 600
  function testDonateToProject() public payable {
    require(acc_sponsor.balance > 600, "sponsor account should have sufficient fund");

    (bool success, bytes memory result) = address(this).call{gas:500000, value:600}(abi.encodeWithSignature("donateToProject(uint16,uint16)", 123, 0));
    Assert.equal(success, true, "donate to project by a random sponsor should succeed");
    Assert.equal(address(this).balance, 600, "balance should be updated to 600");
  }

  /// reset oracle to the test account for mocking the following tests called by the oracle.
  function resetOracle() public {
    updateOracle(acc_oracle);
  }

    /// #sender: account-1
  function testDistributeCall1() public {
    require(sponsorRequestAmounts[0] == 600, "request should have 600 wei to be distributed");
  
    distribute(0, 0, 1);
    Assert.equal(distribution[234], 100, "project dep should be distributed 100 wei");
    Assert.equal(distribution[235], 100, "project dep should be distributed 100 wei");
    Assert.equal(distribution[236], 0, "remaining project dep should not have fund distributed");
    Assert.equal(distribution[123], 0, "source project should not have fund distributed");
  }

  /// #sender: account-1
  function testDistributeCall2() public {
    distribute(0, 2, 2);
    Assert.equal(distribution[234], 100, "project dep should be distributed 100 wei");
    Assert.equal(distribution[235], 100, "project dep should be distributed 100 wei");
    Assert.equal(distribution[236], 100, "project dep should be distributed 100 wei");
    Assert.equal(distribution[123], 300, "source project should be distributed 300 wei");
  }
}
