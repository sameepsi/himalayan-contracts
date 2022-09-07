const Web3 = require('web3');
var Tx = require('ethereumjs-tx');
var util = require('ethereumjs-util');
const axios = require('axios').default;

const options = {
    // Enable auto reconnection
    reconnect: {
        auto: true,
        delay: 5000, // ms
        maxAttempts: 50,
        onTimeout: false
    }
};

var p  = 'https://polygon-rpc.com/'//'https://polygon-mainnet.infura.io/v3/6a2c456d01b841ae900ec2f85243322d'//"https://polygon-rpc.com/"// "https://nd-995-891-194.p2pify.com/58d3a2349fd1d7d909ee1a51d76cfdbf"//
//'https://polygon-mainnet.infura.io/v3/6a2c456d01b841ae900ec2f85243322d';
var infura = 'https://polygon-rpc.com/'//'https://polygon-mai0xa27b6853d759c03b3ac3714a97322c90b9c79316nnet.infura.io/v3/6a2c456d01b841ae900ec2f85243322d'//"https://polygon-rpc.com/"//'https://polygon-mainnet.infura.io/v3/6a2c456d01b841ae900ec2f85243322d'//'https://matic-mainnet--jsonrpc.datahub.figment.io/apikey/73088fa3ab15c735a4efb389a05ebdfc/';

//var p = 'wss://mainnet.infura.io/ws/v3/25828999a1a34c00845f18df8e5053fd';

var web3 = new Web3(new Web3.providers.HttpProvider(p));
var web3Infura = new Web3(new Web3.providers.HttpProvider(infura));

require('dotenv').config();  // Store environment-specific variable from '.env' to process.env

const converterABI = [
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "_factory",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "_dragonLair",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "_quick",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "_weth",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "_treasury",
        "type": "address"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "constructor"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "internalType": "address",
        "name": "token",
        "type": "address"
      },
      {
        "indexed": true,
        "internalType": "address",
        "name": "bridge",
        "type": "address"
      }
    ],
    "name": "LogBridgeSet",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "internalType": "address",
        "name": "server",
        "type": "address"
      },
      {
        "indexed": true,
        "internalType": "address",
        "name": "token0",
        "type": "address"
      },
      {
        "indexed": true,
        "internalType": "address",
        "name": "token1",
        "type": "address"
      },
      {
        "indexed": false,
        "internalType": "uint256",
        "name": "amount0",
        "type": "uint256"
      },
      {
        "indexed": false,
        "internalType": "uint256",
        "name": "amount1",
        "type": "uint256"
      },
      {
        "indexed": false,
        "internalType": "uint256",
        "name": "amountQUICK",
        "type": "uint256"
      }
    ],
    "name": "LogConvert",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "internalType": "address",
        "name": "previousOwner",
        "type": "address"
      },
      {
        "indexed": true,
        "internalType": "address",
        "name": "newOwner",
        "type": "address"
      }
    ],
    "name": "OwnershipTransferred",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "internalType": "address",
        "name": "treasury",
        "type": "address"
      }
    ],
    "name": "TreasuryChanged",
    "type": "event"
  },
  {
    "inputs": [],
    "name": "claimOwnership",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "dragonLair",
    "outputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "factory",
    "outputs": [
      {
        "internalType": "contract IUniswapV2Factory",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "owner",
    "outputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "pendingOwner",
    "outputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "quick",
    "outputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "newOwner",
        "type": "address"
      },
      {
        "internalType": "bool",
        "name": "direct",
        "type": "bool"
      },
      {
        "internalType": "bool",
        "name": "renounce",
        "type": "bool"
      }
    ],
    "name": "transferOwnership",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "treasury",
    "outputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "weth",
    "outputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "token",
        "type": "address"
      }
    ],
    "name": "bridgeFor",
    "outputs": [
      {
        "internalType": "address",
        "name": "bridge",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "token",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "bridge",
        "type": "address"
      }
    ],
    "name": "setBridge",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "_treasury",
        "type": "address"
      }
    ],
    "name": "changeTreasury",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "token0",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "token1",
        "type": "address"
      }
    ],
    "name": "convert",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "token0",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "token1",
        "type": "address"
      }
    ],
    "name": "burnPair",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "token",
        "type": "address"
      }
    ],
    "name": "convertTokenToQuick",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address[]",
        "name": "token0",
        "type": "address[]"
      },
      {
        "internalType": "address[]",
        "name": "token1",
        "type": "address[]"
      }
    ],
    "name": "convertMultiple",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
];

