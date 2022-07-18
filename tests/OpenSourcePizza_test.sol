// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../contracts/OpenSourcePizza.sol";
import "../contracts/OpenSourcePizzaOracle.sol";

import "https://github.com/GNSPS/solidity-bytes-utils/blob/master/contracts/BytesLib.sol";

contract OpenSourcePizzaTest1 is OpenSourcePizza {
  using BytesLib for bytes;

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

  // TODO: test updateOracle with non owner address should fail

  function testUpdateOracleResult() public {
    Assert.equal(oracle, acc1, "oracle should be equal to account 1");
  }

  // TODO: test enable contract should fail here due to missing oracle
  // TODO: test registerProject should fail here due to disabled contract

  function testEnableContractAction() public {
    enableContract();
  }

  // TODO: test registerProject with non oracle address should fail

  /// #sender: account-1
  function testRegisterProjectAction() public {
    registerProject(123, acc2);
  }

  function testRegisteredProjectResult() public {
    Assert.equal(projectOwners[123], acc2, "project 123 should map to account 2");
  }

  // TODO: test updateDeps with non oracle address should fail

  uint16[] deps;

  /// #sender: account-1
  function testUpdateDepsAction() public {
    deps.push(uint16(234));
    deps.push(uint16(235));
    deps.push(uint16(236));

    (bool success, bytes memory result) = address(this).delegatecall(abi.encodeWithSignature("updatedDeps(uint16 projectID, uint16[] calldata deps, bool isReplace)", 123, deps, false));
    Assert.ok(success, "oracle calls updateDeps should succeed");

    string memory reason = abi.decode(result.slice(4, result.length - 4), (string));
    Assert.equal(reason, "Can only be executed by the manager", reason);
  }
}
