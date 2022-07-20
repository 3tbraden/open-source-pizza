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
const OpenSourcePizza = artifacts.require("OpenSourcePizza");
const OpenSourcePizzaOracle = artifacts.require("OpenSourcePizzaOracle");
module.exports = function (deployer) {
    return __awaiter(this, void 0, void 0, function* () {
        deployer.deploy(OpenSourcePizza).then(function () {
            return deployer.deploy(OpenSourcePizzaOracle, OpenSourcePizza.address);
        });
    });
};
