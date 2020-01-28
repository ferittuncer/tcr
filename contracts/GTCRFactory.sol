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
 *  @title GTCR Factory
 *  An EIP 1167 implementation and registry of GeneralizedTCR instances.
 *
 *  https://eips.ethereum.org/EIPS/eip-1167
 *  Reference implementation: https://github.com/optionality/clone-factory
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

    modifier onlyGovernor {require(msg.sender == governor, "The caller must be the governor."); _;}

    constructor(address _governor, address _target) public {
        governor = _governor;
        target = _target;
    }

    function createClone() external {
        bytes20 targetBytes = bytes20(target);
        address instance;

        // solium-disable-next-line security/no-inline-assembly
        assembly {
            let clone := mload(0x40)
            mstore(
                clone,
                0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            mstore(add(clone, 0x14), targetBytes)
            mstore(
                add(clone, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            instance := create(0, clone, 0x37)
        }

        instances.push(instance);
        addressToIndex[instance] = instances.length - 1;
        emit NewGTCR(instance);
    }

    function changeTarget(address _target) external onlyGovernor {
        target = _target;
    }

    function isClone(address _target, address _query)
        internal
        view
        returns (bool result)
    {
        bytes20 targetBytes = bytes20(_target);

        // solium-disable-next-line security/no-inline-assembly
        assembly {
            let clone := mload(0x40)
            mstore(
                clone,
                0x363d3d373d3d3d363d7300000000000000000000000000000000000000000000
            )
            mstore(add(clone, 0xa), targetBytes)
            mstore(
                add(clone, 0x1e),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )

            let other := add(clone, 0x40)
            extcodecopy(_query, other, 0, 0x2d)
            result := and(
                eq(mload(clone), mload(other)),
                eq(mload(add(clone, 0xd)), mload(add(other, 0xd)))
            )
        }
    }

    /**
     * @return The number of deployed tcrs using this factory.
     */
    function count() external view returns (uint) {
        return instances.length;
    }
}