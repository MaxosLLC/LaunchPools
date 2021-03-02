import React, {Component} from 'react'

const Web3 = require('web3')

let web3js = ''

let contract = ''

let accounts = ''

let ethereum = ''

class Sample extends Component {

    constructor(props) {
        super(props);
        this.state = {

        }
    }

    componentDidMount() {
        // Important line to enable MetaMask connection with React
        ethereum = window.ethereum;
        this.checkWeb3()
    }

    async checkWeb3() {
        if (typeof window.web3 !== 'undefined') {
            // Use MetaMask's provider.
            web3js = new Web3(window.web3.currentProvider);

            //Get selected account on MetaMask
            accounts = await web3js.eth.getAccounts()

            //Get network which MetaMask is connected to
            let network = await web3js.eth.net.getNetworkType()


        } else {
            /*** MetaMask is not installed ***/
        }
    }

    initContract() {
        contract = new web3js.eth.Contract("INSERT CONTRACT ABI", "INSERT CONTRACT ADDRESS")
    }

    async sendTransactionToContract() {
        // contract.methods.methodName(parameters).send({from:selected account})
        await contract.methods.burnFrom(/*** parameters ***/).send({from: accounts /* from MetaMask */})
            .on('transactionHash', (hash) => {
                // hash of tx
            }).on('confirmation', function (confirmationNumber, receipt) {
                if (confirmationNumber === 2) {
                   // tx confirmed
                }
            })
    }

    async sendTransactionEth(){
        web3js.eth.sendTransaction({
            to: "INSERT DESTINATION PUBLIC KEY",
            from: "INSERT ORIGIN PUBLIC KEY",
            value: web3js.utils.toWei('amount', 'ether'),
        })
    }

    async callContract(){
        // contract.methods.methodName(parameters).call({from:selected account})
        contract.methods.getManufacturerAddress().call({ from: accounts /* from MetaMask */})
            .then((res) => {
                /*** We will get the return value from our smart contract ***/
            });
    }


    render() {
        // render
    }
}
