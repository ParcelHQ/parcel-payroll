// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { ethers, tenderly } = require("hardhat");
const { ALLOWANCE_MODULE } = require("../utils/constant");
const { default: MerkleTree } = require("merkletreejs");

async function main() {
  // Hardhat always runs the compile task when running scripts through it.
  // If this runs in a standalone fashion you may want to call compile manually
  // to make sure everything is compiled
  // await run("compile");
  // We get the contract to deploy

  const [masterOperator] = await ethers.getSigners();

  // Get Contract from address
  const Organizer = await ethers.getContractAt(
    "Organizer",
    "0x04556aE158A02Cc0a4b64112A1DD6cd022D521Eb"
  );

  const BASE_PAYOUT_NONCE = 0;

  tenderly.verify({
    address: Organizer.address,
    name: "Organizer",
  });

  const MULTISIG_ADDRESS = "0xe428E496A0cAC7720593234c5Ae302b085aaE9Ef";

  const [operator1, operator2] = await ethers.getSigners();
  console.log(operator1.address);
  console.log(operator2.address);
  const payouts = [];

  payouts[0] = {
    to: "0x4789a8423004192D55dCDD81fCbA47dA47D290aD",
    tokenAddress: "0x07865c6E87B9F70255377e024ace6630C1Eaa37F",
    amount: 100,
    payoutNonce: BASE_PAYOUT_NONCE + 7,
  };
  payouts[1] = {
    to: "0x4789a8423004192D55dCDD81fCbA47dA47D290aD",
    tokenAddress: "0x07865c6E87B9F70255377e024ace6630C1Eaa37F",
    amount: 100,
    payoutNonce: BASE_PAYOUT_NONCE + 1,
  };
  payouts[2] = {
    to: "0x4789a8423004192D55dCDD81fCbA47dA47D290aD",
    tokenAddress: "0x07865c6E87B9F70255377e024ace6630C1Eaa37F",
    amount: 100,
    payoutNonce: BASE_PAYOUT_NONCE + 2,
  };
  payouts[3] = {
    to: "0x4789a8423004192D55dCDD81fCbA47dA47D290aD",
    tokenAddress: "0x07865c6E87B9F70255377e024ace6630C1Eaa37F",
    amount: 100,
    payoutNonce: BASE_PAYOUT_NONCE + 3,
  };
  payouts[4] = {
    to: "0x4789a8423004192D55dCDD81fCbA47dA47D290aD",
    tokenAddress: "0x07865c6E87B9F70255377e024ace6630C1Eaa37F",
    amount: 100,
    payoutNonce: BASE_PAYOUT_NONCE + 4,
  };
  payouts[5] = {
    to: "0x4789a8423004192D55dCDD81fCbA47dA47D290aD",
    tokenAddress: "0x07865c6E87B9F70255377e024ace6630C1Eaa37F",
    amount: 100,
    payoutNonce: BASE_PAYOUT_NONCE + 5,
  };
  payouts[6] = {
    to: "0x4789a8423004192D55dCDD81fCbA47dA47D290aD",
    tokenAddress: "0x07865c6E87B9F70255377e024ace6630C1Eaa37F",
    amount: 100,
    payoutNonce: BASE_PAYOUT_NONCE + 6,
  };
  const encodedHashes = [];
  encodedHashes[0] = await Organizer.connect(operator1).encodeTransactionData(
    payouts[0].to,
    payouts[0].tokenAddress,
    payouts[0].amount,
    payouts[0].payoutNonce
  );
  // console.log(encodedHash_0);
  encodedHashes[1] = await Organizer.connect(operator1).encodeTransactionData(
    payouts[1].to,
    payouts[1].tokenAddress,
    payouts[1].amount,
    payouts[1].payoutNonce
  );
  // console.log(encodedHash_1);
  encodedHashes[2] = await Organizer.connect(operator1).encodeTransactionData(
    payouts[2].to,
    payouts[2].tokenAddress,
    payouts[2].amount,
    payouts[2].payoutNonce
  );
  // console.log(encodedHash_2);
  encodedHashes[3] = await Organizer.connect(operator1).encodeTransactionData(
    payouts[3].to,
    payouts[3].tokenAddress,
    payouts[3].amount,
    payouts[3].payoutNonce
  );
  // console.log(encodedHash_3);
  encodedHashes[4] = await Organizer.connect(operator1).encodeTransactionData(
    payouts[4].to,
    payouts[4].tokenAddress,
    payouts[4].amount,
    payouts[4].payoutNonce
  );
  // console.log(encodedHash_4);
  encodedHashes[5] = await Organizer.connect(operator1).encodeTransactionData(
    payouts[5].to,
    payouts[5].tokenAddress,
    payouts[5].amount,
    payouts[5].payoutNonce
  );

  // console.log(encodedHash_5);

  encodedHashes[6] = await Organizer.connect(operator1).encodeTransactionData(
    payouts[6].to,
    payouts[6].tokenAddress,
    payouts[6].amount,
    payouts[6].payoutNonce
  );

  // console.log(encodedHash_6);

  // // Creating Root Hashes Per Approver
  const leaves_1 = ([] = [
    encodedHashes[0],
    encodedHashes[1],
    encodedHashes[2],
    encodedHashes[3],
    encodedHashes[4],
    encodedHashes[5],
    encodedHashes[6],
  ]);

  const leaves_2 = ([] = [
    encodedHashes[0],
    encodedHashes[1],
    encodedHashes[3],
    encodedHashes[2],
    encodedHashes[4],
    encodedHashes[5],
    encodedHashes[6],
  ]);

  const tree_1 = new MerkleTree(leaves_1, ethers.utils.keccak256, {
    sortPairs: true,
  });

  const tree_2 = new MerkleTree(leaves_2, ethers.utils.keccak256, {
    sortPairs: true,
  });

  //  Generating Node Hash
  const root_1 = "0x" + tree_1.getRoot().toString("hex");
  const root_2 = "0x" + tree_2.getRoot().toString("hex");

  // Creating Signatures
  const PayrollTx = [{ name: "rootHash", type: "bytes32" }];

  let domainData = {
    chainId: 5,
    verifyingContract: Organizer.address,
  };

  const operator1Sign = await operator1._signTypedData(
    domainData,
    {
      PayrollTx: PayrollTx,
    },
    { rootHash: root_1 }
  );

  const operator2Sign = await operator2._signTypedData(
    domainData,
    {
      PayrollTx: PayrollTx,
    },
    { rootHash: root_2 }
  );

  console.log(operator1Sign, operator2Sign, "Signature Done");

  const payoutArgs = payouts.map((payout, i) => {
    const proof_1 = tree_1.getHexProof(encodedHashes[i]);
    const proof_2 = tree_2.getHexProof(encodedHashes[i]);
    return {
      recipient: payout.to,
      tokenAddress: payout.tokenAddress,
      amount: payout.amount,
      payoutNonce: payout.payoutNonce,
      rootIndexes: [0, 1],
      signatureIndexes: [0, 1],
      merkleProofs: [proof_1, proof_2],
    };
  });

  console.log(payoutArgs, "Payout Args");

  // // Executing Payouts
  const tx = await Organizer.connect(operator1).executePayouts(
    payoutArgs,
    [root_1, root_2],
    [operator1Sign, operator2Sign],
    MULTISIG_ADDRESS,
    {
      gasLimit: 9000000,
    }
  );

  console.log(tx, "Transaction");

  const receipt = await tx.wait();

  console.log(receipt, "Receipt");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
