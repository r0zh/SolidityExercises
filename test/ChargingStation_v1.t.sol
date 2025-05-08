// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

import "forge-std/Test.sol";
import "../src/ChargingStation.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract ChargingStation_v1_Test is Test {
    ChargingStation_v1 public chargingStation;
    address alice = address(0x1);
    address bob = address(0x2);
    address charlie = address(0x3);

    // Events
    event ReservationCreated(
        address indexed user, uint8 chargerIndex, uint256 startTime, uint256 endTime, uint256 amountPaid
    );
    event ChargingStarted(address indexed user, uint8 chargerIndex, uint256 timestamp);
    event ChargingEnded(address indexed user, uint8 chargerIndex, uint256 timestamp);
    event Paused(address account);
    event Unpaused(address account);

    function setUp() public {
        vm.prank(alice);
        // Setup with valid parameters
        chargingStation = new ChargingStation_v1(16, 1000);
        vm.stopPrank();

        // Fund test accounts
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(charlie, 10 ether);
    }

    // Constructor Tests
    function testConstructorValidParameters() public {
        ChargingStation_v1 testStation = new ChargingStation_v1(8, 500);
        assertEq(testStation.numChargers(), 8);
        assertEq(testStation.costPerMinute(), 500);
    }

    function testConstructorInvalidParameters() public {
        vm.expectRevert("Invalid number of chargers");
        new ChargingStation_v1(0, 1000);

        vm.expectRevert("Invalid number of chargers");
        new ChargingStation_v1(33, 1000); // MAX_CHARGERS is 32

        vm.expectRevert("Cost per minute must be greater than zero");
        new ChargingStation_v1(16, 0);
    }

    // Withdraw Tests
    function testWithdrawByOwner() public {
        // First make a reservation to add funds to contract
        vm.prank(bob);
        chargingStation.reserveCharger{value: 15000 wei}(15); // 15 minutes

        uint256 initialBalance = alice.balance;

        vm.prank(alice);
        chargingStation.withdraw();

        assertEq(alice.balance, initialBalance + 15000);
    }

    function testWithdrawByNonOwner() public {
        vm.prank(bob);
        vm.expectRevert();
        chargingStation.withdraw();
    }

    // ReserveCharger Tests
    function testReserveChargerSuccess() public {
        vm.prank(bob);

        vm.expectEmit(true, true, false, false);
        emit ReservationCreated(bob, 0, block.timestamp, block.timestamp + (15 * 60), 15000);

        chargingStation.reserveCharger{value: 15000 wei}(15); // 15 minutes
    }

    function testReserveChargerWithExcessPayment() public {
        uint256 initialBalance = bob.balance;

        vm.prank(bob);
        chargingStation.reserveCharger{value: 20000 wei}(15); // 15 minutes costs 15000

        // Should be refunded 5000
        assertEq(bob.balance, initialBalance - 15000);
    }

    function testReserveChargerWithInsufficientPayment() public {
        vm.prank(bob);
        vm.expectRevert("Insufficient payment for reservation");
        chargingStation.reserveCharger{value: 14000 wei}(15);
    }

    function testReserveChargerWithInvalidDuration() public {
        vm.prank(bob);
        vm.expectRevert("Reservation time below minimum");
        chargingStation.reserveCharger{value: 10000 wei}(10); // MIN_MINUTES is 15

        vm.prank(bob);
        vm.expectRevert("Reservation time exceeds maximum");
        chargingStation.reserveCharger{value: 300000 wei}(300); // MAX_MINUTES is 240
    }

    function testNoAvailableChargers() public {
        // Reserve all chargers
        for (uint8 i = 0; i < 16; i++) {
            vm.prank(bob);
            chargingStation.reserveCharger{value: 15000 wei}(15);
        }

        vm.prank(charlie);
        vm.expectRevert("No available chargers");
        chargingStation.reserveCharger{value: 15000 wei}(15);
    }

    // StartCharging Tests
    function testStartChargingSuccess() public {
        vm.prank(bob);
        chargingStation.reserveCharger{value: 15000 wei}(15);

        vm.prank(bob);
        vm.expectEmit(true, true, false, false);
        emit ChargingStarted(bob, 0, block.timestamp);
        chargingStation.startCharging(0);
    }

    function testStartChargingInvalidIndex() public {
        vm.prank(bob);
        vm.expectRevert("Invalid charger index");
        chargingStation.startCharging(99);
    }

    function testStartChargingNotYourReservation() public {
        vm.prank(bob);
        chargingStation.reserveCharger{value: 15000 wei}(15);

        vm.prank(charlie);
        vm.expectRevert("Not your reservation");
        chargingStation.startCharging(0);
    }

    function testStartChargingExpiredReservation() public {
        vm.prank(bob);
        chargingStation.reserveCharger{value: 15000 wei}(15);

        // Fast forward past the reservation end time
        skip(16 * 60);

        vm.prank(bob);
        vm.expectRevert("Reservation expired");
        chargingStation.startCharging(0);
    }

    function testStartChargingAlreadyStarted() public {
        vm.prank(bob);
        chargingStation.reserveCharger{value: 15000 wei}(15);

        vm.prank(bob);
        chargingStation.startCharging(0);

        vm.prank(bob);
        vm.expectRevert("Charging already started");
        chargingStation.startCharging(0);
    }

    // StopCharging Tests
    function testStopChargingSuccess() public {
        vm.prank(bob);
        chargingStation.reserveCharger{value: 15000 wei}(15);

        vm.prank(bob);
        chargingStation.startCharging(0);

        vm.prank(bob);
        vm.expectEmit(true, true, false, false);
        emit ChargingEnded(bob, 0, block.timestamp);
        chargingStation.stopCharging(0);

        // Verify charger is available again
        assertTrue(chargingStation.isChargerAvailable(0));
    }

    function testStopChargingInvalidIndex() public {
        vm.prank(bob);
        vm.expectRevert("Invalid charger index");
        chargingStation.stopCharging(99);
    }

    function testStopChargingNotYourReservation() public {
        vm.prank(bob);
        chargingStation.reserveCharger{value: 15000 wei}(15);

        vm.prank(bob);
        chargingStation.startCharging(0);

        vm.prank(charlie);
        vm.expectRevert("Not your reservation");
        chargingStation.stopCharging(0);
    }

    function testStopChargingNotStarted() public {
        vm.prank(bob);
        chargingStation.reserveCharger{value: 15000 wei}(15);

        vm.prank(bob);
        vm.expectRevert("Charging not started");
        chargingStation.stopCharging(0);
    }

    // CheckAndReleaseExpiredReservation Tests
    function testReleaseExpiredReservation() public {
        vm.prank(bob);
        chargingStation.reserveCharger{value: 15000 wei}(15);

        // Fast forward past the reservation end time
        skip(16 * 60);

        assertTrue(chargingStation.checkAndReleaseExpiredReservation(0));
        assertTrue(chargingStation.isChargerAvailable(0));
    }

    function testReleaseActiveExpiredReservation() public {
        vm.prank(bob);
        chargingStation.reserveCharger{value: 15000 wei}(15);

        vm.prank(bob);
        chargingStation.startCharging(0);

        // Fast forward past the reservation end time
        skip(16 * 60);

        vm.expectEmit(true, true, false, false);
        emit ChargingEnded(bob, 0, block.timestamp);
        chargingStation.checkAndReleaseExpiredReservation(0);
    }

    // FindAvailableCharger Tests
    function testFindAvailableCharger() public {
        uint8 chargerIndex = chargingStation.findAvailableCharger();
        assertEq(chargerIndex, 0);

        // Reserve first charger
        vm.prank(bob);
        chargingStation.reserveCharger{value: 15000 wei}(15);

        // Should find next available charger
        chargerIndex = chargingStation.findAvailableCharger();
        assertEq(chargerIndex, 1);
    }

    function testFindExpiredCharger() public {
        // Reserve a charger
        vm.prank(bob);
        chargingStation.reserveCharger{value: 15000 wei}(15);

        // Fast forward past the reservation end time
        skip(16 * 60);

        // Should find the expired charger
        uint8 chargerIndex = chargingStation.findAvailableCharger();
        assertEq(chargerIndex, 0);
    }

    // IsChargerAvailable Tests
    function testIsChargerAvailable() public {
        // Initially all chargers are available
        assertTrue(chargingStation.isChargerAvailable(0));

        // Reserve a charger
        vm.prank(bob);
        chargingStation.reserveCharger{value: 15000 wei}(15);

        // Should no longer be available
        assertFalse(chargingStation.isChargerAvailable(0));

        // Fast forward past the reservation end time
        skip(16 * 60);

        // Should be available again due to expiration
        assertTrue(chargingStation.isChargerAvailable(0));
    }

    function testIsChargerAvailableInvalidIndex() public {
        vm.expectRevert("Invalid charger index");
        chargingStation.isChargerAvailable(99);
    }

    // GetReservationTimeRemaining Tests
    function testGetReservationTimeRemaining() public {
        // No reservation initially
        assertEq(chargingStation.getReservationTimeRemaining(0), 0);

        // Make a reservation for 15 minutes
        vm.prank(bob);
        chargingStation.reserveCharger{value: 15000 wei}(15);

        // Should have close to 15 minutes remaining
        uint256 remaining = chargingStation.getReservationTimeRemaining(0);
        assertGt(remaining, 14 * 60);
        assertLe(remaining, 15 * 60);

        // Fast forward 5 minutes
        skip(5 * 60);

        // Should have close to 10 minutes remaining
        remaining = chargingStation.getReservationTimeRemaining(0);
        assertGt(remaining, 9 * 60);
        assertLe(remaining, 10 * 60);

        // Fast forward past end time
        skip(11 * 60);

        // Should have 0 time remaining
        assertEq(chargingStation.getReservationTimeRemaining(0), 0);
    }

    function testGetReservationTimeRemainingInvalidIndex() public {
        vm.expectRevert("Invalid charger index");
        chargingStation.getReservationTimeRemaining(99);
    }

    // Pause and Unpause Functionality Tests
    function test_ownerCanPauseAndUnpause() public {
        assertFalse(chargingStation.paused(), "Contract should not be paused initially");

        vm.prank(alice);
        vm.expectEmit(true, false, false, false);
        emit Paused(alice);
        chargingStation.pause();
        assertTrue(chargingStation.paused(), "Contract should be paused after owner pauses");

        vm.prank(alice);
        vm.expectEmit(true, false, false, false);
        emit Unpaused(alice);
        chargingStation.unpause();
        assertFalse(chargingStation.paused(), "Contract should be unpaused after owner unpauses");
    }

    function test_nonOwnerCannotPause() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob));
        vm.prank(bob);
        chargingStation.pause();
    }

    function test_nonOwnerCannotUnpause() public {
        vm.prank(alice);
        chargingStation.pause(); // Owner pauses first

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob));
        vm.prank(bob);
        chargingStation.unpause();
    }

    function test_reserveCharger_whenPaused() public {
        vm.prank(alice);
        chargingStation.pause();

        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(bob);
        chargingStation.reserveCharger{value: 15 * 1000}(15);
    }

    function test_startCharging_whenPaused() public {
        // User1 reserves a charger
        vm.prank(bob);
        chargingStation.reserveCharger{value: 15 * 1000}(15);

        vm.prank(alice);
        chargingStation.pause();

        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(bob);
        chargingStation.startCharging(0);
    }

    function test_stopCharging_whenPaused() public {
        // User1 reserves and starts charging
        vm.prank(bob);
        chargingStation.reserveCharger{value: 15 * 1000}(15);
        vm.prank(bob);
        chargingStation.startCharging(0);

        vm.prank(alice);
        chargingStation.pause();

        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(bob);
        chargingStation.stopCharging(0);
    }

    function test_checkAndReleaseExpiredReservation_whenPaused() public {
        // User1 reserves a charger
        vm.prank(bob);
        chargingStation.reserveCharger{value: 15 * 1000}(15);

        vm.prank(alice);
        chargingStation.pause();

        vm.expectRevert(Pausable.EnforcedPause.selector);
        chargingStation.checkAndReleaseExpiredReservation(0);
    }

    function test_functionsWork_afterUnpause() public {
        vm.prank(alice);
        chargingStation.pause();
        assertTrue(chargingStation.paused(), "Contract should be paused");

        vm.prank(alice);
        chargingStation.unpause();
        assertFalse(chargingStation.paused(), "Contract should be unpaused");

        // Test reserveCharger
        vm.prank(bob);
        uint256 initialBalanceUser1 = bob.balance; // Now get the balance AFTER setting it
        uint256 reservationCost = 15 * 1000;
        chargingStation.reserveCharger{value: reservationCost}(15);
        (address rUser,,,) = chargingStation.chargerReservations(0);
        assertEq(rUser, bob, "User1 should have reserved charger 0");
        assertEq(bob.balance, initialBalanceUser1 - reservationCost, "User1 balance incorrect after reservation");

        // Test startCharging
        vm.prank(bob);
        chargingStation.startCharging(0);
        (,,, bool active) = chargingStation.chargerReservations(0);
        assertTrue(active, "Charger 0 should be active");

        // Test stopCharging
        vm.prank(bob);
        chargingStation.stopCharging(0);
        (rUser,,,) = chargingStation.chargerReservations(0);
        assertEq(rUser, address(0), "Charger 0 should be available after stopping");

        // Test checkAndReleaseExpiredReservation (indirectly via findAvailableCharger)
        // Reserve again to make it unavailable
        vm.prank(charlie);
        chargingStation.reserveCharger{value: reservationCost}(15);

        // Warp time to expire reservation
        skip(16 * 60); // Skip 16 minutes

        assertTrue(chargingStation.checkAndReleaseExpiredReservation(0), "Expired reservation should be released");
        (rUser,,,) = chargingStation.chargerReservations(0);
        assertEq(rUser, address(0), "Charger 0 should be available after expiration release");
    }
}
