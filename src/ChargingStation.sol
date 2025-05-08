// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "forge-std/console.sol";

/**
 * @title ChargingStation_v1
 * @notice Prepaid EV charging station reservations (Version 1).
 */
contract ChargingStation_v1 is Ownable, Pausable {
    // ==============================================================================
    // State Variables
    // ==============================================================================

    uint8 public constant MAX_CHARGERS = 32;
    uint256 public constant MIN_MINUTES = 15;
    uint256 public constant MAX_MINUTES = 240; // 4 hours

    uint8 public numChargers;
    uint256 public costPerMinute;
    Reservation[] public chargerReservations;

    // ==============================================================================
    // Events
    // ==============================================================================

    event ReservationCreated(
        address indexed user, uint8 chargerIndex, uint256 startTime, uint256 endTime, uint256 amountPaid
    );

    event ChargingStarted(address indexed user, uint8 chargerIndex, uint256 timestamp);

    event ChargingEnded(address indexed user, uint8 chargerIndex, uint256 timestamp);

    // ==============================================================================
    // Structs
    // ==============================================================================

    /**
     * @notice Details of a charger reservation.
     * @param user Reserving user.
     * @param startTime Reservation start time.
     * @param endTime Reservation end time.
     * @param active True if charging has been initiated.
     */
    struct Reservation {
        address user;
        uint256 startTime;
        uint256 endTime;
        bool active;
    }

    // ==============================================================================
    // Constructor
    // ==============================================================================

    /**
     * @notice Initializes the charging station.
     * @param _numChargers Number of chargers (0 < _numChargers < MAX_CHARGERS).
     * @param _costPerMinute Cost per minute for charging (> 0).
     */
    constructor(uint8 _numChargers, uint256 _costPerMinute) Ownable(msg.sender) {
        require(_numChargers > 0 && _numChargers < MAX_CHARGERS, "Invalid number of chargers");
        require(_costPerMinute > 0, "Cost per minute must be greater than zero");

        costPerMinute = _costPerMinute;
        numChargers = _numChargers;

        for (uint8 i = 0; i < _numChargers; i++) {
            chargerReservations.push(Reservation({user: address(0), startTime: 0, endTime: 0, active: false}));
        }
    }

    // ==============================================================================
    // External Functions
    // ==============================================================================

    /**
     * @notice Owner can withdraw contract ETH balance.
     */
    function withdraw() external onlyOwner {
        (bool success,) = msg.sender.call{value: address(this).balance}("");
        require(success, "ETH transfer failed");
    }

    /**
     * @notice Owner can pause the contract.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Owner can unpause the contract.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Reserves a charger by paying upfront.
     * @param min Duration of reservation in minutes (MIN_MINUTES <= min <= MAX_MINUTES).
     */
    function reserveCharger(uint256 min) external payable whenNotPaused {
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

        if (msg.value > cost) {
            (bool success,) = msg.sender.call{value: msg.value - cost}("");
            require(success, "Refund failed");
        }
    }

    /**
     * @notice User starts charging on their reserved charger.
     * @param chargerIndex Index of the charger.
     */
    function startCharging(uint8 chargerIndex) external whenNotPaused {
        require(chargerIndex < numChargers, "Invalid charger index");

        Reservation storage reservation = chargerReservations[chargerIndex];
        require(reservation.user == msg.sender, "Not your reservation");
        require(block.timestamp < reservation.endTime, "Reservation expired");
        require(!reservation.active, "Charging already started");

        reservation.active = true;
        emit ChargingStarted(msg.sender, chargerIndex, block.timestamp);
    }

    /**
     * @notice User manually stops charging before reservation expiry.
     * @param chargerIndex Index of the charger.
     */
    function stopCharging(uint8 chargerIndex) external whenNotPaused {
        require(chargerIndex < numChargers, "Invalid charger index");

        Reservation storage reservation = chargerReservations[chargerIndex];
        require(reservation.user == msg.sender, "Not your reservation");
        require(reservation.active, "Charging not started");

        reservation.active = false;
        emit ChargingEnded(msg.sender, chargerIndex, block.timestamp);
        resetReservation(chargerIndex);
    }

    // ==============================================================================
    // Public Functions
    // ==============================================================================

    /**
     * @notice Checks and releases an expired reservation.
     * @param chargerIndex Index of the charger to check.
     * @return True if the charger is or becomes available.
     */
    function checkAndReleaseExpiredReservation(uint8 chargerIndex) public whenNotPaused returns (bool) {
        require(chargerIndex < numChargers, "Invalid charger index");
        Reservation storage reservation = chargerReservations[chargerIndex];

        if (reservation.user != address(0) && block.timestamp > reservation.endTime) {
            if (reservation.active) {
                emit ChargingEnded(reservation.user, chargerIndex, reservation.endTime);
            }
            resetReservation(chargerIndex);
            return true;
        }
        return isChargerAvailable(chargerIndex);
    }

    /**
     * @notice Finds the first available charger.
     * @dev Calls {checkAndReleaseExpiredReservation} for each charger.
     * This function should be on the frontend to avoid gas issues.
     * @return Index of an available charger.
     */
    function findAvailableCharger() public returns (uint8) {
        for (uint8 i = 0; i < numChargers; i++) {
            if (checkAndReleaseExpiredReservation(i)) {
                return i;
            }
        }
        revert("No available chargers");
    }

    // ==============================================================================
    // Internal Functions
    // ==============================================================================

    /**
     * @notice Resets a charger's reservation to its default empty state.
     * @param chargerIndex Index of the charger to reset.
     */
    function resetReservation(uint8 chargerIndex) internal {
        chargerReservations[chargerIndex] = Reservation({user: address(0), startTime: 0, endTime: 0, active: false});
    }

    // ==============================================================================
    // View/Pure Functions
    // ==============================================================================

    /**
     * @notice Checks if a specific charger is available.
     * @param chargerIndex Index of the charger.
     * @return True if available, false otherwise.
     */
    function isChargerAvailable(uint8 chargerIndex) public view returns (bool) {
        require(chargerIndex < numChargers, "Invalid charger index");
        Reservation storage reservation = chargerReservations[chargerIndex];
        return (reservation.user == address(0)) || (block.timestamp > reservation.endTime);
    }

    /**
     * @notice Gets remaining time for an active reservation.
     * @param chargerIndex Index of the charger.
     * @return Remaining time in seconds, or 0 if no active/valid reservation.
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
 * @notice Pay-per-use EV charging station (Version 2).
 */
contract ChargingStation_v2 is Ownable, Pausable {
    // ==============================================================================
    // State Variables
    // ==============================================================================

    uint8 public constant MAX_CHARGERS = 32;
    uint8 public numChargers;
    uint256 public costPerMinute;
    ChargingSession[] public chargingSessions;

    // ==============================================================================
    // Events
    // ==============================================================================

    /**
     * @notice Emitted when a user starts charging.
     * @param user Address of the user.
     * @param timestamp Start time (Unix timestamp).
     * @param chargerIndex Index of the charger.
     */
    event ChargingStarted(address indexed user, uint256 timestamp, uint8 chargerIndex);

    /**
     * @notice Emitted when a user stops charging and payment is processed.
     * @param user Address of the user.
     * @param cost Total cost for the session.
     */
    event CostCharged(address indexed user, uint256 cost);

    // ==============================================================================
    // Structs
    // ==============================================================================

    /**
     * @notice Details of an active charging session.
     * @param user User currently charging.
     * @param startTime Session start time.
     */
    struct ChargingSession {
        address user;
        uint256 startTime;
    }

    // ==============================================================================
    // Constructor
    // ==============================================================================

    /**
     * @notice Initializes the charging station.
     * @param _numChargers Number of chargers (0 < _numChargers < MAX_CHARGERS).
     * @param _costPerMinute Cost per minute for charging (> 0).
     */
    constructor(uint8 _numChargers, uint256 _costPerMinute) Ownable(msg.sender) {
        require(_numChargers > 0 && _numChargers < MAX_CHARGERS, "Invalid number of chargers");
        require(_costPerMinute > 0, "Cost per minute must be greater than zero");

        costPerMinute = _costPerMinute;
        numChargers = _numChargers;

        for (uint8 i = 0; i < _numChargers; i++) {
            chargingSessions.push(ChargingSession({user: address(0), startTime: 0}));
        }
    }

    // ==============================================================================
    // External Functions
    // ==============================================================================

    /**
     * @notice Owner can withdraw contract ETH balance.
     */
    function withdraw() external onlyOwner {
        (bool success,) = msg.sender.call{value: address(this).balance}("");
        require(success, "ETH transfer failed");
    }

    /**
     * @notice Owner can pause the contract.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Owner can unpause the contract.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Starts a charging session for `msg.sender` on an available charger.
     * @dev Emits {ChargingStarted}.
     */
    function startCharging() external whenNotPaused {
        require(numChargers > 0, "No chargers available in station");
        uint8 chargerIndex = findAvailableCharger();

        chargingSessions[chargerIndex] = ChargingSession({user: msg.sender, startTime: block.timestamp});
        emit ChargingStarted(msg.sender, block.timestamp, chargerIndex);
    }

    /**
     * @notice Stops an ongoing charging session for `msg.sender`.
     * @param chargerIndex Index of the charger.
     * @dev Calculates cost; user must send sufficient ETH. Excess is refunded.
     */
    function stopCharging(uint8 chargerIndex) external payable whenNotPaused {
        require(chargerIndex < numChargers, "Invalid charger index");

        ChargingSession storage session = chargingSessions[chargerIndex];
        require(session.startTime > 0, "Charger not in use");
        require(session.user == msg.sender, "Not your charging session");

        uint256 timeSpentSeconds = block.timestamp - session.startTime;
        uint256 minutesCharged = (timeSpentSeconds + 59) / 60;
        if (timeSpentSeconds == 0) {
            minutesCharged = 1; // Charge for at least one minute
        }
        uint256 cost = minutesCharged * costPerMinute;

        require(msg.value >= cost, "Insufficient payment");

        chargingSessions[chargerIndex] = ChargingSession({user: address(0), startTime: 0});
        emit CostCharged(msg.sender, cost);

        if (msg.value > cost) {
            (bool success,) = msg.sender.call{value: msg.value - cost}("");
            require(success, "Refund failed");
        }
    }

    // ==============================================================================
    // View/Pure Functions
    // ==============================================================================

    /**
     * @notice Finds the index of the first available charger.
     * @return Index of an available charger.
     * @dev This function should be on the frontend to avoid gas issues.
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