const converterAddress = "0x0E43245f7Af3cFb1D4838E6704F27D09A8b4b072" //"0x66f3125acB3c070B323e354156A1a370706990E9";//"0x38E8d77F4b651fB989C8b5ad274346dD5B5239eA";

var converterContract =  new web3Infura.eth.Contract(
    converterABI,
    converterAddress
);

var converterContractRead =  new web3.eth.Contract(
  converterABI,
  converterAddress
);

const blacklist = [
  "0x7d645cbbcade2a130bf1bf0528b8541d32d3f8cf",
  "0xa27b6853d759c03b3ac3714a97322c90b9c79316",
  "0xcc1b9517460d8ae86fe576f614d091fca65a28fc",
  "0x0db83fc98318e0c417dace3a7b141ebcff8eb739",
  "0xadd493490011fb1d5798891eb579c7515a381a35",
  "0x1aa75e1254868e6663bb7a2792c0c23c340e38d6",
  "0x58507a5eaea8c790aa606aab3172ec00f82cdb21",
  "0x1250ab0d94d8140514b0550c9aed1dde78b8eb42",
  "0xc59762a6b56fcf9015e56dd721dd3ef4e2272f80",
  "0xee67a5bf49d7d28b3da7fec7c2f2fe690e25eb9b",
  "0x80244c2441779361f35803b8c711c6c8fc6054a3",
  "0x0c8c8ae8bc3a69dc8482c01ceacfb588bb516b01",
  "0x8465d41d66ce05bde12fd3320f260e01aa4ced3f",
  "0x3cef98bb43d732e2f285ee605a8158cde967d219",
  "0x521cddc0cba84f14c69c1e99249f781aa73ee0bc",
  "0x71b821aa52a49f32eed535fca6eb5aa130085978",
  "0x9359729fe74603e782710a6a7ffcfa22261f85e6",
  "0x3e014fdb8fb2e9fd29fcb05448804cbd840feea9",
  "0x43308565c0204c8076a291f0726f914c3133ce34",
  "0xdab529f40e671a1d4bf91361c21bf9f0c9712ab7",
  "0x1f435c17d7ff631218827f9ba43a696650a9d512",
  "0xe59c42b6a8c8079a5b8b9e6e407bb55fd66c7372",
  "0x36763d262243ca67186487add95256f5892a6fd0",
  "0x83593d701b04eeb4ebb03abd84919185ea1d4aed",
  "0x73381dfd4c994ba4f5c68622ebd4edaa0e056b43",
  "0x3a879931d80d6b1221f5f1887bac929da2c699f2",
  "0x67b78d31a40dacc5acf7648c2ad88bdbf6eeec1c",
  "0xadf79db1147e831158f08b13356d69ccf6649d2b",
  "0xd864c4558d5bcfc6941cce962032ed59ab85efc8",
  "0x260f5d6ab77f2459c231baf84bd13bfbfa7521e3",
  "0xb140665dde25c644c6b418e417c930de8a8a6ac9",
  "0x4ee8135b058b8a6bbd5af8e9ce387e051731e7b7",
  "0xdb3b3b147a030f032633f6c4bebf9a2fb5a882b5",
  "0xb6e12d03fbe1aa993fa1815e79490e24317cf7b8",
  "0x221afac78d2725d090499b973bb42fc93cca2ef5",
  "0x9d47b3faa5ff227d2bd404f572ef0ab0c8409161",
  "0xf524d21316c69f50b46623a9773300b86fbe2e10",
  "0x0325bf6889aa55f7d5f62619fdec3aa6d78308a8",
  "0xfa72b07ade2af7d41413850a1e8d5578b3490988",
  "0x2b88ad57897a8b496595925f43048301c37615da",
  "0x6971aca589bbd367516d70c3d210e4906b090c96",
  "0x3be698b235026368c35aad14c08972bc5c5f2849",
  "0x4a81f8796e0c6ad4877a51c86693b0de8093f2ef",
  "0xe7f76250e6739efcd6957cf6484135c10d56cf12",
  "0xb1289f48e8d8ad1532e83a8961f6e8b5a134661d",
  "0xfa8f10950eaf53449c77e47a0c68c1996cc28eb1",
  "0xda7bdacdd9a8e8ebe062b31f63b3f58cf480d09d",
  "0x06e52db46f1b1bb3c3e0db3d9686c38f8dfc5db8",
  "0x130ff075868af7027a87f02fba766037b73f4403",
  "0x7a5ef89d49c0c16e750b46ded653c0560af994c0",
  "0x30a8e1c256143ad440faa9042722929b0bc0fc7d",
  "0x845e76a8691423fbc4ecb8dd77556cb61c09ee25",
  "0xe68361e0f58d0c1e38a5392dd7e0c6bb5cd66833",
  "0x6cc2c94bf853fca7ee473b2a7186d5251099697e",
  "0xab7589de4c581db0fb265e25a8e7809d84ccd7e8",
  "0xf5ea626334037a2cf0155d49ea6462fddc6eff19",
  "0x1c40ac03aacaf5f85808674e526e9c26309db92f",
  "0x0b3f868e0be5597d5db7feb59e1cadbb0fdda50a",
  "0x0000000000000000000000000000000000000040",
  "0x00000000000000000000000000000000000006a0",
  "0x161c0ece60dcfcdc3e4bdd5f1cde3ed2f68285a9",
  "0x5d47baba0d66083c52009271faf3f50dcc01023c",
  "0xfcb5df42e06a39e233dc707bb3a80311efd11576",
  "0x316b4db72ec7eacdb6e998257c4349c2b08ff27d",
  "0x4b56708bca811ed5851b4e41e99d36bfccbacb9f",
  "0xc8c0b377f9f164bdb008c0e9fa57a3d9da2dabcd"
]

