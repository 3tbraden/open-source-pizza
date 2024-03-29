import Web3 from "web3"
import { getAddress, getDependencies } from "./github-client";
const Contract = require('web3-eth-contract');

const web3Provider = new Web3.providers.HttpProvider(process.env.BLOCKCHAIN_CONNECTION_HTTPS as string);
const web3 = new Web3(web3Provider); 

const OpenSourcePizzaOracle = require('./contracts/OpenSourcePizzaOracle.json');
const OpenSourcePizza = require('./contracts/OpenSourcePizza.json');

const privateKey = process.env.ORACLE_PRIV as string;
// set provider for all later instances to use
Contract.setProvider(process.env.BLOCKCHAIN_CONNECTION_WSS as string);

const oracleAddress = process.env.ORACLE_CONTRACT;
const mainPizzaAddress = process.env.PIZZA_CONTRACT;

var contract = new Contract(OpenSourcePizzaOracle.abi, oracleAddress);
var pizzaContract = new Contract(OpenSourcePizza.abi, mainPizzaAddress);

const checkUntilDistributionHasEnded = async (projectID: number) => {
    console.log('A distribution is currently in progress... entering an interval to keep evaluating this every 30 seconds')
                
    const checkIfDistributionIsInProgressInterval = async () => {   
        var numDistributionsInProgress = await pizzaContract.methods.distributionInProgress(projectID).call()
        
        if (numDistributionsInProgress == 0) {
            console.log('Distribution has ended!')
            stopChecking()
        }
        console.log('Distribution still in progress...')
    }
    const stopChecking = () => {
        clearInterval(myInterval)
    }

    const myInterval = setInterval(checkIfDistributionIsInProgressInterval, 30000)
}

contract!.events["RegisterEvent(uint32)"]()
    .on("connected", function (subId: any) {
        console.log("Listening on event RegisterEvent...");
    })
    .on("data", async function (event: any) {
        console.log('Received data from RegisterEvent...')
        const { projectID } = event.returnValues

        try {
            console.log('Trying to call reply register...')

            // Grab the address of the project owner from their github repo
            const ownerAddress = await getAddress(projectID)

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
        console.log("Listening on event DonateEvent");
    })
    .on("data", async function (event: any) {
        console.log('Received data from DonateEvent...')
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
        
        if (hasChanged) {
            try {
                console.log('Trying to call replyDonateUpdateDeps...')
                
                var numDistributionsInProgress: any = await pizzaContract.methods.distributionInProgress(projectID).call()

                /* If a distribution is currently in progress, enter an interval where we keep checking this every 30 seconds
                   When it becomes true, we exit the interval and call replyDonateUpdateDeps */
                if (numDistributionsInProgress > 0) await checkUntilDistributionHasEnded(projectID)
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
            const singleCallMaxDepsSize = 1
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
