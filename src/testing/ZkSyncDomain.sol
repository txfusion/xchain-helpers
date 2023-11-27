// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import {StdChains} from "forge-std/StdChains.sol";
import {Vm} from "forge-std/Vm.sol";

import {Domain, BridgedDomain} from "./BridgedDomain.sol";
import {RecordedLogs} from "./RecordedLogs.sol";

//used for l1->l2 communication
interface ICrossDomainZkSync {
    function requestL2Transaction(
        address _contractL2,
        uint256 _l2Value,
        bytes calldata _calldata,
        uint256 _l2GasLimit,
        uint256 _l2GasPerPubdataByteLimit,
        bytes[] calldata _factoryDeps,
        address _refundRecipient
    ) external payable returns (bytes32 canonicalTxHash);

    // function callZkSync(
    //     address contractAddr,
    //     bytes memory data,
    //     uint256 gasLimit,
    //     uint256 gasPerPubdataByteLimit
    // ) external payable;
}

interface IL1Messenger {
    // Possibly in the future we will be able to track the messages sent to L1 with
    // some hooks in the VM. For now, it is much easier to track them with L2 events.
    event L1MessageSent(
        address indexed _sender,
        bytes32 indexed _hash,
        bytes _message
    );

    function sendToL1(bytes memory _message) external returns (bytes32);

    function sendL2ToL1Log(
        bool _isService,
        bytes32 _key,
        bytes32 _value
    ) external returns (uint256 logIdInMerkleTree);
}

struct L2CanonicalTransaction {
    uint256 txType;
    uint256 from;
    uint256 to;
    uint256 gasLimit;
    uint256 gasPerPubdataByteLimit;
    uint256 maxFeePerGas;
    uint256 maxPriorityFeePerGas;
    uint256 paymaster;
    uint256 nonce;
    uint256 value;
    uint256[4] reserved;
    bytes data;
    bytes signature;
    uint256[] factoryDeps;
    bytes paymasterInput;
    bytes reservedDynamic;
}

/**
    emit NewPriorityRequest(
            _priorityOpParams.txId,
            canonicalTxHash,
            _priorityOpParams.expirationTimestamp,
            transaction,
            _factoryDeps
        );
 */

contract ZkSyncDomain is BridgedDomain {
    ICrossDomainZkSync public L1_MESSENGER;

    uint160 private constant SYSTEM_CONTRACTS_OFFSET = 0x8000; // 2^15

    /// @notice Address of the zkSync's L2Messenger contract
    IL1Messenger public constant L2_MESSENGER =
        IL1Messenger(address(SYSTEM_CONTRACTS_OFFSET + 0x08));

    bytes32 constant L1_EVENT_TOPIC =
        keccak256(
            "NewPriorityRequest(uint256,bytes32,uint64,L2CannonicalTransaction,bytes[])"
        );

    bytes32 constant L1_MESSAGE_SENT_TOPIC =
        keccak256("L1MessageSent(address, bytes32, bytes)");

    uint256 internal lastFromHostLogIndex;
    uint256 internal lastToHostLogIndex;

    constructor(
        StdChains.Chain memory _chain,
        Domain _hostDomain
    ) Domain(_chain) BridgedDomain(_hostDomain) {
        bytes32 name = keccak256(bytes(_chain.chainAlias));
        if (name == keccak256("zksync")) {
            L1_MESSENGER = ICrossDomainZkSync(
                0x32400084C286CF3E17e7B677ea9583e60a000324
            );
        } else {
            revert("Unsupported chain");
        }
        vm.recordLogs();
    }

    function relayFromHost(bool switchToGuest) external override {
        selectFork();

        // Read all L1 -> L2 messages and relay them under zkevm fork
        Vm.Log[] memory logs = RecordedLogs.getLogs();
        for (; lastFromHostLogIndex < logs.length; lastFromHostLogIndex++) {
            Vm.Log memory log = logs[lastFromHostLogIndex];
            if (
                log.topics[0] == L1_EVENT_TOPIC &&
                log.emitter == address(L1_MESSENGER)
            ) {
                (
                    uint256 txId,
                    bytes32 txHash,
                    uint64 expirationTimestamp,
                    L2CanonicalTransaction memory transaction,
                    bytes[] memory factoryDeps
                ) = abi.decode(
                        log.data,
                        (
                            uint256,
                            bytes32,
                            uint64,
                            L2CanonicalTransaction,
                            bytes[]
                        )
                    );

                //message should be automatically executed (check how it works on different rollups)
                // (bool success, bytes memory response) = target.call(message);
            }
        }

        if (!switchToGuest) {
            hostDomain.selectFork();
        }
    }

    function relayToHost(bool switchToHost) external override {
        hostDomain.selectFork();

        // Read all L2 -> L1 messages and relay them under Primary fork
        Vm.Log[] memory logs = RecordedLogs.getLogs();
        for (; lastToHostLogIndex < logs.length; lastToHostLogIndex++) {
            Vm.Log memory log = logs[lastToHostLogIndex];
            if (
                log.topics[0] == L1_MESSAGE_SENT_TOPIC &&
                log.emitter == address(L2_MESSENGER)
            ) {
                (address sender, bytes32 _hash, bytes memory message) = abi
                    .decode(log.data, (address, bytes32, bytes));

                //1. prove the L2 message inclusion
                //2. execute message on L1
                (address target, bytes memory _calldata) = parseMessage(
                    message
                );

                (bool success, bytes memory response) = target.call(_calldata);
            }
        }

        if (!switchToHost) {
            selectFork();
        }
    }

    function parseMessage(
        bytes memory message
    ) internal returns (address _target, bytes memory _calldata) {
        assembly {
            _target := mload(add(message, 0x14))
            _calldata := mload(add(message, 0x38))
        }
        // _target = 0xc4448b71118c9071Bcb9734A0EAc55D18A153949; //need change TODO
        // _calldata = "";

        // uint256 offset;
        // (_target, offset) = UnsafeBytes.readAddress(_l2ToL1message, 0);
        // (_calldata, ) = UnsafeBytes.Read(_l2ToL1message, offset);
    }
}
