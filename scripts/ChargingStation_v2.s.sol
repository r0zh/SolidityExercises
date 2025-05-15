// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

import "forge-std/Script.sol";
import "../src/ChargingStation.sol";

/**
 * @title DeployChargingStation_v2
 * @notice Deploys the ChargingStation_v2 contract
 * @dev Run with: forge script scripts/ChargingStation_v2.s.sol:DeployChargingStation_v2 --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
 * @dev Can override defaults: forge script scripts/ChargingStation_v2.s.sol:DeployChargingStation_v2 --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast -s "deployChargers(4, 10000000000000000)"
 */
contract DeployChargingStation_v2 is Script {
    // Default values
    uint8 public constant DEFAULT_NUM_CHARGERS = 8;
    uint256 public constant DEFAULT_COST_PER_MINUTE = 0.01 ether; // 0.01 ETH per minute

    /**
     * @notice Deploy the contract with default parameters
     */
    function run() external {
        // Use the default parameters
        deployChargers(DEFAULT_NUM_CHARGERS, DEFAULT_COST_PER_MINUTE);
    }

    /**
     * @notice Deploy with custom parameters
     * @param numChargers Number of chargers to set up (1-32)
     * @param costPerMinute Cost per minute in wei
     */
    function deployChargers(uint8 numChargers, uint256 costPerMinute) public {
        // Input validation
        require(
            numChargers > 0 && numChargers < 32,
            "Invalid number of chargers"
        );
        require(costPerMinute > 0, "Cost per minute must be greater than zero");

        // Start broadcast
        vm.startBroadcast();

        // Deploy contract
        ChargingStation_v2 chargingStation = new ChargingStation_v2(
            numChargers,
            costPerMinute
        );

        // Log deployment info
        console.log(
            "ChargingStation_v2 deployed at:",
            address(chargingStation)
        );
        console.log("Number of chargers:", numChargers);
        console.log("Cost per minute:", costPerMinute);

        vm.stopBroadcast();
    }
}
