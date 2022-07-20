// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../contracts/OpenSourcePizza.sol";
import "../contracts/OpenSourcePizzaOracle.sol";

import "https://github.com/GNSPS/solidity-bytes-utils/blob/master/contracts/BytesLib.sol";

contract OpenSourcePizzaOracleTest is OpenSourcePizzaOracle {
  using BytesLib for bytes;

  address acc_contract_owner;
  address acc_caller;

  constructor () OpenSourcePizzaOracle(TestsAccounts.getAccount(1)) {}

  /// #sender: account-1
  function beforeAll() public {
    acc_contract_owner = TestsAccounts.getAccount(0);
    acc_caller = TestsAccounts.getAccount(1);
  }

  function testOwner() public {
    Assert.equal(owner, acc_contract_owner, "owner should be equal to account 0");
  }

  /// #sender: account-1
  function testUpdateCallerFail() public {
    (bool success, bytes memory result) = address(this).delegatecall(abi.encodeWithSignature("updateCaller(address)", acc_caller));
    Assert.equal(success, false, "updateCaller called by a non owner account should fail");
    string memory reason = abi.decode(result.slice(4, result.length - 4), (string));
    Assert.equal(reason, "owner only", "Failed with unexpected reason");
  }

  function testUpdateCaller() public {
    updateCaller(acc_caller);
    Assert.ok(true, "update caller by owner should succeed");
    Assert.equal(caller, acc_caller, "caller should be equal to account 1");
  }
}
