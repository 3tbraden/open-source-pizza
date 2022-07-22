import Web3 from "web3"
const Contract = require('web3-eth-contract');

const web3Provider = new Web3.providers.WebsocketProvider("ws://localhost:7545");
const web3 = new Web3(web3Provider); 

const OpenSourcePizzaOracle = require('./contracts/OpenSourcePizzaOracle.json');
const owner = '0xef0f564EF485aA83cdaeD5b7Dfe7784a5DD272c7'
const privateKey = '0x1be9fb140547fbc23da661d283db717caf265a97bae49e248206023cc7e164fa'
// set provider for all later instances to use
Contract.setProvider('wss://ropsten.infura.io/ws/v3/2c77e96cffa447759bf958ee4cd8f9ad');

// const caller = "0x557FD57ca1855913e457DA28fF3E033B0c653700";
const address = "0x671BC4b1388e52f864fa182Bc1D59Cef23AaD797";
var contract = new Contract(OpenSourcePizzaOracle.abi, address);

const dummyAddress = '0xef0F564ef485AA83cdaEd5B7Dfe7784A5dd272F9'

contract!.events["RegisterEvent(uint16)"]()
    .on("connected", function (subId: any) {
        console.log("listening on event RegisterEvent");
    })
    .on("data", async function (event: any) {
        console.log(`logging event returnValues ${JSON.stringify(event.returnValues)}`);
        const { projectID } = event.returnValues
        console.log(`projectID: ${projectID}`)

        try {
            console.log('Trying...')
            console.log(contract.methods)
            
            contract.methods
            .replyRegister(projectID, dummyAddress)
            .send({ from: owner }, function (err: any, res: any) {
              if (err) {
                console.log("An error occured", err)
                return
              }
              console.log("Hash of the transaction: " + res)
            })
            // const getData = contract.methods.replyRegister.getData(projectID, dummyAddress);
            // web3.eth.sendTransaction({to: address, from: owner, data: getData })
        } catch (e) {
            console.log(e);
        }
    });