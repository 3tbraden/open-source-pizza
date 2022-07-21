const Contract = require('web3-eth-contract');

const OpenSourcePizzaOracle = require('./contracts/OpenSourcePizzaOracle.json');

// set provider for all later instances to use
Contract.setProvider('wss://ropsten.infura.io/ws/v3/2c77e96cffa447759bf958ee4cd8f9ad');

// const caller = "0x557FD57ca1855913e457DA28fF3E033B0c653700";
const address = "0x671BC4b1388e52f864fa182Bc1D59Cef23AaD797";
var contract = new Contract(OpenSourcePizzaOracle.abi, address);

contract!.events["RegisterEvent(uint16)"]()
    .on("connected", function (subId: any) {
        console.log("listening on event RegisterEvent");
    })
    .on("data", async function (event: any) {
        console.log(`logging event returnValues ${JSON.stringify(event.returnValues)}`);
    })