var privateKey01 = process.env.PK1;
var privateKey02 = process.env.PK2;

var lastUsed = 1;

const convertAll = async() => {
  const pairs = require("./pairs.json");
  const token0ss = pairs["token0"];
  const token1ss = pairs['token1'];
  
  try {
    const token0s = new Array();
    const token1s = new Array();

    console.log("Total pairs fetched", token0ss.length)
    console.log("Fetching all relevant pairs!");
    for (var i = 0; i < token0ss.length; i++) {
      try {
        console.log(i);
        const token0 = token0ss[i];
        const token1 = token1ss[i];
        if ( (blacklist.includes(token0.toLowerCase()) || blacklist.includes(token1.toLowerCase()))) {
          continue;
        }
        try {
          await testBurnPair(token0, token1);
          token0s.push(token0);
          token1s.push(token1);
          
        } catch (error) {
          console.log("Failed to burn", token0, token1)
        }
      } catch (error) {
        
      }
    }
    console.log("Total pairs to convert", token1s.length);
  
    
    console.log("Converting all pairs to QUICK");
    
    for(var i = 0; i < 300/**token1s.length*/; i = i + 30) {
      await waitforme(2000)
        console.log(i, i + 30);
        try {
          //console.log("Gas Price", startingGasPrice);
          await sendTransaction(token0s.slice(i, i + 30), token1s.slice(i, i + 30));
        } catch (error) {
          console.log(error);

          try {
            /**console.log("Burning individual tokens")
            for( var j = i; ( j < i + 50 && j < token1s.length ) ; j++) {
              console.log(j);
              const arr1 = new Array();
              const arr2 = new Array();
              arr1.push(token0s[j]);
              arr2.push(token1s[j]);
              await sendTransaction(arr1, arr2);
            }*/
          } catch (error) {
            console.log(error);
          }
        }
    }

    console.log("Converted all tokens to QUICK");

    /**for(var i = 0; i < whitelist.length; i++) {
      await waitforme(2000)
      const pairContract = new web3.eth.Contract(
        pairABI,
        whitelist[i]
      );
      const balance = await pairContract.methods.balanceOf(converterAddress).call();
      if (balance > 0) {
        await convertToken(whitelist[i]);
      }
    }*/
    //await waitforme(10000)

    //console.log("TURNING FEE ON");

    //await setFeeTo(converterAddress);

  } catch (error) {
      console.log(error);
  }
    
}
const testBurnPair = async(tokenA, tokenB) => {
  const arr1 = new Array();
  const arr2 = new Array();
  arr1.push(tokenA);
  arr2.push(tokenB);

  await converterContractRead.methods.convertMultiple(arr1, arr2).estimateGas();
    
}

