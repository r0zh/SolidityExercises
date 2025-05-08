// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "forge-std/console.sol";

/**
 * @title ChargingStation_v1
 * @notice This contract implements a prepaid reservation system for EV charging stations.
 * Users pay upfront for a fixed charging time period, after which the charger becomes available again.
 */
contract ChargingStation_v1 is Ownable {
    uint8 public constant MAX_CHARGERS = 32;
    uint256 public constant MIN_MINUTES = 15; // Minimum reservation time (15 minutes)
    uint256 public constant MAX_MINUTES = 240; // Maximum reservation time (4 hours)

    // Events
    event ReservationCreated(
        address indexed user, uint8 chargerIndex, uint256 startTime, uint256 endTime, uint256 amountPaid
    );
    event ChargingStarted(address indexed user, uint8 chargerIndex, uint256 timestamp);
    event ChargingEnded(address indexed user, uint8 chargerIndex, uint256 timestamp);

    struct Reservation {
        address user; // User who made the reservation
        uint256 startTime; // Start time of the reservation
        uint256 endTime; // End time of the reservation
        bool active; // Whether charging has been initiated
    }

    uint8 public numChargers;
    uint256 public costPerMinute;

    // Array that tracks reservations for each charger
    Reservation[] public chargerReservations;

    constructor(uint8 _numChargers, uint256 _costPerMinute) Ownable(msg.sender) {
        require(_numChargers > 0 && _numChargers < MAX_CHARGERS, "Invalid number of chargers");
        require(_costPerMinute > 0, "Cost per minute must be greater than zero");
        costPerMinute = _costPerMinute;
        numChargers = _numChargers;

        // Initialize reservations for all chargers. Altough this will cost gas, it is a one-time cost because
        // pre-allocating the entire array at deployment is more gas-efficient than growing it dynamically
        for (uint8 i = 0; i < _numChargers; i++) {
            chargerReservations.push(Reservation({user: address(0), startTime: 0, endTime: 0, active: false}));
        }
    }

    /**
     * @notice Allows admin to withdraw contract funds
     */
    function withdraw() external onlyOwner {
        (bool success,) = msg.sender.call{value: address(this).balance}("");
        require(success, "ETH transfer failed");
    }

    /**
     * @notice Reserves a charger for a specified time period and pays upfront
     * @param min The number of minutes to reserve the charger
     */
    function reserveCharger(uint256 min) external payable {
        require(min >= MIN_MINUTES, "Reservation time below minimum");
        require(min <= MAX_MINUTES, "Reservation time exceeds maximum");

        uint8 chargerIndex = findAvailableCharger();
        uint256 cost = min * costPerMinute;

        require(msg.value >= cost, "Insufficient payment for reservation");

        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + (min * 60);

        chargerReservations[chargerIndex] =
            Reservation({user: msg.sender, startTime: startTime, endTime: endTime, active: false});

        emit ReservationCreated(msg.sender, chargerIndex, startTime, endTime, cost);

        // Refund any excess payment
        if (msg.value > cost) {
            (bool success,) = msg.sender.call{value: msg.value - cost}("");
            require(success, "Refund failed");
        }
    }

    /**
     * @notice Start charging with an existing reservation
     * @param chargerIndex The index of the charger to use
     */
    function startCharging(uint8 chargerIndex) external {
        require(chargerIndex < numChargers, "Invalid charger index");

        Reservation storage reservation = chargerReservations[chargerIndex];
        require(reservation.user == msg.sender, "Not your reservation");
        require(block.timestamp < reservation.endTime, "Reservation expired");
        require(!reservation.active, "Charging already started");

        reservation.active = true;
        emit ChargingStarted(msg.sender, chargerIndex, block.timestamp);
    }

    /**
     * @notice Manually end charging before reservation expires (optional)
     * @param chargerIndex The index of the charger to stop
     */
    function stopCharging(uint8 chargerIndex) external {
        require(chargerIndex < numChargers, "Invalid charger index");

        Reservation storage reservation = chargerReservations[chargerIndex];
        require(reservation.user == msg.sender, "Not your reservation");
        require(reservation.active, "Charging not started");

        // Mark charger as available
        reservation.active = false;
        reservation.endTime = block.timestamp;

        emit ChargingEnded(msg.sender, chargerIndex, block.timestamp);

        // Reset reservation to make charger available
        resetReservation(chargerIndex);
    }

    /**
     * @notice Checks if a charger's reservation has expired and makes it available if needed
     * @param chargerIndex The charger to check
     * @return True if charger is available after check
     */
    function checkAndReleaseExpiredReservation(uint8 chargerIndex) public returns (bool) {
        require(chargerIndex < numChargers, "Invalid charger index");

        Reservation storage reservation = chargerReservations[chargerIndex];

        if (reservation.user != address(0) && block.timestamp > reservation.endTime) {
            if (reservation.active) {
                emit ChargingEnded(reservation.user, chargerIndex, block.timestamp);
            }

            resetReservation(chargerIndex);
            return true;
        }

        return isChargerAvailable(chargerIndex);
    }

    /**
     * @notice Finds an available charger
     * @return The index of the first available charger
     */
    function findAvailableCharger() public returns (uint8) {
        for (uint8 i = 0; i < numChargers; i++) {
            // First check if any expired reservations need to be released
            if (checkAndReleaseExpiredReservation(i)) {
                return i;
            }
        }
        revert("No available chargers");
    }

    /**
     * @notice Checks if a charger is available without changing state
     * @param chargerIndex The charger to check
     * @return True if the charger is available
     */
    function isChargerAvailable(uint8 chargerIndex) public view returns (bool) {
        require(chargerIndex < numChargers, "Invalid charger index");

        Reservation storage reservation = chargerReservations[chargerIndex];

        // Charger is available if there's no reservation or if existing reservation has expired
        return (reservation.user == address(0)) || (block.timestamp > reservation.endTime);
    }

    /**
     * @notice Reset a charger's reservation
     * @param chargerIndex The charger to reset
     */
    function resetReservation(uint8 chargerIndex) internal {
        chargerReservations[chargerIndex] = Reservation({user: address(0), startTime: 0, endTime: 0, active: false});
    }

    /**
     * @notice Returns time remaining for a reservation in seconds
     * @param chargerIndex The charger to check
     * @return The number of seconds remaining, or 0 if expired or not reserved
     */
    function getReservationTimeRemaining(uint8 chargerIndex) external view returns (uint256) {
        require(chargerIndex < numChargers, "Invalid charger index");

        Reservation storage reservation = chargerReservations[chargerIndex];

        if (reservation.user == address(0) || block.timestamp >= reservation.endTime) {
            return 0;
        }

        return reservation.endTime - block.timestamp;
    }
}

