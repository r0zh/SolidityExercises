// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

import "forge-std/Test.sol";
import "../src/ChargingStation.sol"; // Import the contract under test

// Import specific errors from OpenZeppelin contracts
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract ChargingStation_v2_Test is Test {
    ChargingStation_v2 public chargingStation;
    address alice = address(0x1);
    address bob = address(0x2);
    address charlie = address(0x3);

    // Events
    event ChargingStarted(address indexed user, uint256 timestamp, uint8 chargerIndex);
    event CostCharged(address indexed user, uint256 cost);
    event Paused(address account);
    event Unpaused(address account);

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

    // =========================================================================
    // Pause and Unpause Functionality Tests
    // =========================================================================

    function test_ownerCanPauseAndUnpause() public {
        assertFalse(chargingStation.paused(), "Contract should not be paused initially");

        vm.prank(alice);
        // For events with non-indexed parameters, they are in the data.
        // topic0 (event signature) is always checked by `emit Paused(alice)`.
        // We are not checking topic1, topic2, topic3. We are checking data.
        vm.expectEmit(false, false, false, true);
        emit Paused(alice);
        chargingStation.pause();
        assertTrue(chargingStation.paused(), "Contract should be paused after owner pauses");

        vm.prank(alice);
        vm.expectEmit(false, false, false, true);
        emit Unpaused(alice);
        chargingStation.unpause();
        assertFalse(chargingStation.paused(), "Contract should be unpaused after owner unpauses");
    }

    function test_nonOwnerCannotPause() public {
        // vm.expectRevert("Ownable: caller is not the owner");
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob));
        vm.prank(bob);
        chargingStation.pause();
    }

    function test_nonOwnerCannotUnpause() public {
        vm.prank(alice);
        chargingStation.pause(); // Owner pauses first

        // vm.expectRevert("Ownable: caller is not the owner");
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob));
        vm.prank(bob);
        chargingStation.unpause();
    }

    function test_startCharging_whenPaused() public {
        vm.prank(alice);
        chargingStation.pause();

        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        vm.prank(bob);
        chargingStation.startCharging();
    }

    function test_functionsWork_afterUnpause() public {
        vm.prank(alice);
        chargingStation.pause();
        assertTrue(chargingStation.paused(), "Contract should be paused");

        vm.prank(alice);
        chargingStation.unpause();
        assertFalse(chargingStation.paused(), "Contract should be unpaused");

        // Test startCharging
        vm.prank(bob);
        chargingStation.startCharging();
        (address u, uint256 startTime) = chargingStation.chargingSessions(0); // Assuming Bob gets charger 0
        assertEq(u, bob, "Bob should be charging on charger 0");
        assertTrue(startTime > 0, "Start time should be set for charger 0");

        // Warp time a bit to simulate charging duration
        skip(5 * 60); // Skip 5 minutes

        // Test stopCharging
        uint256 costFor5Min = 5 * chargingStation.costPerMinute();

        // Deal Bob exactly enough for this transaction to check his balance becomes 0
        vm.deal(bob, costFor5Min);

        vm.prank(bob);
        chargingStation.stopCharging{value: costFor5Min}(0); // Bob pays costFor5Min from charger 0

        (u, startTime) = chargingStation.chargingSessions(0);
        assertEq(u, address(0), "Charger 0 should be available after stopping");
        assertEq(startTime, 0, "Start time should be reset for charger 0");

        // Bob's balance should be 0 after paying the exact amount he was dealt for this tx
        assertEq(bob.balance, 0, "Bob balance should be 0 after paying the exact amount dealt for the transaction");
    }
}
