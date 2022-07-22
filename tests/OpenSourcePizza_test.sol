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
  address acc_project1_owner;
  address acc_sponsor;
  address acc_project2_owner;

  /// #sender: account-1
  function beforeAll() public {
    acc_contract_owner = TestsAccounts.getAccount(0);

    acc_oracle = TestsAccounts.getAccount(1);
    OpenSourcePizzaOracle oc = new OpenSourcePizzaOracle(address(this));
    mock_oracle = address(oc);

    acc_project1_owner = TestsAccounts.getAccount(2);
    acc_sponsor = TestsAccounts.getAccount(3);
    acc_project2_owner = TestsAccounts.getAccount(4);
  }

  function testOwner() public {
    Assert.equal(owner, acc_contract_owner, "owner should be equal to account 0");
  }

  /// test onlyOwner modifier on updateOracle
  /// #sender: account-1
  function testUpdateOracleFail() public {
    (bool success, bytes memory result) = address(this).delegatecall(abi.encodeWithSignature("updateOracle(address)", acc_oracle));
    Assert.equal(success, false, "updateOracle called by a non owner account should fail");
    string memory reason = abi.decode(result.slice(4, result.length - 4), (string));
    Assert.equal(reason, "owner only", "Failed with unexpected reason");
  }

  /// test oracle requirement on enableContract
  function testEnableContractFail() public {
    (bool success, bytes memory result) = address(this).delegatecall(abi.encodeWithSignature("enableContract()"));
    Assert.equal(success, false, "enableContract without an oracle should fail");
    string memory reason = abi.decode(result.slice(4, result.length - 4), (string));
    Assert.equal(reason, "oracle is missing", "Failed with unexpected reason");
  }

  function testUpdateOracle() public {
    updateOracle(acc_oracle);
    Assert.ok(true, "update oracle by owner should succeed");
    Assert.equal(oracle, acc_oracle, "oracle should be equal to account 1");
  }

  /// test enabled requirement for registerProject
  /// #sender: account-1
  function testRegisterProjectFail1() public {
    (bool success, bytes memory result) = address(this).delegatecall(abi.encodeWithSignature("registerProject(uint16,address)", 1, acc_project1_owner));
    Assert.equal(success, false, "registerProject when contract is disabled should fail");
    string memory reason = abi.decode(result.slice(4, result.length - 4), (string));
    Assert.equal(reason, "contract is disabled", "Failed with unexpected reason");
  }

  /// test enabled requirement for donateToProject
  function testDonateToProjectFail() public {
    (bool success, bytes memory result) = address(this).delegatecall(abi.encodeWithSignature("donateToProject(uint16,uint16)", 1, 0));
    Assert.equal(success, false, "donateToProject when contract is disabled should fail");
    string memory reason = abi.decode(result.slice(4, result.length - 4), (string));
    Assert.equal(reason, "contract is disabled", "Failed with unexpected reason");
  }

  function testEnableContract() public {
    enableContract();
    Assert.equal(disabled, false, "enable contract by owner should succeed");
  }

  /// test onlyOwner modifier on registerProject
  function testRegisterProjectFail2() public {
    (bool success, bytes memory result) = address(this).delegatecall(abi.encodeWithSignature("registerProject(uint16,address)", 1, acc_project1_owner));
    Assert.equal(success, false, "registerProject by a non oracle account should fail");
    string memory reason = abi.decode(result.slice(4, result.length - 4), (string));
    Assert.equal(reason, "oracle only", "Failed with unexpected reason");
  }

  /// #sender: account-1
  function testRegisterProject1() public {
    registerProject(1, acc_project1_owner);
    Assert.equal(projectOwners[1], acc_project1_owner, "project 1 should map to account 2");
  }

  /// test onlyOwner modifier on updateSingleCallMaxDepsSize
  /// #sender: account-1
  function testUpdateSingleCallMaxDepsSizeFail() public {
    (bool success, bytes memory result) = address(this).delegatecall(abi.encodeWithSignature("updateSingleCallMaxDepsSize(uint256)", 2));
    Assert.equal(success, false, "updateSingleCallMaxDepsSize called by a non owner account should fail");
    string memory reason = abi.decode(result.slice(4, result.length - 4), (string));
    Assert.equal(reason, "owner only", "Failed with unexpected reason");
  }

  function testUpdateSingleCallMaxDepsSize() public {
    updateSingleCallMaxDepsSize(2);
    Assert.equal(singleCallMaxDepsSize, 2, "max deps size should be 2");
  }

  function testInitialBalance() public {
    Assert.equal(address(this).balance, 0, "balance should be 0 initially");
  }

  /// test onlyOracle modifier on updateDeps
  uint16[] deps1;
  function testUpdateDepsReplaceFail1() public {
    deps1.push(uint16(123));
    deps1.push(uint16(124));
    deps1.push(uint16(125));

    (bool success, bytes memory result) = address(this).delegatecall(abi.encodeWithSignature("updateDeps(uint16,uint16[],bool)", 1, deps1, false));
    Assert.equal(success, false, "updateDeps called by a non oracle account should fail");
    string memory reason = abi.decode(result.slice(4, result.length - 4), (string));
    Assert.equal(reason, "oracle only", "Failed with unexpected reason");
  }

  /// test deps size requirement on updateDeps
  /// #sender: account-1
  function testUpdateDepsReplaceFail2() public {
    (bool success, bytes memory result) = address(this).delegatecall(abi.encodeWithSignature("updateDeps(uint16,uint16[],bool)", 1, deps1, false));
    Assert.equal(success, false, "updateDeps exceeding deps max size should fail");
    string memory reason = abi.decode(result.slice(4, result.length - 4), (string));
    Assert.equal(reason, "dep size is over allowed size", "Failed with unexpected reason");
  }

  /// test updateDeps by replace
  /// #sender: account-1
  function testUpdateDepsReplace0() public {
    deps1.pop(); // deps list is now of length 2.

    (bool success, bytes memory result) = address(this).delegatecall(abi.encodeWithSignature("updateDeps(uint16,uint16[],bool)", 1, deps1, false));
    Assert.ok(success, "oracle calls updateDeps externally should succeed");
    Assert.equal(projectDependencies[1].length, 2, "project 1 has 2 dependencies");
    Assert.equal(projectDependencies[1][0], 123, "project 1 has first dep 123");
    Assert.equal(projectDependencies[1][1], 124, "project 1 has second dep 124");
  }

  /// test updateDeps by appending to existing deps
  /// #sender: account-1
  function testUpdateDepsAppend0() public {
    deps1.pop();
    deps1.pop();
    deps1.push(uint16(125)); // deps list now consist of only a single element.

    (bool success, bytes memory result) = address(this).delegatecall(abi.encodeWithSignature("updateDeps(uint16,uint16[],bool)", 1, deps1, false));
    Assert.ok(success, "oracle calls updateDeps to append externally should succeed");
    Assert.equal(projectDependencies[1].length, 3, "project 1 has 3 dependencies");
    Assert.equal(projectDependencies[1][0], 123, "project 1 has first dep 123");
    Assert.equal(projectDependencies[1][1], 124, "project 1 has second dep 124");
    Assert.equal(projectDependencies[1][2], 125, "project 1 has third dep 125");
  }

  /// test updateDeps in single function call
  uint16[] deps2;
  /// #sender: account-1
  function testUpdateDepsReplace1() public {
    deps2.push(uint16(234));
    deps2.push(uint16(235));

    (bool success, bytes memory result) = address(this).delegatecall(abi.encodeWithSignature("updateDeps(uint16,uint16[],bool)", 2, deps2, false));
    Assert.ok(success, "oracle calls updateDeps to replace externally should succeed");
    Assert.equal(projectDependencies[2].length, 2, "project 2 has 2 dependencies");
    Assert.equal(projectDependencies[2][0], 234, "project 2 has first dep 234");
    Assert.equal(projectDependencies[2][1], 235, "project 2 has second dep 235");
  }

  /// test registerProject after project dependencies is updated
  /// #sender: account-1
  function testRegisterProject2() public {
    registerProject(2, acc_project2_owner);
    Assert.equal(projectOwners[2], acc_project2_owner, "project 2 should map to account 4");
  }

  /// update oracle to an actual oracle instance for donateToProject test.
  function setMockOracle() public {
    updateOracle(address(mock_oracle));
  }

  /// #sender: account-3
  /// #value: 600
  function testDonateToProject1Request0() public payable {
    donateToProject(1, 0);
    Assert.equal(address(this).balance, 600, "balance should be updated to 600");
  }

  /// test requestID requirement on donateToProject
  /// #sender: account-3
  /// #value: 123
  function testDonateToProject1Request0Fail1() public payable {
    (bool success, bytes memory result) = address(this).delegatecall(abi.encodeWithSignature("donateToProject(uint16,uint16)", 1, 0));
    Assert.equal(success, false, "donate with occupied requestID should fail");
    string memory reason = abi.decode(result.slice(4, result.length - 4), (string));
    Assert.equal(reason, "existing sponsorship request", "Failed with unexpected reason");
  }

  /// test value requirement on donateToProject
  /// #sender: account-3
  /// #value: 0
  function testDonateToProject1Request0Fail2() public payable {
    (bool success, bytes memory result) = address(this).delegatecall(abi.encodeWithSignature("donateToProject(uint16,uint16)", 1, 1));
    Assert.equal(success, false, "donate with no value should fail");
    string memory reason = abi.decode(result.slice(4, result.length - 4), (string));
    Assert.equal(reason, "no fund to donate", "Failed with unexpected reason");
  }

  /// test donate to the same project with a different requestID
  /// #sender: account-3
  /// #value: 123
  function testDonateToProject1Request1() public payable {
    donateToProject(1, 1);
    Assert.equal(address(this).balance, 846, "balance should be updated to 846");
    // balance of "this" contract is 600+123+123 because the above failed test transferred fund to "this",
    // the call will be reverted in the actual contract instance and the balance after a failed donateToProject()
    // call should not change.
  }

  /// reset oracle to the test account for mocking the following tests called by the oracle.
  function resetOracle() public {
    updateOracle(acc_oracle);
  }

  /// test onlyOracle modifier on distribute
  function testDistributeFail() public {
    Assert.equal(sponsorRequestAmounts[0], 600, "request should have 600 wei to be distributed");
  
    (bool success, bytes memory result) = address(this).delegatecall(abi.encodeWithSignature("distribute(uint16,uint256,uint256)", 0, 0, 1));
    Assert.equal(success, false, "distribute by a non oracle account should fail");
    string memory reason = abi.decode(result.slice(4, result.length - 4), (string));
    Assert.equal(reason, "oracle only", "Failed with unexpected reason");
  }

  /// test distribute part of the deps with the first function call
  /// #sender: account-1
  function testDistributeRequest0Call1() public {
    Assert.equal(sponsorRequestAmounts[0], 600, "request should have a total of 600 wei to be distributed");
  
    distribute(0, 0, 1);
    Assert.equal(distribution[123], 100, "project dep should be distributed 100 wei");
    Assert.equal(distribution[124], 100, "project dep should be distributed 100 wei");
    Assert.equal(distribution[125], 0, "remaining project dep should not have fund distributed");
    Assert.equal(distribution[1], 0, "source project should not have fund distributed");
    Assert.equal(undistributedAmounts[0], 400, "request should have a remaining of 400 wei to be distributed");
  }

  /// test deps size requirement on distribute
  /// deps list has 3 entries while allowed deps size is 2
  /// #sender: account-1
  function testDistributeRequest1Fail() public {
    Assert.equal(sponsorRequestAmounts[1], 123, "request should have a total of 123 wei to be distributed");
    Assert.equal(undistributedAmounts[1], 123, "request should have a remaining of 123 wei to be distributed");

    (bool success, bytes memory result) = address(this).delegatecall(abi.encodeWithSignature("distribute(uint16,uint256,uint256)", 1, 0, 0));
    Assert.equal(success, false, "distribute over allowed deps size should fail");
    string memory reason = abi.decode(result.slice(4, result.length - 4), (string));
    Assert.equal(reason, "dep size is over allowed size", "Failed with unexpected reason");
  }

  function updateMaxDepsSize() public {
    updateSingleCallMaxDepsSize(3);
  }

  /// test distribution in progress requirement on updateDeps
  /// updateDeps should fail when there's a distribution in progress for the project
  /// #sender: account-1
  function testUpdateDepsFail() public {
    (bool success, bytes memory result) = address(this).delegatecall(abi.encodeWithSignature("updateDeps(uint16,uint16[],bool)", 1, deps2, true));
    Assert.equal(success, false, "updateDeps when there's distribution in progress should fail");
    string memory reason = abi.decode(result.slice(4, result.length - 4), (string));
    Assert.equal(reason, "sponsorship distribution in progress for project", "Failed with unexpected reason");
  }

  /// test distribute fund for another request for the same project
  /// when there is another distribution in progress
  /// #sender: account-1
  function testDistributeRequest1() public {
    Assert.equal(sponsorRequestAmounts[1], 123, "request should have a total of 123 wei to be distributed");
    Assert.equal(undistributedAmounts[1], 123, "request should have a remaining of 123 wei to be distributed");

    distribute(1, 0, 0); // distribute to the entire dependencies list.
    
    Assert.equal(distribution[123], 120, "project dep should be distributed 20 wei"); // 100 + (123 * 50 / 100 / 3) = 120
    Assert.equal(distribution[124], 120, "project dep should be distributed 20 wei"); // 100 + (123 * 50 / 100 / 3) = 120
    Assert.equal(distribution[125], 20, "project dep should be distributed 20 wei");  // 0 + (123 * 50 / 100 / 3) = 20
    Assert.equal(distribution[1], 63, "source project should be distributed 63 wei"); // 123 - 20 - 20 - 20 = 63
    Assert.equal(undistributedAmounts[1], 0, "request should have no remaining fund to be distributed");
  }

  /// test distribute the remaining part of the deps with the second function call
  /// #sender: account-1
  function testDistributeRequest0Call2() public {
    Assert.equal(sponsorRequestAmounts[0], 600, "request should have a total of 600 wei to be distributed");

    distribute(0, 2, 2);
    Assert.equal(distribution[123], 120, "project dep should not have fund distributed");
    Assert.equal(distribution[124], 120, "project dep should not have fund distributed");
    Assert.equal(distribution[125], 120, "project dep should be distributed 100 wei");  // 20 + 100 = 120
    Assert.equal(distribution[1], 363, "source project should be distributed 300 wei"); // 63 + 300 = 363
    Assert.equal(undistributedAmounts[0], 0, "request should have no remaining fund to be distributed");
  }

  /// test onlyProjectOwner modifier on redeem
  function testRedeemFail() public {
    (bool success, bytes memory result) = address(this).delegatecall(abi.encodeWithSignature("redeem(uint16)", 1));
    Assert.equal(success, false, "redeem by an account other than the project owner should fail");
    string memory reason = abi.decode(result.slice(4, result.length - 4), (string));
    Assert.equal(reason, "project owner only", "Failed with unexpected reason");
  }

  /// #sender: account-2
  function testRedeem() public {
    uint256 projectOwnerBalance = acc_project1_owner.balance;
    redeem(1);
    Assert.equal(projectOwnerBalance + 363, acc_project1_owner.balance, "project owner should receive distributed fund");
  }
}
