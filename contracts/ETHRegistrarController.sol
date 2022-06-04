pragma solidity ^0.5.0;

import "./PriceOracle.sol";
import "./ENS.sol";
import "./Ownable.sol";
import "./BaseRegistrar.sol";
import "./StringUtils.sol";
import "./Resolver.sol";

// https://etherscan.io/address/0x283af0b28c62c092c9727f1ee09c02ca627eb7f5

/*
commit:
https://etherscan.io/tx/0x27d2ec02d7ff0930a01bc1a19e39245468e028f47903364367c7adb188fa70f3

registerWithConfig:
https://etherscan.io/tx/0x7e336ce48fab31a77986d7278c0ce4395b40073a3ddea9b38da59dfd1ec27a1f


BaseRegistrarImplementation:
https://etherscan.io/address/0x57f1887a8bf19b14fc0df6fd9b2acc9af147ea85


-----Decoded View---------------
Arg [0] : _base (address): 0x57f1887a8bf19b14fc0df6fd9b2acc9af147ea85
Arg [1] : _prices (address): 0xb9d374d0fe3d8341155663fae31b7beae0ae233a
Arg [2] : _minCommitmentAge (uint256): 60
Arg [3] : _maxCommitmentAge (uint256): 86400

*/

/**
 * @dev A registrar controller for registering and renewing names at fixed cost.
 */
