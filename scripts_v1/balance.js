const { ethers } = require("ethers");
const { DefenderRelaySigner, DefenderRelayProvider } = require('defender-relay-client/lib/ethers');


// Cli Gamma Sync Information = null performed sync using autoclient on Wed Feb 02 2022 12:37:16 GMT+0100 (West Africa Standard Time);


var gammaRelayer = '0xb60998a500a4751419481d2f10c9a9f6b3f27ef1';


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
    const balance = await provider.getBalance(gammaRelayer);
    console.log(balance);
  }


  
  // To run locally (this code will not be executed in Autotasks)
  if (require.main === module) {
      const { API_KEY: apiKey, API_SECRET: apiSecret } = process.env;
      exports.handler({ apiKey, apiSecret })
          .then(() => process.exit(0))
          .catch(error => { console.error(error); process.exit(1); });
  }