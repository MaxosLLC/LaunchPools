import { ethers, run } from 'hardhat';
import { StakeVault } from '../types';

async function deploySmartContract() {
  let stakeVault: StakeVault;

  await run('compile');
  const [owner] = await ethers.getSigners();

  console.log('Deploying contracts with the account:', owner.address);

  const StakeVaultFactory = await ethers.getContractFactory("StakeVault");
  const offerPeriod       = 604800;
  const tokenAddress      = '0xeb8f08a975Ab53E34D8a0330E0D34de942C95926'; // Rinkeyby USDC Address

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
