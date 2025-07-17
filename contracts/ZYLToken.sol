// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ZYLToken is Initializable, ERC20BurnableUpgradeable, ERC20PermitUpgradeable, OwnableUpgradeable, PausableUpgradeable, UUPSUpgradeable {
    bool public isPaused;
    mapping(address => bool) public blacklist;

    event Blacklisted(address indexed account, bool isBlacklisted);
    event EmergencyWithdraw(address indexed recipient, uint256 amount);
    event RescueERC20(address indexed token, address indexed recipient, uint256 amount);

    modifier whenNotBlacklisted(address account) {
        require(!blacklist[account], "Blacklisted address");
        _;
    }

    function initialize(address initialOwner) public initializer {
        __ERC20_init("Zylithium", "ZYL");
        __ERC20Burnable_init();
        __ERC20Permit_init("Zylithium");
        __Ownable_init(); // ✅ FIXED
        transferOwnership(initialOwner); // ✅ FIXED
        __Pausable_init();
        __UUPSUpgradeable_init();

        _mint(initialOwner, 1_000_000_000 * 10 ** decimals()); // ✅ 1 Billion ZYL
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function mint(address to, uint256 amount) public onlyOwner whenNotPaused whenNotBlacklisted(to) {
        _mint(to, amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setBlacklist(address account, bool value) external onlyOwner {
        blacklist[account] = value;
        emit Blacklisted(account, value);
    }

    function emergencyWithdrawETH(address recipient) external onlyOwner {
        uint256 amount = address(this).balance;
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Transfer failed");
        emit EmergencyWithdraw(recipient, amount);
    }

    function rescueERC20(address tokenAddress, address recipient, uint256 amount) external onlyOwner {
        IERC20(tokenAddress).transfer(recipient, amount);
        emit RescueERC20(tokenAddress, recipient, amount);
    }

    receive() external payable {}
    fallback() external payable {}
}