/**
 *  @authors: [@mtsalenc]
 *  @reviewers: []
 *  @auditors: []
 *  @bounties: []
 *  @deployments: []
 */

pragma solidity ^0.5.16;

/* solium-disable max-len */

/**
 *  @title Factory and registry of deployed contracts.
 */
contract Factory {

    address public blueprint; // The contract that will be cloned.
    address public governor; // The address allowed to change the blueprint and the governor.
    address[] public instances;
    mapping(address => uint256) addressToIndex;

    /**
     *  @dev Emitted when a new contract is deployed using this factory.
     *  @param _address The address of the newly deployed contract.
     *  @param _creator The address that deployed the new clone.
     */
    event NewInstance(address indexed _address, address indexed _creator);

    modifier onlyGovernor {
        require(msg.sender == governor, "The caller must be the governor.");
        _;
    }

    /**
     *  @dev Constructs the factory.
     *  @param _governor The address allowed to change the blueprint
     *  @param _blueprint The address of the contract that will be cloned.
     */
    constructor(address _governor, address _blueprint) public {
        governor = _governor;
        blueprint = _blueprint;
    }

    /**
     *  @dev Clones and deploys the blueprint contract.
     */
    function createClone() external {
        address instance;
        address inMemoryTarget = blueprint;

        /** Reference implementation: https://gist.github.com/holiman/069de8d056a531575d2b786df3345665
        *
        *   Assembly of the code that we want to use as init-code in the new contract,
        *   along with stack values:
        *                  # bottom [ STACK ] top
        *   PUSH1 00       # [ 0 ]
        *   DUP1           # [ 0, 0 ]
        *   PUSH20
        *   <address>      # [0,0, address]
        *   DUP1		    # [0,0, address ,address]
        *   EXTCODESIZE    # [0,0, address, size ]
        *   DUP1           # [0,0, address, size, size]
        *   SWAP4          # [ size, 0, address, size, 0]
        *   DUP1           # [ size, 0, address ,size, 0,0]
        *   SWAP2          # [ size, 0, address, 0, 0, size]
        *   SWAP3          # [ size, 0, size, 0, 0, address]
        *   EXTCODECOPY    # [ size, 0]
        *   RETURN
        *
        *   The code above weighs in at 33 bytes, which is _just_ above fitting into a uint.
        *   So a modified version is used, where the initial PUSH1 00 is replaced by `PC`.
        *   This is one byte smaller, and also a bit cheaper Wbase instead of Wverylow. It only costs 2 gas.
        *
        *   PC             # [ 0 ]
        *   DUP1           # [ 0, 0 ]
        *   PUSH20
        *   <address>      # [0,0, address]
        *   DUP1		    # [0,0, address ,address]
        *   EXTCODESIZE    # [0,0, address, size ]
        *   DUP1           # [0,0, address, size, size]
        *   SWAP4          # [ size, 0, address, size, 0]
        *   DUP1           # [ size, 0, address ,size, 0,0]
        *   SWAP2          # [ size, 0, address, 0, 0, size]
        *   SWAP3          # [ size, 0, size, 0, 0, address]
        *   EXTCODECOPY    # [ size, 0]
        *   RETURN
        *
        *   The opcodes are:
        *   58 80 73 <address> 80 3b 80 93 80 91 92 3c F3
        *   We get <address> in there by OR:ing the upshifted address into the 0-filled space.
        *   5880730000000000000000000000000000000000000000803b80938091923cF3
        *   +000000xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx000000000000000000
        *   -----------------------------------------------------------------
        *   588073xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx00000803b80938091923cF3
        *
        *   This is simply stored at memory position 0, and create is invoked.
        */
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            mstore(
                0x0,
                or(
                    0x5880730000000000000000000000000000000000000000803b80938091923cF3,
                    mul(inMemoryTarget, 0x1000000000000000000)
                )
            )
            instance := create(0, 0, 32)

            // Revert if the deployment failed.
            if iszero(extcodesize(instance)) { revert(0,0) }
        }

        instances.push(instance);
        addressToIndex[instance] = instances.length - 1;
        emit NewInstance(instance, msg.sender);
    }

    /** @dev Change the address of the contract to be cloned.
     *  @param _blueprint The address of the new target.
     */
    function changeBlueprint(address _blueprint) external onlyGovernor {
        blueprint = _blueprint;
    }

    /** @dev Change the governor of the factory
     *  @param _governor The address of the new governor.
     */
    function changeGovernor(address _governor) external onlyGovernor {
        governor = _governor;
    }

    /**
     * @return The number of deployed contracts using this factory.
     */
    function count() external view returns (uint256) {
        return instances.length;
    }
}
