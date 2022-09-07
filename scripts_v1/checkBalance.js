const { ethers } = require("ethers");
const { DefenderRelaySigner, DefenderRelayProvider } = require('defender-relay-client/lib/ethers');


// Cli Gamma Sync Information = null performed sync using autoclient on Wed Feb 02 2022 12:37:16 GMT+0100 (West Africa Standard Time);

var WDogeAbiString = '[{"type":"event","name":"Approval","inputs":[{"type":"address","name":"src","internalType":"address","indexed":true},{"type":"address","name":"guy","internalType":"address","indexed":true},{"type":"uint256","name":"wad","internalType":"uint256","indexed":false}],"anonymous":false},{"type":"event","name":"Deposit","inputs":[{"type":"address","name":"dst","internalType":"address","indexed":true},{"type":"uint256","name":"wad","internalType":"uint256","indexed":false}],"anonymous":false},{"type":"event","name":"Transfer","inputs":[{"type":"address","name":"src","internalType":"address","indexed":true},{"type":"address","name":"dst","internalType":"address","indexed":true},{"type":"uint256","name":"wad","internalType":"uint256","indexed":false}],"anonymous":false},{"type":"event","name":"Withdrawal","inputs":[{"type":"address","name":"src","internalType":"address","indexed":true},{"type":"uint256","name":"wad","internalType":"uint256","indexed":false}],"anonymous":false},{"type":"function","stateMutability":"view","outputs":[{"type":"uint256","name":"","internalType":"uint256"}],"name":"allowance","inputs":[{"type":"address","name":"","internalType":"address"},{"type":"address","name":"","internalType":"address"}]},{"type":"function","stateMutability":"nonpayable","outputs":[{"type":"bool","name":"","internalType":"bool"}],"name":"approve","inputs":[{"type":"address","name":"guy","internalType":"address"},{"type":"uint256","name":"wad","internalType":"uint256"}]},{"type":"function","stateMutability":"view","outputs":[{"type":"uint256","name":"","internalType":"uint256"}],"name":"balanceOf","inputs":[{"type":"address","name":"","internalType":"address"}]},{"type":"function","stateMutability":"view","outputs":[{"type":"uint8","name":"","internalType":"uint8"}],"name":"decimals","inputs":[]},{"type":"function","stateMutability":"payable","outputs":[],"name":"deposit","inputs":[]},{"type":"function","stateMutability":"view","outputs":[{"type":"string","name":"","internalType":"string"}],"name":"name","inputs":[]},{"type":"function","stateMutability":"view","outputs":[{"type":"string","name":"","internalType":"string"}],"name":"symbol","inputs":[]},{"type":"function","stateMutability":"view","outputs":[{"type":"uint256","name":"","internalType":"uint256"}],"name":"totalSupply","inputs":[]},{"type":"function","stateMutability":"nonpayable","outputs":[{"type":"bool","name":"","internalType":"bool"}],"name":"transfer","inputs":[{"type":"address","name":"dst","internalType":"address"},{"type":"uint256","name":"wad","internalType":"uint256"}]},{"type":"function","stateMutability":"nonpayable","outputs":[{"type":"bool","name":"","internalType":"bool"}],"name":"transferFrom","inputs":[{"type":"address","name":"src","internalType":"address"},{"type":"address","name":"dst","internalType":"address"},{"type":"uint256","name":"wad","internalType":"uint256"}]},{"type":"function","stateMutability":"nonpayable","outputs":[],"name":"withdraw","inputs":[{"type":"uint256","name":"wad","internalType":"uint256"}]},{"type":"receive","stateMutability":"payable"}]'

var wdogeAddressString = '0xb7ddc6414bf4f5515b52d8bdd69973ae205ff101';

const WDogeAbi = JSON.parse(WDogeAbiString);

const poolAddress = '0x41043e6227472dAA2fE8625C2BE4BB3F64537138';

// Entrypoint for the Autotask
exports.handler = async function(credentials) {
    // config
    const relayerAddress = '0xcc1f07006b9bc5b3f072dfb7b5f7ff7e16e2eef9';                    // Refiller address
    
    // Initialize default provider and defender relayer signer
    const provider = new DefenderRelayProvider(credentials);
    const signer = new DefenderRelaySigner(credentials, provider, { 
        speed: 'fast', 
        from: relayerAddress,
    });

    const wdoge = new ethers.Contract(wdogeAddressString, WDogeAbi, signer);

    const balance = await wdoge.balanceOf(poolAddress);
    console.log(balance);
  }


  
  // To run locally (this code will not be executed in Autotasks)
  if (require.main === module) {
      const { API_KEY: apiKey, API_SECRET: apiSecret } = process.env;
      exports.handler({ apiKey, apiSecret })
          .then(() => process.exit(0))
          .catch(error => { console.error(error); process.exit(1); });
  }