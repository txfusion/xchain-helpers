// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./IntegrationBase.t.sol";

import {ZkSyncDomain} from "../src/testing/ZkSyncDomain.sol";
import "forge-std/console.sol";

contract ZkSyncIntegrationTest is IntegrationBaseTest {
    uint256 forkId;

    function test_zksync() public {
        console.log("This is zksync test");
        setChain(
            "zksync",
            ChainData("ZkSync", 324, "https://mainnet.era.zksync.io")
        );
        checkZkSyncStyle(new ZkSyncDomain(getChain("zksync"), mainnet));
    }

    function checkZkSyncStyle(ZkSyncDomain zksync) public {
        console.log("This is checkzksyncstyle()");
        Domain host = zksync.hostDomain();

        forkId = host.forkId();

        host.selectFork();

        MessageOrdering moHost = new MessageOrdering();

        zksync.selectFork();

        MessageOrdering moZkSync = new MessageOrdering();

        // zksync.L2_MESSENGER().sendToL1(
        //     abi.encodePacked(
        //         address(moHost),
        //         abi.encodeWithSelector(MessageOrdering.push.selector, 3)
        //     )
        // );

        host.selectFork();

        XChainForwarders.sendMessageZkSyncEra(
            address(moZkSync),
            abi.encodeWithSelector(MessageOrdering.push.selector, 1),
            10_000_000_0,
            800
        );
        XChainForwarders.sendMessageZkSyncEra(
            address(moZkSync),
            abi.encodeWithSelector(MessageOrdering.push.selector, 2),
            10_000_000_0,
            800
        );

        zksync.relayFromHost(true);

        assertEq(moZkSync.length(), 2);
        assertEq(moZkSync.messages(0), 1);
        assertEq(moZkSync.messages(1), 2);
    }
}
