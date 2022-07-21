import Web3 from "web3"
const Contract = require('web3-eth-contract');

const web3Provider = new Web3.providers.WebsocketProvider("ws://localhost:7545");
const web3 = new Web3(web3Provider); 

const OpenSourcePizzaOracle = require('./contracts/OpenSourcePizzaOracle.json');
const owner = '0xef0f564EF485aA83cdaeD5b7Dfe7784a5DD272c7'
// set provider for all later instances to use
Contract.setProvider('wss://ropsten.infura.io/ws/v3/2c77e96cffa447759bf958ee4cd8f9ad');

// const caller = "0x557FD57ca1855913e457DA28fF3E033B0c653700";
const address = "0x671BC4b1388e52f864fa182Bc1D59Cef23AaD797";
var contract = new Contract(OpenSourcePizzaOracle.abi, address);

const getGasPrice = async () => 
    await web3.eth.getGasPrice().then((averageGasPrice) => {
    return averageGasPrice
}).catch(console.error)

const gasPrice = getGasPrice()

contract!.events["RegisterEvent(uint16)"]()
    .on("connected", function (subId: any) {
        console.log("listening on event RegisterEvent");
    })
    .on("data", async function (event: any) {
        console.log(`logging event returnValues ${JSON.stringify(event.returnValues)}`);
        const { projectID } = event.returnValues
        console.log(`projectID: ${projectID}`)
        const dummyAddress = '0xef0f564EF485aA83cdaeD5b7Dfe7784a5DD272f9'

        try {
            console.log('Trying...')
            JSON.stringify(contract.methods, undefined, 4)
            contract.methods["replyRegister(uint16,address)"](projectID,dummyAddress).send({
                from: owner,
                gasPrice,
                gas: Math.ceil(1.2 * await contract.methods["replyRegister(uint16,address)"]
                (projectID, dummyAddress).estimateGas({from: owner})),
            }).then(function (receipt: any) {
                console.log('Success: ', receipt)
                return receipt;
            }).catch((err: any) => {
                console.error(err);
            });
        } catch (e) {
            console.log(e);
        }
    });