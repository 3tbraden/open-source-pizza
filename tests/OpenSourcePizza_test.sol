// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../contracts/OpenSourcePizza.sol";
import "../contracts/OpenSourcePizzaOracle.sol";

contract OpenSourcePizzaTest1 is OpenSourcePizza(TestsAccounts.getAccount(2)) {
  address acc0;
  address acc1;

  function beforeAll() public {
    acc0 = TestsAccounts.getAccount(0);
    acc1 = TestsAccounts.getAccount(1);

    updateOracle(acc1);
  }

  function testOwner() public {
    Assert.equal(owner, acc0, "owner should be equal to account 0");
  }

  function testUpdateOracle() public {
    Assert.equal(oracle, acc1, "oracle should be equal to account 1");
  }
}

contract OpenSourcePizzaTest2 is OpenSourcePizza(TestsAccounts.getAccount(1)) {
  address acc0;
  address acc1;
  address acc2;

  /// #sender: account-1
  function beforeAll() public {
    acc0 = TestsAccounts.getAccount(0);
    acc1 = TestsAccounts.getAccount(1);
    acc2 = TestsAccounts.getAccount(2);

    registerProject(123, acc2);
  }

  function testRegisterProject() public {
    Assert.equal(projectOwners[123], acc2, "project 123 should map to account 2");
  }
}

