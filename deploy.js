const solc = require('solc');
const fs = require('fs');
const path = require('path');
const { createPublicClient, http, defineChain } = require('viem');
const { privateKeyToAccount } = require('viem/accounts');

const chain = defineChain({
  id: 1979,
  name: 'Ritual Testnet',
  nativeCurrency: { name: 'CRAT', symbol: 'CRAT', decimals: 18 },
  rpcUrls: { default: { http: ['https://rpc.ritualfoundation.org'] } },
});

require('dotenv').config();
const account = privateKeyToAccount(process.env.PRIVATE_KEY);
const client = createPublicClient({ chain, transport: http() });

function compileContract(name) {
  const source = fs.readFileSync(path.join(__dirname, `contracts/${name}.sol`), 'utf8');
  const input = {
    language: 'Solidity',
    sources: { [`${name}.sol`]: { content: source } },
    settings: {
      outputSelection: { '*': { '*': ['abi', 'evm.bytecode'] } },
      optimizer: { enabled: true, runs: 200 },
    },
  };
  
  const output = JSON.parse(solc.compile(JSON.stringify(input)));
  if (output.errors) {
    const errs = output.errors.filter(e => e.severity === 'error');
    if (errs.length > 0) throw new Error(errs.map(e => e.message).join('\n'));
  }
  
  const contract = output.contracts[`${name}.sol`][name];
  return {
    abi: contract.abi,
    bytecode: `0x${contract.evm.bytecode.object}`,
  };
}

async function deploy(name) {
  console.log(`\nCompiling ${name}...`);
  const { abi, bytecode } = compileContract(name);
  console.log(`  Bytecode: ${bytecode.length} chars`);
  
  const [nonce, fees] = await Promise.all([
    client.getTransactionCount({ address: account.address }),
    client.estimateFeesPerGas(),
  ]);
  
  const tx = {
    data: bytecode,
    gas: 5_000_000n,
    nonce,
    maxFeePerGas: fees.maxFeePerGas + fees.maxFeePerGas / 10n,
    maxPriorityFeePerGas: fees.maxPriorityFeePerGas,
    chainId: 1979,
    type: 'eip1559',
  };
  
  console.log(`  Deploying from: ${account.address}`);
  const signed = await account.signTransaction(tx);
  const hash = await client.request({ method: 'eth_sendRawTransaction', params: [signed] });
  console.log(`  TX Hash: ${hash}`);
  
  console.log(`  Waiting for receipt...`);
  let receipt = null;
  for (let i = 0; i < 60; i++) {
    try {
      receipt = await client.getTransactionReceipt({ hash });
      break;
    } catch {
      await new Promise(r => setTimeout(r, 3000));
    }
  }
  
  if (!receipt) throw new Error('Deployment timed out');
  console.log(`  Contract Address: ${receipt.contractAddress}`);
  console.log(`  Block: ${receipt.blockNumber}`);
  console.log(`  Gas Used: ${receipt.gasUsed}`);
  
  // Save ABI
  fs.writeFileSync(
    path.join(__dirname, `contracts/${name}.abi.json`),
    JSON.stringify(abi, null, 2)
  );
  
  return { address: receipt.contractAddress, txHash: hash, abi };
}

async function main() {
  console.log('=== Ritual Homework: CommitRevealBounty Deployment ===');
  console.log(`Wallet: ${account.address}`);
  
  const bal = await client.getBalance({ address: account.address });
  console.log(`Balance: ${Number(bal) / 1e18} CRAT`);
  
  const bounty = await deploy('CommitRevealBounty');
  
  console.log('\n=== Deployment Summary ===');
  console.log(`CommitRevealBounty: ${bounty.address}`);
  console.log(`  TX: ${bounty.txHash}`);
  
  // Save to .env
  const envPath = path.join(__dirname, '.env');
  let env = '';
  if (fs.existsSync(envPath)) {
    env = fs.readFileSync(envPath, 'utf8');
  }
  
  if (!env.includes('COMMIT_REVEAL_BOUNTY=')) {
    env += `\nCOMMIT_REVEAL_BOUNTY=${bounty.address}\n`;
  } else {
    env = env.replace(/COMMIT_REVEAL_BOUNTY=.*/, `COMMIT_REVEAL_BOUNTY=${bounty.address}`);
  }
  
  fs.writeFileSync(envPath, env);
  
  console.log('\n.env updated with contract address.');
  console.log('Done!');
}

main().catch(console.error);
