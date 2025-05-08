// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

import "forge-std/Test.sol";
import "../src/ChargingStation.sol";

contract ChargingStation_v2_Test is Test {
    ChargingStation_v2 public chargingStation;
    address alice = address(0x1);
    address bob = address(0x2);
    address charlie = address(0x3);

    // Events
    event ChargingStarted(address indexed user, uint256 timestamp, uint8 chargerIndex);
    event CostCharged(address indexed user, uint256 cost);

    function setUp() public {
        vm.prank(alice);
        // Setup with valid parameters
        chargingStation = new ChargingStation_v2(16, 1000);
        vm.stopPrank();

        // Fund test accounts
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(charlie, 10 ether);
    }

    // CONSTRUCTOR TESTS
    // Test valid constructor parameters
    function test_ConstructorSetsCorrectValues() public {
        uint8 testChargers = 20;
        uint256 testCostPerMinute = 2000;

        vm.prank(alice);
        ChargingStation_v2 newStation = new ChargingStation_v2(testChargers, testCostPerMinute);
        vm.stopPrank();

        assertEq(newStation.numChargers(), testChargers);
        assertEq(newStation.costPerMinute(), testCostPerMinute);
        assertEq(newStation.owner(), alice);
    }

    // Test that constructor reverts when number of chargers exceeds maximum
    function test_RevertWhen_NumChargersExceedsMax() public {
        vm.expectRevert("Invalid number of chargers");
        new ChargingStation_v2(32, 1000);
    }

    // Test that constructor reverts when chargers is zero
    function test_RevertWhen_NumChargersIsZero() public {
        vm.expectRevert("Invalid number of chargers");
        new ChargingStation_v2(0, 1000);
    }

    // Test that constructor reverts when cost per minute is zero
    function test_RevertWhen_CostPerMinuteIsZero() public {
        vm.expectRevert("Cost per minute must be greater than zero");
        new ChargingStation_v2(5, 0);
    }
    // -------------------------------------------------------------------------------

    // FUNCTIONALITY TESTS
    // Test that only admin can withdraw funds
    function test_OnlyAdminCanWithdraw() public {
        // Fund the contract
        vm.deal(address(chargingStation), 1 ether);

        // Attempt to withdraw from non-admin address
        vm.prank(bob);
        vm.expectRevert();
        chargingStation.withdraw();

        // Attempt to withdraw from admin address
        vm.prank(alice);
        uint256 initialBalance = address(alice).balance;
        chargingStation.withdraw();
        uint256 finalBalance = address(alice).balance;

        assertEq(finalBalance, initialBalance + 1 ether);
        assertEq(address(chargingStation).balance, 0);
    }

    // Test starting a charging session
    function test_StartCharging() public {
        // Verify initial state - all chargers should be available (no user)
        for (uint8 i = 0; i < chargingStation.numChargers(); i++) {
            (address user, uint256 startTime) = chargingStation.chargingSessions(i);
            assertEq(user, address(0));
            assertEq(startTime, 0);
        }

        // Start charging as Bob
        vm.prank(bob);
        chargingStation.startCharging();

        // Check that at least one charger is now in use (non-zero timestamp)
        bool foundActiveCharger = false;
        for (uint8 i = 0; i < chargingStation.numChargers(); i++) {
            (address user, uint256 startTime) = chargingStation.chargingSessions(i);
            if (user == bob && startTime > 0) {
                foundActiveCharger = true;
                break;
            }
        }
        assertTrue(foundActiveCharger, "No charger was marked as active");
    }

    // Test when all chargers are in use
    function test_RevertWhen_AllChargersInUse() public {
        // Fill all chargers
        for (uint8 i = 0; i < chargingStation.numChargers(); i++) {
            vm.prank(address(uint160(i + 100))); // Use different addresses
            chargingStation.startCharging();
        }

        // Try to start charging when all chargers are in use
        vm.expectRevert("No available chargers");
        vm.prank(bob);
        chargingStation.startCharging();
    }

    // Test stopping charging and payment
    function test_StopCharging() public {
        // Start charging
        vm.prank(bob);
        chargingStation.startCharging();

        // Find which charger was used
        uint8 usedChargerIndex;
        bool found = false;
        for (uint8 i = 0; i < chargingStation.numChargers(); i++) {
            (address _user, uint256 _startTime) = chargingStation.chargingSessions(i);
            if (_user == bob && _startTime > 0) {
                usedChargerIndex = i;
                found = true;
                break;
            }
        }
        assertTrue(found, "No active charger found");

        // Skip ahead 2 minutes
        skip(2 minutes);

        // Calculate expected cost (2 minutes * costPerMinute)
        uint256 expectedCost = 2 * chargingStation.costPerMinute();

        // Verify contract balance before
        uint256 contractBalanceBefore = address(chargingStation).balance;

        // Stop charging and pay
        vm.prank(bob);
        chargingStation.stopCharging{value: expectedCost}(usedChargerIndex);

        // Verify charger is now available
        (address user, uint256 startTime) = chargingStation.chargingSessions(usedChargerIndex);
        assertEq(user, address(0), "Charger user should be reset");
        assertEq(startTime, 0, "Charger start time should be reset");

        // Verify contract received payment
        assertEq(address(chargingStation).balance, contractBalanceBefore + expectedCost);
    }

    // Test the CostCharged event
    function test_StopChargingEvent() public {
        // Start charging
        vm.prank(bob);
        chargingStation.startCharging();

        // Find which charger was used
        uint8 usedChargerIndex = 0;
        for (uint8 i = 0; i < chargingStation.numChargers(); i++) {
            (address user, uint256 startTime) = chargingStation.chargingSessions(i);
            if (user == bob && startTime > 0) {
                usedChargerIndex = i;
                break;
            }
        }

        // Skip ahead 1 minute
        skip(1 minutes);

        // Calculate expected cost
        uint256 expectedCost = chargingStation.costPerMinute();

        // Expect the CostCharged event with bob's address and the correct cost
        vm.expectEmit(true, false, false, true);
        emit CostCharged(bob, expectedCost);

        // Stop charging
        vm.prank(bob);
        chargingStation.stopCharging{value: expectedCost}(usedChargerIndex);
    }

    // Test authentication - only the user who started can stop
    function test_RevertWhen_NotYourSession() public {
        // Start charging as Bob
        vm.prank(bob);
        chargingStation.startCharging();

        // Find which charger was used
        uint8 usedChargerIndex;
        for (uint8 i = 0; i < chargingStation.numChargers(); i++) {
            (address user, uint256 startTime) = chargingStation.chargingSessions(i);
            if (user == bob && startTime > 0) {
                usedChargerIndex = i;
                break;
            }
        }

        // Try to stop charging as Charlie
        vm.prank(charlie);
        vm.expectRevert("Not your charging session");
        chargingStation.stopCharging{value: 1 ether}(usedChargerIndex);
    }

    // Other test functions remain largely unchanged except for accessing chargingSessions
    function test_RevertWhen_InvalidChargerIndex() public {
        vm.prank(bob);
        vm.expectRevert("Invalid charger index");
        chargingStation.stopCharging{value: 1 ether}(100); // Use an invalid index
    }

    function test_RevertWhen_ChargerNotInUse() public {
        vm.prank(bob);
        vm.expectRevert("Charger not in use");
        chargingStation.stopCharging{value: 1 ether}(0); // Charger not in use
    }

    function test_RevertWhen_InsufficientPayment() public {
        // Start charging
        vm.prank(bob);
        chargingStation.startCharging();

        // Find which charger was used
        uint8 usedChargerIndex = 0;
        for (uint8 i = 0; i < chargingStation.numChargers(); i++) {
            (address user, uint256 startTime) = chargingStation.chargingSessions(i);
            if (user == bob && startTime > 0) {
                usedChargerIndex = i;
                break;
            }
        }

        // Skip ahead 2 minutes
        skip(2 minutes);
        uint256 expectedCost = chargingStation.costPerMinute() * 2;

        // Pay less than required
        vm.prank(bob);
        vm.expectRevert("Insufficient payment");
        chargingStation.stopCharging{value: expectedCost - 1}(usedChargerIndex);
    }
}
