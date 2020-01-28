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
 *  @title GTCR Factory and registry of deployed contracts.
 */
contract GTCRFactory {
    // Storage

    address public target; // The contract that will be cloned.
    address public governor; // The address allowed to change the target.
    address[] public instances;
    mapping(address => uint256) addressToIndex;

    /**
     *  @dev Emitted when a new Generalized TCR contract is deployed using this factory.
     *  @param _address The address of the newly deployed Generalized TCR.
     */
    event NewGTCR(address indexed _address);

    modifier onlyGovernor {
        require(msg.sender == governor, "The caller must be the governor.");
        _;
    }

    constructor(address _governor, address _target) public {
        governor = _governor;
        target = _target;
    }

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
    function createClone() external {
        address instance;
        address inMemoryTarget = target;

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
        }

        instances.push(instance);
        addressToIndex[instance] = instances.length - 1;
        emit NewGTCR(instance);
    }

    function changeTarget(address _target) external onlyGovernor {
        target = _target;
    }

    /**
     * @return The number of deployed tcrs using this factory.
     */
    function count() external view returns (uint256) {
        return instances.length;
    }
}