const sendTransaction = async(tokenAs, tokenBs) => {
  return new Promise(async(res, rej)=>{
    var startingGasPrice = 50;
    try {
      var result01 = await axios.get('https://gasstation-mainnet.matic.network');
      startingGasPrice = result01.data.standard;

      /**if (startingGasPrice > 200) {
        startingGasPrice = 200;
      }
      if(startingGasPrice < 30) {
        startingGasPrice = 40
      }*/
    } catch (error) {
      console.log("Failed to get gas price. Using default gas price")
    }
    try {
      console.log(tokenAs, tokenBs);
      var privateKey;
      if(lastUsed == 0) {
        lastUsed = 1;
        privateKey = privateKey02
        console.log("First account used")
      }
      else {
        lastUsed = 0;
        privateKey = privateKey01;
        console.log("First account used")
      }
      var privateKeyBuffered = new Buffer(privateKey, 'hex')
      var sender = util.privateToAddress(privateKeyBuffered);
      sender = "0x" + sender.toString('hex');
      console.log("SENDER", sender);
      
      var data = converterContract.methods.convertMultiple(tokenAs, tokenBs).encodeABI();
      //console.log(data);
      //await converterContract.methods.convertMultiple(tokenAs, tokenBs).estimateGas();
      var gasLimit = 14000000;

      var nonce = await web3Infura.eth.getTransactionCount(sender);
      startingGasPrice = web3Infura.utils.toWei(startingGasPrice.toString(), "gwei");
      var rawTx = {
          chainId: web3Infura.utils.toHex(137),
          nonce: web3Infura.utils.toHex(nonce),
          gasLimit: web3Infura.utils.toHex(gasLimit),
          gasPrice: web3Infura.utils.toHex(startingGasPrice),
          to: converterAddress,
          value: '0x00',
          data: data
      }

      var tx = new Tx(rawTx);
      tx.sign(privateKeyBuffered);

      var serializedTx = tx.serialize();

      await web3Infura.eth.sendSignedTransaction('0x' + serializedTx.toString('hex'))
      .once('transactionHash', function(hash){console.log(hash)})
      .on('confirmation', function(confNumber, receipt, latestBlockHash){ if(confNumber === 3) {res()}})
      .on('error', function(error){rej(error)});
    } catch (error) {
      rej(error)
    }
  })
    
    
}

function waitforme(milisec) {
  return new Promise(resolve => {
      setTimeout(() => { resolve('') }, milisec);
  })
}

convertAll();

setInterval(async ()=>{
  console.log("CONVERTING TOKENS")
  await convertAll();
  console.log("TOKENS CONVERTED");
}, 86400000)