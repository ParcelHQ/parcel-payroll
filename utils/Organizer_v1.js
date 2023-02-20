const ORGANIZER_V1_ABI = [
    {
        inputs: [
            {
                internalType: "address",
                name: "_allowanceAddress",
                type: "address",
            },
            {
                internalType: "address",
                name: "_masterOperator",
                type: "address",
            },
        ],
        stateMutability: "nonpayable",
        type: "constructor",
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: "address",
                name: "safeAddress",
                type: "address",
            },
            {
                indexed: true,
                internalType: "address",
                name: "operator",
                type: "address",
            },
        ],
        name: "ApproverAdded",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: "address",
                name: "safeAddress",
                type: "address",
            },
            {
                indexed: true,
                internalType: "address",
                name: "operator",
                type: "address",
            },
        ],
        name: "ApproverRemoved",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: "address",
                name: "orgAddress",
                type: "address",
            },
        ],
        name: "OrgOffboarded",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: "address",
                name: "orgAddress",
                type: "address",
            },
            {
                indexed: true,
                internalType: "address[]",
                name: "approvers",
                type: "address[]",
            },
            {
                indexed: false,
                internalType: "address[]",
                name: "approvers2",
                type: "address[]",
            },
        ],
        name: "OrgOnboarded",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: false,
                internalType: "address",
                name: "account",
                type: "address",
            },
        ],
        name: "Paused",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: false,
                internalType: "address",
                name: "account",
                type: "address",
            },
        ],
        name: "Unpaused",
        type: "event",
    },
    {
        inputs: [
            { internalType: "address", name: "safeAddress", type: "address" },
            { internalType: "address[]", name: "to", type: "address[]" },
            {
                internalType: "address[]",
                name: "tokenAddress",
                type: "address[]",
            },
            { internalType: "uint128[]", name: "amount", type: "uint128[]" },
            { internalType: "uint64[]", name: "payoutNonce", type: "uint64[]" },
            {
                internalType: "bytes32[][][]",
                name: "proof",
                type: "bytes32[][][]",
            },
            { internalType: "bytes32[]", name: "roots", type: "bytes32[]" },
            { internalType: "bytes[]", name: "signatures", type: "bytes[]" },
            {
                internalType: "address[]",
                name: "paymentTokens",
                type: "address[]",
            },
            {
                internalType: "uint96[]",
                name: "payoutAmounts",
                type: "uint96[]",
            },
        ],
        name: "bulkExecution",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [
            { internalType: "address", name: "to", type: "address" },
            { internalType: "address", name: "tokenAddress", type: "address" },
            { internalType: "uint256", name: "amount", type: "uint256" },
            { internalType: "uint64", name: "payoutNonce", type: "uint64" },
        ],
        name: "encodeTransactionData",
        outputs: [{ internalType: "bytes32", name: "", type: "bytes32" }],
        stateMutability: "pure",
        type: "function",
    },
    {
        inputs: [
            { internalType: "address payable", name: "to", type: "address" },
            { internalType: "address", name: "tokenAddress", type: "address" },
            { internalType: "uint256", name: "amount", type: "uint256" },
            { internalType: "uint64", name: "payoutNonce", type: "uint64" },
            { internalType: "address", name: "safeAddress", type: "address" },
            { internalType: "bytes32[][]", name: "proof", type: "bytes32[][]" },
            { internalType: "bytes32[]", name: "roots", type: "bytes32[]" },
        ],
        name: "executePayout",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [
            { internalType: "address", name: "_safeAddress", type: "address" },
        ],
        name: "getApproverCount",
        outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [
            { internalType: "address", name: "_safeAddress", type: "address" },
        ],
        name: "getApprovers",
        outputs: [{ internalType: "address[]", name: "", type: "address[]" }],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [
            { internalType: "address", name: "_safeAddress", type: "address" },
        ],
        name: "getThreshold",
        outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [
            { internalType: "address", name: "_safeAddress", type: "address" },
            {
                internalType: "address",
                name: "_addressToCheck",
                type: "address",
            },
        ],
        name: "isApprover",
        outputs: [{ internalType: "bool", name: "", type: "bool" }],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [
            {
                internalType: "address",
                name: "_addressToCheck",
                type: "address",
            },
        ],
        name: "isOrgOnboarded",
        outputs: [{ internalType: "bool", name: "", type: "bool" }],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [
            { internalType: "address", name: "_safeAddress", type: "address" },
            {
                internalType: "address[]",
                name: "_addressesToAdd",
                type: "address[]",
            },
            {
                internalType: "address[]",
                name: "_addressesToRemove",
                type: "address[]",
            },
            { internalType: "uint256", name: "newThreshold", type: "uint256" },
        ],
        name: "modifyApprovers",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [
            { internalType: "address", name: "_safeAddress", type: "address" },
        ],
        name: "offboard",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [
            {
                internalType: "address[]",
                name: "_approvers",
                type: "address[]",
            },
            {
                internalType: "uint256",
                name: "approvalsRequired",
                type: "uint256",
            },
        ],
        name: "onboard",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [],
        name: "paused",
        outputs: [{ internalType: "bool", name: "", type: "bool" }],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [
            { internalType: "address", name: "safeAddress", type: "address" },
            { internalType: "bytes32[]", name: "roots", type: "bytes32[]" },
            { internalType: "bytes[]", name: "signatures", type: "bytes[]" },
            {
                internalType: "address[]",
                name: "paymentTokens",
                type: "address[]",
            },
            {
                internalType: "uint96[]",
                name: "payoutAmounts",
                type: "uint96[]",
            },
        ],
        name: "validatePayouts",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
];

module.exports = ORGANIZER_V1_ABI;
