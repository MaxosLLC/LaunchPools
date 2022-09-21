import { ethers, run } from 'hardhat'
import { StakeVault } from '../types'

async function deploySmartContract() {
  let stakeVault: StakeVault;

  await run('compile');
  const [owner] = await ethers.getSigners();

  console.log('Deploying contracts with the account:', owner.address);

  const tokenAddress = process.env.ETHEREUM_USDC_ADDRESS;
  const StakeVaultFactory = await ethers.getContractFactory("StakeVault");
  stakeVault = await StakeVaultFactory.deploy(tokenAddress) as StakeVault;
  await stakeVault.deployed();

  console.log(`StakeVault deployed! Address: ${stakeVault.address}`);
}

deploySmartContract()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
