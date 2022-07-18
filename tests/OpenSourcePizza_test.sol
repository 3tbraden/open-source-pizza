// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../contracts/OpenSourcePizza.sol";
import "../contracts/OpenSourcePizzaOracle.sol";

contract OpenSourcePizzaTest1 is OpenSourcePizza {
  address acc0;
  address acc1;
  address acc2;

  function beforeAll() public {
    acc0 = TestsAccounts.getAccount(0);
    acc1 = TestsAccounts.getAccount(1);
    acc2 = TestsAccounts.getAccount(2);
  }

  function testOwner() public {
    Assert.equal(owner, acc0, "owner should be equal to account 0");
  }

  function testUpdateOracleAction() public {
    updateOracle(acc1);
  }

  function testUpdateOracleResult() public {
    Assert.equal(oracle, acc1, "oracle should be equal to account 1");
  }

  // TODO: test enable contract should fail here due to missing oracle
  // TODO: test registerProject should fail here due to disabled contract

  function testEnableContractAction() public {
    enableContract();
  }

  /// #sender: account-1
  function testRegisterProjectAction() public {
    registerProject(123, acc2);
  }

  function testRegisteredProjectResult() public {
    Assert.equal(projectOwners[123], acc2, "project 123 should map to account 2");
  }
}
