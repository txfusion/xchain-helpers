// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./IntegrationBase.t.sol";

import {ZkSyncDomain} from "../src/testing/ZkSyncDomain.sol";

contract ZkSyncIntegrationTest is IntegrationBaseTest {
    uint256 forkId;

    function test_zkSyncEra() public {
        setChain(
            "zksync_era",
            ChainData("zkSync Era", 324, "https://mainnet.era.zksync.io")
        );
        checkZkSyncStyle(new ZkSyncDomain(getChain("zksync_era"), mainnet));
    }

    function test_zkSyncEraTestnet() public {
        setChain(
            "zksync_era_testnet",
            ChainData("zkSync Era Testnet", 280, "https://testnet.era.zksync.dev")
        );
        checkZkSyncStyle(new ZkSyncDomain(getChain("zksync_era_testnet"), goerli));
    }

    function checkZkSyncStyle(ZkSyncDomain zkSync) public {
        Domain host = zkSync.hostDomain();

        forkId = host.forkId();

        host.selectFork();

        MessageOrdering moHost = new MessageOrdering();

        zkSync.selectFork();

        MessageOrdering moZkSync = new MessageOrdering();

        // zkSync.L2_MESSENGER().sendToL1(
        //     abi.encodePacked(
        //         address(moHost),
        //         abi.encodeWithSelector(MessageOrdering.push.selector, 3)
        //     )
        // );

        host.selectFork();

        XChainForwarders.sendMessageZkSyncEra(
            address(zkSync.MAILBOX()),
            address(moZkSync),
            abi.encodeWithSelector(MessageOrdering.push.selector, 1),
            10_000_000_0,
            800
        );
        XChainForwarders.sendMessageZkSyncEra(
            address(zkSync.MAILBOX()),
            address(moZkSync),
            abi.encodeWithSelector(MessageOrdering.push.selector, 2),
            10_000_000_0,
            800
        );

        assertEq(moHost.length(), 0);

        zkSync.relayFromHost(true);

        assertEq(moZkSync.length(), 2);
        assertEq(moZkSync.messages(0), 1);
        assertEq(moZkSync.messages(1), 2);
    }
}
