// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/proxy/Proxy.sol";

contract UnstructuredProxy is Proxy {
    
    // Storage position of the address of the current implementation
    bytes32 private constant implementationPosition = 
        keccak256("org.smartdefi.implementation.address");
    
    // Storage position of the owner of the contract
    bytes32 private constant proxyOwnerPosition = 
        keccak256("org.smartdefi.proxy.owner");
    
    /**
    * @dev Throws if called by any account other than the owner.
    */
    modifier onlyProxyOwner() {
        require (msg.sender == proxyOwner(), "Not Proxy owner");
        _;
    }
    
    /**
    * @dev the constructor sets owner
    */
    constructor() {
        _setUpgradeabilityOwner(msg.sender);
    }

    /**
     * @dev Allows the current owner to transfer ownership
     * @param _newOwner The address to transfer ownership to
     */
    function transferProxyOwnership(address _newOwner) 
        public onlyProxyOwner 
    {
        require(_newOwner != address(0));
        _setUpgradeabilityOwner(_newOwner);
    }
    
    /**
     * @dev Allows the proxy owner to upgrade the implementation
     * @param _impl address of the new implementation
     */
    function upgradeTo(address _impl) 
        public onlyProxyOwner
    {
        _upgradeTo(_impl);
    }
    
    /**
     * @dev Tells the address of the current implementation
     * @return impl address of the current implementation
     */
    function _implementation()
        internal
        view
        override
        returns (address impl)
    {
        bytes32 position = implementationPosition;
        assembly {
            impl := sload(position)
        }
    }

    function implementation() external view returns (address) {
        return _implementation();
    }
    
    /**
     * @dev Tells the address of the owner
     * @return owner the address of the owner
     */
    function proxyOwner() public view returns (address owner) {
        bytes32 position = proxyOwnerPosition;
        assembly {
            owner := sload(position)
        }
    }
    
    /**
     * @dev Sets the address of the current implementation
     * @param _newImplementation address of the new implementation
     */
    function _setImplementation(address _newImplementation) 
        internal 
    {
        bytes32 position = implementationPosition;
        assembly {
            sstore(position, _newImplementation)
        }
    }
    
    /**
     * @dev Upgrades the implementation address
     * @param _newImplementation address of the new implementation
     */
    function _upgradeTo(address _newImplementation) internal {
        address currentImplementation = _implementation();
        require(currentImplementation != _newImplementation);
        _setImplementation(_newImplementation);
    }
    
    /**
     * @dev Sets the address of the owner
     */
    function _setUpgradeabilityOwner(address _newProxyOwner) 
        internal 
    {
        bytes32 position = proxyOwnerPosition;
        assembly {
            sstore(position, _newProxyOwner)
        }
    }
}
