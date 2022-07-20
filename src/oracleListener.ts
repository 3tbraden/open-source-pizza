import Web3 from "web3"
    
(async () => {
    
    //connect to web3
    const web3Provider = new Web3.providers.WebsocketProvider("ws://localhost:7545");
    const web3 = new Web3(web3Provider);

    console.log(web3)
    
})();