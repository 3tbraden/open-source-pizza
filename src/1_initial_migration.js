const OpenSourcePizza = artifacts.require("OpenSourcePizza");
const OpenSourcePizzaOracle = artifacts.require("OpenSourcePizzaOracle");

module.exports = async function (deployer) {
  deployer.deploy(OpenSourcePizza).then(function() {
    return deployer.deploy(OpenSourcePizzaOracle, OpenSourcePizza.address);
  });
};
