var Web3 = require('web3')

const OPTIONS = {
    // defaultBlock: "latest",
    transactionConfirmationBlocks: 1,
    transactionBlockTimeout: 5
};
// Mainnet Infura client
const web3 = new Web3("https://mainnet.infura.io/v3/ff4d778692ad42f7966a456564283e9d", null, OPTIONS)
// Rinkeby Infura client
const web3 = new Web3("https://rinkeby.infura.io/v3/ff4d778692ad42f7966a456564283e9d", null, OPTIONS)


const contract = new web3.eth.Contract("OUR CONTRACT'S ABI", "OUR CONTRACT'S ADDRESS")


exports.sendTransactionETH = async () => {
    try {

        let gasPrices = await exports.getCurrentGasPrices();

        let nonce = await exports.getNonceByEthAddress(/***public key***/);

        let rawTransaction = {
            "from": "INSERT ORIGIN ADDRESS/PUBLIC KEY HERE",
            "to": "INSERT DESTINATION ADDRESS/PUBLIC KEY HERE",
            "value": "INSERT THE AMOUNT TO SEND",
            "gasPrice": gasPrices.medium * 1000000000, // converts the gwei price to wei
            "gasLimit": 300000,
            "nonce": nonce,
            "chainId": 1// EIP 155 chainId - mainnet: 1, rinkeby: 4
        };

        web3.eth.accounts.signTransaction(rawTransaction, /***private key***/ ).then(async signed => {
            web3.eth.sendSignedTransaction(signed.rawTransaction)
                .on('confirmation', (confirmationNumber, receipt) => {
                    console.log(receipt)
                })
                .on('error', (error) => {
                    console.log(error)
                    callback(constants.etherError)
                })
                .on('transactionHash', async (hash) => {
                    console.log(hash);

                });
        });

    } catch (e) {
        console.log(e)
    }
};


exports.sendTransactionContract = async () => {

    web3.eth.getTransactionCount(constants.publicKey, "pending").then(async res => {
        let count = res

        let gasPrices = await exports.getCurrentGasPrices();

        var rawTransaction = {
            from: "INSERT PUBLIC KEY HERE",
            to: "INSERT CONTRACT ADDRESS HERE",
            //contract.methods.methodName(parameters).encodeABI
            data: contract.methods.transfer(to_address, amount * 1000000).encodeABI(),
            gasPrice: gasPrices.medium * 1000000000,
            nonce: web3.utils.toHex(count),
            gasLimit: web3.utils.toHex(300000),
            chainId: 1 //EIP 155 chainId - mainnet: 1, rinkeby: 4
        }

        web3.eth.accounts.signTransaction(rawTransaction, /***private key***/ ).then(async signed => {
            web3.eth.sendSignedTransaction(signed.rawTransaction)
                .on('confirmation', (confirmationNumber, receipt) => {
                    if (confirmationNumber === 1) {
                        console.log(receipt)
                    }
                })
                .on('error', (error) => {
                    console.log(error)
                })
                .on('transactionHash', async (hash) => {
                    console.log(hash);
                });
        }).catch(e => {
            console.log(e)
        });

    }).catch(error => {
        console.log(error)
    })
};

/*** Get data from our smart contract ***/
exports.getData = async () => {
    try {
        let getData = await contract.myFunction.getData(/***parameters***/);
        return getData
    } catch (e) {

    }
}

exports.getCurrentGasPrices = async () => {
    try {
        let response = await axios.get('https://ethgasstation.info/json/ethgasAPI.json')
        let prices = {
            low: response.data.safeLow / 10,
            medium: response.data.average / 10,
            high: response.data.fast / 10
        };

        return prices;
    } catch (e) {
        console.log(e)
    }

};

exports.getNonceByEthAddress = async (eth_address) => {
    try {
        let nonce = await web3.eth.getTransactionCount(eth_address, "pending");
        console.log(nonce);
        return nonce;

    } catch (e) {

    }
}