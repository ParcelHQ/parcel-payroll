# Parcel Payroll

### **Summary**

There are no tools designed for crypto payroll. We want to change that by building the infrastructure from ground up with our smart contracts.

Our smart contract utilizes funds stored in [Gnosis Safe multisig](https://github.com/safe-global/safe-contracts) with the [spending limit module](https://goerli.etherscan.io/address/0xCFbFaC74C26F8647cBDb8c5caf80BB5b32E43134#code) enabled for secure and flexible management of funds.

### **Technical Specification**

The contracts are written in Solidity version 0.8.9 and are compatible to run on all EVM-based chains. The project setup for Parcel's smart contract is being done using Hardhat, a development environment for building and testing smart contracts. The unit tests for the smart contract are written in Waffle, a library that provides a set of helper functions for testing smart contracts.

### External Contracts Used:

 [Gnosis Safe Contracts](https://github.com/safe-global/safe-contracts) and [Allowance Module](https://goerli.etherscan.io/address/0xCFbFaC74C26F8647cBDb8c5caf80BB5b32E43134#code)


### For More Information Please Visit
[Tech Documentation](https://parcelhq.notion.site/Parcel-Payroll-SC-Documentation-539f9a1a75a541a79b8f5809b66b62e1)
