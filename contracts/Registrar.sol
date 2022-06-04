pragma solidity >=0.4.24;

import "./Deed.sol";

interface Registrar {
    enum Mode {
        Open,
        Auction,
        Owned,
        Forbidden,
        Reveal,
        NotYetAvailable
    }

    event AuctionStarted(bytes32 indexed hash, uint256 registrationDate);
    event NewBid(bytes32 indexed hash, address indexed bidder, uint256 deposit);
    event BidRevealed(
        bytes32 indexed hash,
        address indexed owner,
        uint256 value,
        uint8 status
    );
    event HashRegistered(
        bytes32 indexed hash,
        address indexed owner,
        uint256 value,
        uint256 registrationDate
    );
    event HashReleased(bytes32 indexed hash, uint256 value);
    event HashInvalidated(
        bytes32 indexed hash,
        string indexed name,
        uint256 value,
        uint256 registrationDate
    );

    function state(bytes32 _hash) external view returns (Mode);

    function startAuction(bytes32 _hash) external;

    function startAuctions(bytes32[] calldata _hashes) external;

    function newBid(bytes32 sealedBid) external payable;

    function startAuctionsAndBid(bytes32[] calldata hashes, bytes32 sealedBid)
        external
        payable;

    function unsealBid(
        bytes32 _hash,
        uint256 _value,
        bytes32 _salt
    ) external;

    function cancelBid(address bidder, bytes32 seal) external;

    function finalizeAuction(bytes32 _hash) external;

    function transfer(bytes32 _hash, address payable newOwner) external;

    function releaseDeed(bytes32 _hash) external;

    function invalidateName(string calldata unhashedName) external;

    function eraseNode(bytes32[] calldata labels) external;

    function transferRegistrars(bytes32 _hash) external;

    function acceptRegistrarTransfer(
        bytes32 hash,
        Deed deed,
        uint256 registrationDate
    ) external;

    function entries(bytes32 _hash)
        external
        view
        returns (
            Mode,
            address,
            uint256,
            uint256,
            uint256
        );
}
