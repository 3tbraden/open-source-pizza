import Web3 from "web3"
import { getAddress, getDependencies } from "./github-client";
const Contract = require('web3-eth-contract');

const web3Provider = new Web3.providers.HttpProvider(`https://ropsten.infura.io/v3/2c77e96cffa447759bf958ee4cd8f9ad`);
const web3 = new Web3(web3Provider); 

const OpenSourcePizzaOracle = require('./contracts/OpenSourcePizzaOracle.json');
const OpenSourcePizza = require('./contracts/OpenSourcePizza.json');

const owner = '0xef0f564EF485aA83cdaeD5b7Dfe7784a5DD272c7'
const privateKey = '0x1be9fb140547fbc23da661d283db717caf265a97bae49e248206023cc7e164fa'
// set provider for all later instances to use
Contract.setProvider('wss://ropsten.infura.io/ws/v3/2c77e96cffa447759bf958ee4cd8f9ad');

// const caller = "0x557FD57ca1855913e457DA28fF3E033B0c653700";
const oracleAddress = "0xa6a4a5d19327b575861466b0fa532833fa84b602";
const mainPizzaAddress = '0x0681ef84916faf655d7702783653cde2c863583c'

var contract = new Contract(OpenSourcePizzaOracle.abi, oracleAddress);
var pizzaContract = new Contract(OpenSourcePizza.abi, mainPizzaAddress);

/* 
// // Iterates through the dependencies of the project and returns only the ones that exist on our blockchain
        // const extractOnChainProjects = async () => {
        //     const arr: number[] = []
        //     await Promise.all(dependenciesFromGithub.map(async (projectID) => {
        //         const result = await pizzaContract.methods.projectOwners(projectID).call()
        //         result != 0 && arr.push(projectID)
        //     }))
        //     return arr;
        // }
        // const resultToReturn = await extractOnChainProjects()
*/

async function main() {
}   
// main()           

contract!.events["RegisterEvent(uint32)"]()
    .on("connected", function (subId: any) {
        console.log("listening on event RegisterEvent");
    })
    .on("data", async function (event: any) {
        console.log(`logging event returnValues ${JSON.stringify(event.returnValues)}`);
        const { projectID } = event.returnValues

        try {
            console.log('Trying to call reply register...')
            console.log(contract.methods)

            // Grab the address of the project owner from their github repo
            const ownerAddress = await getAddress(projectID)

            console.log(`ownerAddress: ${ownerAddress}`)
            // need to grab the address of the project owner
            var data = contract.methods["replyRegister(uint32,address)"](projectID, ownerAddress).encodeABI();
            const options = {
                to: oracleAddress,
                data: data,
                gas: '100000',
            }
            const signedTransaction: any = await web3.eth.accounts.signTransaction(options, privateKey);
            const transactionReceipt = await web3.eth.sendSignedTransaction(signedTransaction.rawTransaction);
            console.log(transactionReceipt);
            
        } catch (e) {
            console.log(e);
        }
   });

// Donate Event
contract!.events["DonateEvent(uint32)"]()
    .on("connected", function (subId: any) {
        console.log("listening on event DonateEvent");
    })
    .on("data", async function (event: any) {
        console.log('DonateEvent event received...')
        const { requestID } = event.returnValues
        const projectID = await pizzaContract.methods.sponsorRequests(requestID).call()
        
        // Here, we call github to grab the dependencies. Currently using a dummy array
        const resultToReturn = await getDependencies(projectID)
        
        // Grabbing the list of dependencies for the project on chain ---> mapping(uint32 => uint32[]) public projectDependencies;
        const getExistingDependencies = async () => {
            const res: number[] = []
            var i = 0;
            while (true) {
                try {
                    const result = await pizzaContract.methods.projectDependencies(projectID, i).call();
                    res.push(result)
                    i += 1
                } catch (e) {
                    return res
                }
            }
        }
        const existingDependenciesOnChain: number[] = await getExistingDependencies()

        /* Now, we check whether the dependencies have changed to evaluate the isReplace boolean.
           If the lengths are not the same, they have changed, or if they are different at any given index, they have changed */
        var hasChanged = false
        
        if (resultToReturn.length != existingDependenciesOnChain.length) {
            hasChanged = true
        } else {
            for (var i = 0; i < resultToReturn.length; i++) {
                if (resultToReturn[i] != existingDependenciesOnChain[i]) {
                    hasChanged = true;
                    break;
                }
            }
        }
        console.log(`hasChanged: ${hasChanged}`)
        if (hasChanged) {
            try {
                console.log('Trying to call replyDonateUpdateDeps...')
                
                // TODO: Check whether a distribution is in progress
                var data = contract.methods["replyDonateUpdateDeps(uint32,uint32[],bool)"](projectID, resultToReturn, hasChanged).encodeABI();
                const options = {
                    to: oracleAddress,
                    data: data,
                    gas: '100000',
                }
    
                const signedTransaction: any = await web3.eth.accounts.signTransaction(options, privateKey);
                const transactionReceipt = await web3.eth.sendSignedTransaction(signedTransaction.rawTransaction);
                console.log(`Reply donate update deps transaction receipt: ${transactionReceipt}`);
                
            } catch (e) {
                console.log(e);
            }
        }
        // Now to call replyDonateDistribute
        try {
            // Split up the response dependant on singleCallMaxDepsSize
            console.log('Calling replyDonateDistribute...')
            const singleCallMaxDepsSize = await pizzaContract.methods.singleCallMaxDepsSize().call()
            var lowerIndex = 0;
        
            for (var i = 0; i < resultToReturn.length; i++) {
                if (((i + 1) % singleCallMaxDepsSize == 0) || ((i + 1) == resultToReturn.length)) {
                    var data = contract.methods["replyDonateDistribute(uint32,uint256,uint256)"](requestID, lowerIndex, i).encodeABI();
                    const options = {
                        to: oracleAddress,
                        data: data,
                        gas: '1000000',
                    }
                    lowerIndex = i + 1;
                    const signedTransaction: any = await web3.eth.accounts.signTransaction(options, privateKey);
                    const transactionReceipt = await web3.eth.sendSignedTransaction(signedTransaction.rawTransaction);
                    console.log(transactionReceipt)
                }
            }

        } catch (err) {
            console.log(err)
        }

    });
