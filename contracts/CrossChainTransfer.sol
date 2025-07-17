// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CrossChainTransfer is Ownable {
    IRouterClient public immutable router;
    IERC20 public immutable token;
    uint64 public immutable destinationChainSelector;
    bool public isPaused;

    event TransferInitiated(
        uint64 indexed chain,
        address receiver,
        uint256 amount
    );
    error InsufficientFeeTokenBalance(
        uint256 currentBalance,
        uint256 calculatedFees
    );
    error TransferFailed(string reason);

    modifier whenNotPaused() {
        require(!isPaused, "Contract paused");
        _;
    }

    constructor(address _router, address _token, uint64 _selector) {
        _transferOwnership(msg.sender);
        router = IRouterClient(_router);
        token = IERC20(_token);
        destinationChainSelector = _selector;
    }

    function transferTokens(
        address receiver,
        uint256 amount,
        uint256 minAmountOut
    ) external onlyOwner whenNotPaused {
        require(
            token.balanceOf(address(this)) >= amount,
            "Insufficient balance"
        );

        // ✅ Fixed: Proper array declaration
        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(token),
            amount: amount
        });

        // ✅ Construct the cross-chain message
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: abi.encode(minAmountOut),
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 500000})
            ),
            feeToken: address(0)
        });

        uint256 fees = router.getFee(destinationChainSelector, message);
        if (address(this).balance < fees) {
            revert InsufficientFeeTokenBalance(address(this).balance, fees);
        }

        try router.ccipSend{value: fees}(destinationChainSelector, message) {
            emit TransferInitiated(destinationChainSelector, receiver, amount);
        } catch (bytes memory reason) {
            revert TransferFailed(string(reason));
        }
    }

    function pause() external onlyOwner {
        isPaused = true;
    }

    function unpause() external onlyOwner {
        isPaused = false;
    }

    function emergencyWithdrawETH(address recipient) external onlyOwner {
        (bool success, ) = recipient.call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }

    receive() external payable {}
}
