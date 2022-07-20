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
const Contract = require('web3-eth-contract');
const OpenSourcePizzaOracle = require('./contracts/OpenSourcePizzaOracle.json');
// set provider for all later instances to use
Contract.setProvider('wss://ropsten.infura.io/ws/v3/2c77e96cffa447759bf958ee4cd8f9ad');
// const caller = "0x557FD57ca1855913e457DA28fF3E033B0c653700";
const address = "0x671BC4b1388e52f864fa182Bc1D59Cef23AaD797";
var contract = new Contract(OpenSourcePizzaOracle.abi, address);
contract.events["RegisterEvent(uint16)"]()
    .on("connected", function (subId) {
    console.log("listening on event RegisterEvent");
})
    .on("data", function (event) {
    return __awaiter(this, void 0, void 0, function* () {
        console.log(`logging event returnValues ${JSON.stringify(event.returnValues)}`);
    });
});
