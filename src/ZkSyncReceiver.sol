// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

/**
 * @title ZkSyncReceiver
 * @notice Receive messages to an zkSync-style chain.
 */
abstract contract ZkSyncReceiver {

    address public immutable l1Authority;
    uint160 private constant OFFSET = uint160(0x1111000000000000000000000000000000001111);

    constructor(
        address _l1Authority
    ) {
        l1Authority = _l1Authority;
    }

    function _getL1MessageSender() internal view returns (address) {
        unchecked {
            return address(uint160(msg.sender) - OFFSET);
        }
    }

    function _onlyCrossChainMessage() internal view {
        require(_getL1MessageSender() == l1Authority, "Receiver/invalid-l1Authority");
    }

    modifier onlyCrossChainMessage() {
        _onlyCrossChainMessage();
        _;
    }

}
