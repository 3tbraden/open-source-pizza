"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const web3_1 = __importDefault(require("web3"));
const Contract = require('web3-eth-contract');
const web3Provider = new web3_1.default.providers.HttpProvider(`https://ropsten.infura.io/v3/2c77e96cffa447759bf958ee4cd8f9ad`);
const web3 = new web3_1.default(web3Provider);
const OpenSourcePizzaOracle = require('./contracts/OpenSourcePizzaOracle.json');
const OpenSourcePizza = require('./contracts/OpenSourcePizza.json');
const owner = '0xef0f564EF485aA83cdaeD5b7Dfe7784a5DD272c7';
const privateKey = '0x1be9fb140547fbc23da661d283db717caf265a97bae49e248206023cc7e164fa';
// set provider for all later instances to use
Contract.setProvider('wss://ropsten.infura.io/ws/v3/2c77e96cffa447759bf958ee4cd8f9ad');
// const caller = "0x557FD57ca1855913e457DA28fF3E033B0c653700";
const oracleAddress = "0x146afe4c90a2be19b3784351c8f36357b27c8b8d";
const mainPizzaAddress = '0xc6c0089249de98f5459cea44cab3deebc3ef3fce';
var contract = new Contract(OpenSourcePizzaOracle.abi, oracleAddress);
var pizzaContract = new Contract(OpenSourcePizza.abi, mainPizzaAddress);
async function main() {
    const singleCallMaxDepsSize = await pizzaContract.methods.singleCallMaxDepsSize().call();
    console.log(singleCallMaxDepsSize);
}
// main()           
contract.events["RegisterEvent(uint16)"]()
    .on("connected", function (subId) {
    console.log("listening on event RegisterEvent");
})
    .on("data", async function (event) {
    console.log(`logging event returnValues ${JSON.stringify(event.returnValues)}`);
    const { projectID } = event.returnValues;
    try {
        console.log('Trying to call reply register...');
        console.log(contract.methods);
        const ownerAddress = 0;
        // need to grab the address of the project owner
        var data = contract.methods["replyRegister(uint16,address)"](projectID, ownerAddress).encodeABI();
        const options = {
            to: oracleAddress,
            data: data,
            gas: '100000',
        };
        const signedTransaction = await web3.eth.accounts.signTransaction(options, privateKey);
        const transactionReceipt = await web3.eth.sendSignedTransaction(signedTransaction.rawTransaction);
        console.log(transactionReceipt);
    }
    catch (e) {
        console.log(e);
    }
});
// Donate Event
contract.events["DonateEvent(uint16)"]()
    .on("connected", function (subId) {
    console.log("listening on event DonateEvent");
})
    .on("data", async function (event) {
    console.log('DonateEvent event received...');
    const { requestID } = event.returnValues;
    const projectID = await pizzaContract.methods.sponsorRequests(requestID).call();
    // Here, we call github to grab the dependencies. Currently using a dummy array
    const dummyDependenciesFromGithub = [1, 2, 3];
    // Iterates through the dependencies of the project and returns only the ones that exist on our blockchain
    const extractOnChainProjects = async () => {
        const arr = [];
        await Promise.all(dummyDependenciesFromGithub.map(async (projectID) => {
            const result = await pizzaContract.methods.projectOwners(projectID).call();
            result != 0 && arr.push(projectID);
        }));
        return arr;
    };
    const resultToReturn = await extractOnChainProjects();
    // Grabbing the list of dependencies for the project on chain ---> mapping(uint16 => uint16[]) public projectDependencies;
    const getExistingDependencies = async () => {
        const res = [];
        var i = 0;
        while (true) {
            try {
                const result = await pizzaContract.methods.projectDependencies(projectID, i).call();
                res.push(result);
                i += 1;
            }
            catch (e) {
                return res;
            }
        }
    };
    const existingDependenciesOnChain = await getExistingDependencies();
    /* Now, we check whether the dependencies have changed to evaluate the isReplace boolean.
       If the lengths are not the same, they have changed, or if they are different at any given index, they have changed */
    var hasChanged = false;
    if (resultToReturn.length != existingDependenciesOnChain.length) {
        hasChanged = true;
    }
    else {
        for (var i = 0; i < resultToReturn.length; i++) {
            if (resultToReturn[i] != existingDependenciesOnChain[i]) {
                hasChanged = true;
                break;
            }
        }
    }
    try {
        console.log('Trying to call replyDonateUpdateDeps...');
        // need to grab the address of the project owner
        var data = contract.methods["replyDonateUpdateDeps(uint16,uint16[],bool)"](projectID, resultToReturn, hasChanged).encodeABI();
        const options = {
            to: oracleAddress,
            data: data,
            gas: '100000',
        };
        const signedTransaction = await web3.eth.accounts.signTransaction(options, privateKey);
        const transactionReceipt = await web3.eth.sendSignedTransaction(signedTransaction.rawTransaction);
        console.log(transactionReceipt);
    }
    catch (e) {
        console.log(e);
    }
    // Now to call replyDonateDistribute
    try {
        const singleCallMaxDepsSize = await pizzaContract.methods.singleCallMaxDepsSize().call();
        console.log(singleCallMaxDepsSize);
    }
    catch (err) {
        console.log(err);
    }
});
