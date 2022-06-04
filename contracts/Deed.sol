pragma solidity >=0.4.24;

interface Deed {
    function setOwner(address payable newOwner) external;

    function setRegistrar(address newRegistrar) external;

    function setBalance(uint256 newValue, bool throwOnFailure) external;

    function closeDeed(uint256 refundRatio) external;

    function destroyDeed() external;

    function owner() external view returns (address);

    function previousOwner() external view returns (address);

    function value() external view returns (uint256);

    function creationDate() external view returns (uint256);
}
