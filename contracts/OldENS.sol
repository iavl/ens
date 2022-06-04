pragma solidity >=0.4.24;

interface OldENS {
    function setSubnodeOwner(
        bytes32 node,
        bytes32 label,
        address owner
    ) external;

    function setResolver(bytes32 node, address resolver) external;

    function setOwner(bytes32 node, address owner) external;

    function setTTL(bytes32 node, uint64 ttl) external;

    function owner(bytes32 node) external view returns (address);

    function resolver(bytes32 node) external view returns (address);

    function ttl(bytes32 node) external view returns (uint64);
}
