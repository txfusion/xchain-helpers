// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

interface ICrossDomainOptimism {
    function sendMessage(address _target, bytes calldata _message, uint32 _gasLimit) external;
}

interface ICrossDomainArbitrum {
    function createRetryableTicket(
        address to,
        uint256 l2CallValue,
        uint256 maxSubmissionCost,
        address excessFeeRefundAddress,
        address callValueRefundAddress,
        uint256 gasLimit,
        uint256 maxFeePerGas,
        bytes calldata data
    ) external payable returns (uint256);
    function calculateRetryableSubmissionFee(uint256 dataLength, uint256 baseFee) external view returns (uint256);
}

interface ICrossDomainGnosis {
    function requireToPassMessage(address _contract, bytes memory _data, uint256 _gas) external returns (bytes32);
}

interface ICrossDomainZkEVM {
    function bridgeMessage(
        uint32 destinationNetwork,
        address destinationAddress,
        bool forceUpdateGlobalExitRoot,
        bytes calldata metadata
    ) external payable;
}

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

    function l2TransactionBaseCost(
        uint256 _gasPrice,
        uint256 _l2GasLimit,
        uint256 _l2GasPerPubdataByteLimit
    ) external pure returns (uint256);
}

/**
 * @title XChainForwarders
 * @notice Helper functions to abstract over L1 -> L2 message passing.
 * @dev General structure is sendMessageXXX(target, message, gasLimit) where XXX is the remote domain name (IE OptimismMainnet, ArbitrumOne, Base, etc).
 */
library XChainForwarders {

    /// ================================ Optimism Style ================================

    function sendMessageOptimism(
        address l1CrossDomain,
        address target,
        bytes memory message,
        uint256 gasLimit
    ) internal {
        ICrossDomainOptimism(l1CrossDomain).sendMessage(
            target,
            message,
            uint32(gasLimit)
        );
    }

    function sendMessageOptimismMainnet(
        address target,
        bytes memory message,
        uint256 gasLimit
    ) internal {
        sendMessageOptimism(
            0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1,
            target,
            message,
            uint32(gasLimit)
        );
    }

    function sendMessageBase(
        address target,
        bytes memory message,
        uint256 gasLimit
    ) internal {
        sendMessageOptimism(
            0x866E82a600A1414e583f7F13623F1aC5d58b0Afa,
            target,
            message,
            uint32(gasLimit)
        );
    }

    /// ================================ Arbitrum Style ================================

    function sendMessageArbitrum(
        address l1CrossDomain,
        address target,
        bytes memory message,
        uint256 gasLimit
    ) internal {
        // These constants are reasonable estimates based on current market conditions
        // They can be updated as needed
        uint256 maxFeePerGas = 1 gwei;
        uint256 baseFeeMargin = 10 gwei;

        uint256 maxSubmission = ICrossDomainArbitrum(l1CrossDomain).calculateRetryableSubmissionFee(message.length, block.basefee + baseFeeMargin);
        uint256 maxRedemption = gasLimit * maxFeePerGas;
        ICrossDomainArbitrum(l1CrossDomain).createRetryableTicket{value: maxSubmission + maxRedemption}(
            target,
            0, // we always assume that l2CallValue = 0
            maxSubmission,
            address(0), // burn the excess gas
            address(0), // burn the excess gas
            gasLimit,
            maxFeePerGas,
            message
        );
    }

    function sendMessageArbitrumOne(
        address target,
        bytes memory message,
        uint256 gasLimit
    ) internal {
        sendMessageArbitrum(
            0x4Dbd4fc535Ac27206064B68FfCf827b0A60BAB3f,
            target,
            message,
            gasLimit
        );
    }

    function sendMessageArbitrumNova(
        address target,
        bytes memory message,
        uint256 gasLimit
    ) internal {
        sendMessageArbitrum(
            0xc4448b71118c9071Bcb9734A0EAc55D18A153949,
            target,
            message,
            gasLimit
        );
    }

    /// ================================ Gnosis ================================

    function sendMessageGnosis(
        address l1CrossDomain,
        address target,
        bytes memory message,
        uint256 gasLimit
    ) internal {
        ICrossDomainGnosis(l1CrossDomain).requireToPassMessage(
            target,
            message,
            gasLimit
        );
    }

    function sendMessageGnosis(
        address target,
        bytes memory message,
        uint256 gasLimit
    ) internal {
        sendMessageGnosis(
            0x4C36d2919e407f0Cc2Ee3c993ccF8ac26d9CE64e,
            target,
            message,
            gasLimit
        );
    }

    /// ================================ zkEVM ================================

    function sendMessageZkEVM(
        address l1CrossDomain,
        uint32 destinationNetworkId,
        address destinationAddress,
        bool forceUpdateGlobalExitRoot,
        bytes memory metadata
    ) internal {
        ICrossDomainZkEVM(l1CrossDomain).bridgeMessage(
            destinationNetworkId,
            destinationAddress,
            forceUpdateGlobalExitRoot,
            metadata
        );
    }

    function sendMessageZkEVM(
        address destinationAddress,
        bytes memory metadata
    ) internal {
        sendMessageZkEVM(
            0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe,
            1,
            destinationAddress,
            true,
            metadata
        );
    }

    /// ================================ zkSync Era Style ================================

    function sendMessageZkSyncEra(
        address l1CrossDomain,
        address contractAddr,
        bytes memory data,
        uint256 gasLimit,
        uint256 gasPerPubdataByteLimit
    ) internal {
        uint256 maxFeePerGas = 1 gwei;
        uint256 baseCost = ICrossDomainZkSync(l1CrossDomain)
            .l2TransactionBaseCost(
                maxFeePerGas,
                gasLimit,
                gasPerPubdataByteLimit
            );

        ICrossDomainZkSync(l1CrossDomain).requestL2Transaction{value: baseCost}(
            contractAddr,
            0,
            data,
            gasLimit,
            gasPerPubdataByteLimit,
            new bytes[](0),
            msg.sender
        );
    }

    function sendMessageZkSyncEraMainnet(
        address contractAddr,
        bytes memory data,
        uint256 gasLimit,
        uint256 gasPerPubdataByteLimit
    ) internal {
        sendMessageZkSyncEra(
            0x32400084C286CF3E17e7B677ea9583e60a000324,
            contractAddr,
            data,
            gasLimit,
            gasPerPubdataByteLimit
        );
    }

    function sendMessageZkSyncEraTestnet(
        address contractAddr,
        bytes memory data,
        uint256 gasLimit,
        uint256 gasPerPubdataByteLimit
    ) internal {
        sendMessageZkSyncEra(
            0x1908e2BF4a88F91E4eF0DC72f02b8Ea36BEa2319,
            contractAddr,
            data,
            gasLimit,
            gasPerPubdataByteLimit
        );
    }
}
