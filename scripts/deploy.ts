import { ethers, run } from 'hardhat'
import { StakeVault } from '../types'

async function deploySmartContract() {
  let stakeVault: StakeVault;

  await run('compile');
  const [owner] = await ethers.getSigners();

  console.log('Deploying contracts with the account:', owner.address);

  const offerPeriod = process.env.OFFER_PERIOD;
  const tokenAddress = process.env.USDC_ADDRESS;
  const StakeVaultFactory = await ethers.getContractFactory("StakeVault");
  stakeVault = await StakeVaultFactory.deploy(tokenAddress, offerPeriod) as StakeVault;
  await stakeVault.deployed();

  console.log(`StakeVault deployed! Address: ${stakeVault.address}`);
}

deploySmartContract()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
