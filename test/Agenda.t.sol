// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

import "forge-std/Test.sol";
import "../src/Agenda.sol";

contract Agenda_1_Test is Test {
    Agenda_1 public agenda;
    address user1 = address(0x1);
    address user2 = address(0x2);
    address user3 = address(0x3);
    string name1 = "Alice";
    string name2 = "Bob";
    string name3 = "Charlie";

    function setUp() public {
        agenda = new Agenda_1();
    }

    function test_SetContact_Success() public {
        agenda.setContact(user1, name1);
        assertEq(agenda.getContactName(user1), name1);
        assertEq(agenda.getContactAddress(name1), user1);
        address[] memory addresses = agenda.getAllContactsAddress();
        assertEq(addresses.length, 1);
        assertEq(addresses[0], user1);
        string[] memory names = agenda.getAllContactsName();
        assertEq(names.length, 1);
        assertEq(names[0], name1);
    }

    function test_SetContact_Fail_NameExists() public {
        agenda.setContact(user1, name1);
        vm.expectRevert("A contact with this name already exists");
        agenda.setContact(user2, name1);
    }

    function test_SetContact_Fail_AddressExists() public {
        agenda.setContact(user1, name1);
        vm.expectRevert("A contact with this address already exists");
        agenda.setContact(user1, name2);
    }

    function test_UpdateContact_Success() public {
        agenda.setContact(user1, name1);
        agenda.updateContact(user1, name2);
        assertEq(agenda.getContactName(user1), name2);
        assertEq(agenda.getContactAddress(name2), user1);
        // Check reverse mapping for old name is cleared (implicitly tested by getContactAddress failure)
        vm.expectRevert("The contact does not exist");
        agenda.getContactAddress(name1);
    }

    function test_UpdateContact_Fail_ContactDoesNotExist() public {
        vm.expectRevert("The contact does not exist");
        agenda.updateContact(user1, name1);
    }

    function test_UpdateContact_Fail_NewNameExists() public {
        agenda.setContact(user1, name1);
        agenda.setContact(user2, name2);
        vm.expectRevert("A contact with this name already exists");
        agenda.updateContact(user1, name2); // Try to update user1's name to user2's name
    }

    function test_GetContactName_Success() public {
        agenda.setContact(user1, name1);
        assertEq(agenda.getContactName(user1), name1);
    }

    function test_GetContactName_Fail_DoesNotExist() public {
        vm.expectRevert("The contact does not exist");
        agenda.getContactName(user1);
    }

    function test_GetContactAddress_Success() public {
        agenda.setContact(user1, name1);
        assertEq(agenda.getContactAddress(name1), user1);
    }

    function test_GetContactAddress_Fail_DoesNotExist() public {
        vm.expectRevert("The contact does not exist");
        agenda.getContactAddress(name1);
    }

    function test_GetAllContactsAddress_Empty() public {
        address[] memory addresses = agenda.getAllContactsAddress();
        assertEq(addresses.length, 0);
    }

    function test_GetAllContactsAddress_Multiple() public {
        agenda.setContact(user1, name1);
        agenda.setContact(user2, name2);
        address[] memory addresses = agenda.getAllContactsAddress();
        assertEq(addresses.length, 2);
        assertEq(addresses[0], user1);
        assertEq(addresses[1], user2);
    }

     function test_GetAllContactsName_Empty() public {
        string[] memory names = agenda.getAllContactsName();
        assertEq(names.length, 0);
    }

    function test_GetAllContactsName_Multiple() public {
        agenda.setContact(user1, name1);
        agenda.setContact(user2, name2);
        string[] memory names = agenda.getAllContactsName();
        assertEq(names.length, 2);
        assertEq(names[0], name1);
        assertEq(names[1], name2);
    }
}