contract ETHRegistrarController is Ownable {
    using StringUtils for *;

    uint256 public constant MIN_REGISTRATION_DURATION = 28 days;

    bytes4 private constant INTERFACE_META_ID =
        bytes4(keccak256("supportsInterface(bytes4)"));
    bytes4 private constant COMMITMENT_CONTROLLER_ID =
        bytes4(
            keccak256("rentPrice(string,uint256)") ^
                keccak256("available(string)") ^
                keccak256("makeCommitment(string,address,bytes32)") ^
                keccak256("commit(bytes32)") ^
                keccak256("register(string,address,uint256,bytes32)") ^
                keccak256("renew(string,uint256)")
        );

    bytes4 private constant COMMITMENT_WITH_CONFIG_CONTROLLER_ID =
        bytes4(
            keccak256(
                "registerWithConfig(string,address,uint256,bytes32,address,address)"
            ) ^
                keccak256(
                    "makeCommitmentWithConfig(string,address,bytes32,address,address)"
                )
        );

    BaseRegistrar base;
    PriceOracle prices;
    uint256 public minCommitmentAge;
    uint256 public maxCommitmentAge;

    mapping(bytes32 => uint256) public commitments;

    event NameRegistered(
        string name,
        bytes32 indexed label,
        address indexed owner,
        uint256 cost,
        uint256 expires
    );
    event NameRenewed(
        string name,
        bytes32 indexed label,
        uint256 cost,
        uint256 expires
    );
    event NewPriceOracle(address indexed oracle);

    constructor(
        BaseRegistrar _base,
        PriceOracle _prices,
        uint256 _minCommitmentAge,
        uint256 _maxCommitmentAge
    ) public {
        require(_maxCommitmentAge > _minCommitmentAge);

        base = _base;
        prices = _prices;
        minCommitmentAge = _minCommitmentAge;
        maxCommitmentAge = _maxCommitmentAge;
    }

    function rentPrice(string memory name, uint256 duration)
        public
        view
        returns (uint256)
    {
        bytes32 hash = keccak256(bytes(name));
        return prices.price(name, base.nameExpires(uint256(hash)), duration);
    }

    function valid(string memory name) public pure returns (bool) {
        return name.strlen() >= 3;
    }

    function available(string memory name) public view returns (bool) {
        bytes32 label = keccak256(bytes(name));
        return valid(name) && base.available(uint256(label));
    }

    function makeCommitment(
        string memory name,
        address owner,
        bytes32 secret
    ) public pure returns (bytes32) {
        return
            makeCommitmentWithConfig(
                name,
                owner,
                secret,
                address(0),
                address(0)
            );
    }

    function makeCommitmentWithConfig(
        string memory name,
        address owner,
        bytes32 secret,
        address resolver,
        address addr
    ) public pure returns (bytes32) {
        bytes32 label = keccak256(bytes(name));
        if (resolver == address(0) && addr == address(0)) {
            return keccak256(abi.encodePacked(label, owner, secret));
        }
        require(resolver != address(0));
        return
            keccak256(abi.encodePacked(label, owner, resolver, addr, secret));
    }

    function commit(bytes32 commitment) public {
        require(commitments[commitment] + maxCommitmentAge < now);
        commitments[commitment] = now;
    }

    function register(
        string calldata name,
        address owner,
        uint256 duration,
        bytes32 secret
    ) external payable {
        registerWithConfig(
            name,
            owner,
            duration,
            secret,
            address(0),
            address(0)
        );
    }

    function registerWithConfig(
        string memory name,
        address owner,
        uint256 duration,
        bytes32 secret,
        address resolver,
        address addr
    ) public payable {
        bytes32 commitment = makeCommitmentWithConfig(
            name,
            owner,
            secret,
            resolver,
            addr
        );
        uint256 cost = _consumeCommitment(name, duration, commitment);

        bytes32 label = keccak256(bytes(name));
        uint256 tokenId = uint256(label);

        uint256 expires;
        if (resolver != address(0)) {
            // Set this contract as the (temporary) owner, giving it
            // permission to set up the resolver.
            expires = base.register(tokenId, address(this), duration);

            // The nodehash of this label
            bytes32 nodehash = keccak256(
                abi.encodePacked(base.baseNode(), label)
            );

            // Set the resolver
            base.ens().setResolver(nodehash, resolver);

            // Configure the resolver
            if (addr != address(0)) {
                Resolver(resolver).setAddr(nodehash, addr);
            }

            // Now transfer full ownership to the expeceted owner
            base.reclaim(tokenId, owner);
            base.transferFrom(address(this), owner, tokenId);
        } else {
            require(addr == address(0));
            expires = base.register(tokenId, owner, duration);
        }

        emit NameRegistered(name, label, owner, cost, expires);

        // Refund any extra payment
        if (msg.value > cost) {
            msg.sender.transfer(msg.value - cost);
        }
    }

    function renew(string calldata name, uint256 duration) external payable {
        uint256 cost = rentPrice(name, duration);
        require(msg.value >= cost);

        bytes32 label = keccak256(bytes(name));
        uint256 expires = base.renew(uint256(label), duration);

        if (msg.value > cost) {
            msg.sender.transfer(msg.value - cost);
        }

        emit NameRenewed(name, label, cost, expires);
    }

    function setPriceOracle(PriceOracle _prices) public onlyOwner {
        prices = _prices;
        emit NewPriceOracle(address(prices));
    }

    function setCommitmentAges(
        uint256 _minCommitmentAge,
        uint256 _maxCommitmentAge
    ) public onlyOwner {
        minCommitmentAge = _minCommitmentAge;
        maxCommitmentAge = _maxCommitmentAge;
    }

    function withdraw() public onlyOwner {
        msg.sender.transfer(address(this).balance);
    }

    function supportsInterface(bytes4 interfaceID)
        external
        pure
        returns (bool)
    {
        return
            interfaceID == INTERFACE_META_ID ||
            interfaceID == COMMITMENT_CONTROLLER_ID ||
            interfaceID == COMMITMENT_WITH_CONFIG_CONTROLLER_ID;
    }

    function _consumeCommitment(
        string memory name,
        uint256 duration,
        bytes32 commitment
    ) internal returns (uint256) {
        // Require a valid commitment
        require(commitments[commitment] + minCommitmentAge <= now);

        // If the commitment is too old, or the name is registered, stop
        require(commitments[commitment] + maxCommitmentAge > now);
        require(available(name));

        delete (commitments[commitment]);

        uint256 cost = rentPrice(name, duration);
        require(duration >= MIN_REGISTRATION_DURATION);
        require(msg.value >= cost);

        return cost;
    }
}
