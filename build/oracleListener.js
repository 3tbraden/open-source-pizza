"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const web3_1 = __importDefault(require("web3"));
const Contract = require('web3-eth-contract');
const web3Provider = new web3_1.default.providers.WebsocketProvider("ws://localhost:7545");
const web3 = new web3_1.default(web3Provider);
const OpenSourcePizzaOracle = require('./contracts/OpenSourcePizzaOracle.json');
const owner = '0xef0f564EF485aA83cdaeD5b7Dfe7784a5DD272c7';
// set provider for all later instances to use
Contract.setProvider('wss://ropsten.infura.io/ws/v3/2c77e96cffa447759bf958ee4cd8f9ad');
// const caller = "0x557FD57ca1855913e457DA28fF3E033B0c653700";
const address = "0x671BC4b1388e52f864fa182Bc1D59Cef23AaD797";
var contract = new Contract(OpenSourcePizzaOracle.abi, address);
const getGasPrice = () => __awaiter(void 0, void 0, void 0, function* () {
    return yield web3.eth.getGasPrice().then((averageGasPrice) => {
        return averageGasPrice;
    }).catch(console.error);
});
const gasPrice = getGasPrice();
contract.events["RegisterEvent(uint16)"]()
    .on("connected", function (subId) {
    console.log("listening on event RegisterEvent");
})
    .on("data", function (event) {
    return __awaiter(this, void 0, void 0, function* () {
        console.log(`logging event returnValues ${JSON.stringify(event.returnValues)}`);
        const { projectID } = event.returnValues;
        console.log(`projectID: ${projectID}`);
        const dummyAddress = '0xef0f564EF485aA83cdaeD5b7Dfe7784a5DD272f9';
        try {
            console.log('Trying...');
            JSON.stringify(contract.methods, undefined, 4);
            contract.methods["replyRegister(uint16,address)"](projectID, dummyAddress).send({
                from: owner,
                gasPrice,
                gas: Math.ceil(1.2 * (yield contract.methods["replyRegister(uint16,address)"](projectID, dummyAddress).estimateGas({ from: owner }))),
            }).then(function (receipt) {
                console.log('Success: ', receipt);
                return receipt;
            }).catch((err) => {
                console.error(err);
            });
        }
        catch (e) {
            console.log(e);
        }
    });
});
