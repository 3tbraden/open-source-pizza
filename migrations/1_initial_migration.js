const OpenSourcePizzaOracle = artifacts.require("OpenSourcePizzaOracle");
const OpenSourcePizza = artifacts.require("OpenSourcePizza");

module.exports = function (deployer) {
  deployer.deploy(OpenSourcePizzaOracle);
  deployer.deploy(OpenSourcePizza);
};