/**
 * @title ChargingStation_v2
 * @notice This contract allows users to charge their electric vehicles and pay for the time spent charging.
 * The cost is calculated based on the time spent charging and the cost per minute.
 */
contract ChargingStation_v2 is Ownable {
    uint8 public constant MAX_CHARGERS = 32;

    // Events
    event ChargingStarted(address indexed user, uint256 timestamp, uint8 chargerIndex);
    event CostCharged(address indexed user, uint256 cost);

    uint8 public numChargers;
    uint256 public costPerMinute;

    struct ChargingSession {
        address user;
        uint256 startTime;
    }

    ChargingSession[] public chargingSessions;

    constructor(uint8 _numChargers, uint256 _costPerMinute) Ownable(msg.sender) {
        require(_numChargers > 0 && _numChargers < MAX_CHARGERS, "Invalid number of chargers");
        require(_costPerMinute > 0, "Cost per minute must be greater than zero");
        costPerMinute = _costPerMinute;
        numChargers = _numChargers;

        // Initialize the array with empty sessions
        for (uint8 i = 0; i < _numChargers; i++) {
            chargingSessions.push(ChargingSession({user: address(0), startTime: 0}));
        }
    }

    // Admin functions

    /**
     * @notice Withdraws the balance of the contract to the owner's address.
     */
    function withdraw() external onlyOwner {
        (bool success,) = msg.sender.call{value: address(this).balance}("");
        require(success, "ETH transfer failed");
    }

    /**
     * @notice Starts charging for the user.
     * @dev This function uses findAvailableCharger to find an available charger and starts the charging process if one is available.
     * In a real-world scenario, there are many ways to approach this. This function assumes that the user will ask first for a charger and then start charging.
     * Another option would be to pass the chargers as an argument to the function, since, in the real world, the user will be able to physically see which
     * chargers are available.
     */
    function startCharging() external {
        require(numChargers > 0, "No chargers available");
        uint8 chargerIndex = findAvailableCharger();
        require(chargerIndex < numChargers, "No available chargers");
        // Store both the user and the start time
        chargingSessions[chargerIndex] = ChargingSession({user: msg.sender, startTime: block.timestamp});
        emit ChargingStarted(msg.sender, block.timestamp, chargerIndex);
    }

    /**
     * @notice Stops charging for the user.
     * @dev This function calculates the cost of charging based on the time spent and the cost per minute.
     * It also resets the charger start time to 0, so the charger can be used again.
     */
    function stopCharging(uint8 chargerIndex) external payable {
        require(chargerIndex < numChargers, "Invalid charger index");

        ChargingSession storage session = chargingSessions[chargerIndex];
        require(session.startTime > 0, "Charger not in use");
        require(session.user == msg.sender, "Not your charging session");

        uint256 timeSpent = block.timestamp - session.startTime;
        // Calculation to avoid truncation issues
        uint256 min = (timeSpent + 59) / 60; // Round up to next minute
        uint256 cost = min * costPerMinute;

        require(msg.value >= cost, "Insufficient payment");

        chargingSessions[chargerIndex] = ChargingSession({user: address(0), startTime: 0});

        emit CostCharged(msg.sender, cost);

        // Refund excess payment if any
        if (msg.value > cost) {
            (bool success,) = msg.sender.call{value: msg.value - cost}("");
            require(success, "Refund failed");
        }
    }

    // FUNCTIONS THAT SHOULD BE ON THE FRONTEND

    /**
     * @notice Finds the first available charger.
     * @return The index of the first available charger.
     */
    function findAvailableCharger() internal view returns (uint8) {
        for (uint8 i = 0; i < numChargers; i++) {
            if (chargingSessions[i].startTime == 0) {
                return i;
            }
        }
        revert("No available chargers");
    }
}
