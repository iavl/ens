pragma solidity ^0.5.0;

import "./Ownable.sol";
import "./PriceOracle.sol";
import "./SafeMath.sol";
import "./StringUtils.sol";

interface DSValue {
    function read() external view returns (bytes32);
}

// https://etherscan.io/address/0xb9d374d0fe3d8341155663fae31b7beae0ae233a

// StablePriceOracle sets a price in USD, based on an oracle.
contract StablePriceOracle is Ownable, PriceOracle {
    using SafeMath for *;
    using StringUtils for *;

    // Oracle address
    DSValue usdOracle;

    // Rent in attodollars (1e-18) per second
    uint256[] public rentPrices;

    event OracleChanged(address oracle);
    event RentPriceChanged(uint256[] prices);

    constructor(DSValue _usdOracle, uint256[] memory _rentPrices) public {
        setOracle(_usdOracle);
        setPrices(_rentPrices);
    }

    /**
     * @dev Sets the price oracle address
     * @param _usdOracle The address of the price oracle to use.
     */
    function setOracle(DSValue _usdOracle) public onlyOwner {
        usdOracle = _usdOracle;
        emit OracleChanged(address(_usdOracle));
    }

    /**
     * @dev Sets rent prices.
     * @param _rentPrices The price array. Each element corresponds to a specific
     *                    name length; names longer than the length of the array
     *                    default to the price of the last element.
     */
    function setPrices(uint256[] memory _rentPrices) public onlyOwner {
        rentPrices = _rentPrices;
        emit RentPriceChanged(_rentPrices);
    }

    /**
     * @dev Returns the price to register or renew a name.
     * @param name The name being registered or renewed.
     * @param duration How long the name is being registered or extended for, in seconds.
     * @return The price of this renewal or registration, in wei.
     */
    function price(
        string calldata name,
        uint256, /*expires*/
        uint256 duration
    ) external view returns (uint256) {
        uint256 len = name.strlen();
        if (len > rentPrices.length) {
            len = rentPrices.length;
        }
        require(len > 0);
        uint256 priceUSD = rentPrices[len - 1].mul(duration);

        // Price of one ether in attodollars
        uint256 ethPrice = uint256(usdOracle.read());

        // priceUSD and ethPrice are both fixed-point values with 18dp, so we
        // multiply the numerator by 1e18 before dividing.
        return priceUSD.mul(1e18).div(ethPrice);
    }
}
