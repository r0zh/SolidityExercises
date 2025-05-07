// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title Second exercise of the Solidity Programming Language module
 * @dev There are two versions of the agenda contract
 * @author Roberto Sánchez Martín
 */

// 1. Cada entrada de la agenda está compuesta por una dirección ETH y un nombre
/**
 * @title Agenda_1
 * @notice This contract allows to create a simple agenda for everyone
 */
contract Agenda_1 {
    mapping(address => string) agenda;
    mapping(string => address) agendaReverse;
    address[] contacts;

    /**
     * @notice Set a contact in the agenda
     * @param addr The address of the contact
     * @param name The name of the contact
     */
    function setContact(address addr, string memory name) public {
        require(agendaReverse[name] == address(0), "A contact with this name already exists");
        require(bytes(agenda[addr]).length == 0, "A contact with this address already exists");
        agenda[addr] = name;
        agendaReverse[name] = addr;
        contacts.push(addr);
    }

    /**
     * @notice Update a contact in the agenda
     * @param addr The address of the contact
     * @param name The name of the contact
     */
    function updateContact(address addr, string memory name) public {
        require(bytes(agenda[addr]).length > 0, "The contact does not exist");
        require(agendaReverse[name] == address(0), "A contact with this name already exists");
        agenda[addr] = name;
        agendaReverse[name] = addr;
    }

    /**
     * @notice Get a contact from the agenda
     * @param addr The address of the contact
     * @return The name of the contact
     */
    function getContactName(address addr) public view returns (string memory) {
        require(bytes(agenda[addr]).length > 0, "The contact does not exist");
        return agenda[addr];
    }

    /**
     * @notice Get a contact address from the agenda
     * @param name The name of the contact
     * @return The address of the contact
     */
    function getContactAddress(string memory name) public view returns (address) {
        require(agendaReverse[name] != address(0), "The contact does not exist");
        return agendaReverse[name];
    }

    /**
     * @notice Get all contacts from the agenda
     * @return The list of contacts
     */
    function getAllContactsAddress() public view returns (address[] memory) {
        return contacts;
    }

    // FUNCTIONS THAT SHOULD BE ON THE FRONTEND

    /**
     * @notice Get all contacts name from the agenda
     * @return The list of contacts
     * @dev This function should be on the frontend
     */
    function getAllContactsName() public view returns (string[] memory) {
        uint256 length = contacts.length;
        string[] memory names = new string[](length);
        for (uint256 i = 0; i < length; i++) {
            names[i] = agenda[contacts[i]];
        }
        return names;
    }
}

// --------------------------------------------------------------------------------------------------------------------------------------

// 2. Cada usuario pueda crear su propia agenda
/**
 * @title Agenda_2_factory
 * @notice This contract allows users to create their own agenda
 * @dev This contract is a factory contract that creates new instances of the Agenda_1 contract
 */
contract Agenda_2_factory {
    Agenda_1[] public agendas;

    function createAgenda() public returns (uint256 idAgenda) {
        Agenda_1 newAgenda = new Agenda_1();
        agendas.push(newAgenda);
        return agendas.length - 1;
    }

    // FUNCTIONS THAT SHOULD BE ON THE FRONTEND. This functions should be on the frontend but are here for testing purposes

    modifier agendaExists(uint256 idAgenda) {
        require(idAgenda < agendas.length, "Agenda does not exist");
        _;
    }

    function getAgendaAddress(uint256 idAgenda) public view agendaExists(idAgenda) returns (address) {
        return address(agendas[idAgenda]);
    }

    function setContact(uint256 idAgenda, address direccion, string memory nombre) public agendaExists(idAgenda) {
        agendas[idAgenda].setContact(direccion, nombre);
    }

    function getContactName(uint256 idAgenda, address direccion)
        public
        view
        agendaExists(idAgenda)
        returns (string memory)
    {
        return agendas[idAgenda].getContactName(direccion);
    }

    function getContactAddress(uint256 idAgenda, string memory nombre)
        public
        view
        agendaExists(idAgenda)
        returns (address)
    {
        return agendas[idAgenda].getContactAddress(nombre);
    }

    function getAllContactsAddress(uint256 idAgenda) public view agendaExists(idAgenda) returns (address[] memory) {
        return agendas[idAgenda].getAllContactsAddress();
    }

    function getAllContactsName(uint256 idAgenda) public view agendaExists(idAgenda) returns (string[] memory) {
        return agendas[idAgenda].getAllContactsName();
    }
}

/**
 * @title Agenda_2_minimal_proxy
 * @notice This contract allows users to create their own agenda using minimal proxy
 * @dev This contract is more efficient than Agenda_2_factory because it uses minimal proxy. It uses the Clones library from OpenZeppelin
 */
contract Agenda_2_minimal_proxy {
    using Clones for address;

    // The address of the Agenda_1 contract that will be used as a template
    address public agenda;
    // The list of all agendas created
    address[] public agendas;

    constructor() {
        agenda = address(new Agenda_1());
    }

    function createClone() external returns (address) {
        address clone = agenda.clone();
        agendas.push(clone);
        return clone;
    }

    // FUNCTIONS THAT SHOULD BE ON THE FRONTEND. This functions should be on the frontend but are here for testing purposes

    modifier agendaExists(uint256 idAgenda) {
        require(idAgenda < agendas.length, "Agenda does not exist");
        _;
    }

    function getAgendaAddress(uint256 idAgenda) public view agendaExists(idAgenda) returns (address) {
        return address(agendas[idAgenda]);
    }

    function setContact(uint256 idAgenda, address direccion, string memory nombre) public agendaExists(idAgenda) {
        Agenda_1(agendas[idAgenda]).setContact(direccion, nombre);
    }

    function getContactName(uint256 idAgenda, address direccion)
        public
        view
        agendaExists(idAgenda)
        returns (string memory)
    {
        return Agenda_1(agendas[idAgenda]).getContactName(direccion);
    }

    function getContactAddress(uint256 idAgenda, string memory nombre)
        public
        view
        agendaExists(idAgenda)
        returns (address)
    {
        return Agenda_1(agendas[idAgenda]).getContactAddress(nombre);
    }

    function getAllContactsAddress(uint256 idAgenda) public view agendaExists(idAgenda) returns (address[] memory) {
        return Agenda_1(agendas[idAgenda]).getAllContactsAddress();
    }

    function getAllContactsName(uint256 idAgenda) public view agendaExists(idAgenda) returns (string[] memory) {
        return Agenda_1(agendas[idAgenda]).getAllContactsName();
    }
}

// --------------------------------------------------------------------------------------------------------------------------------------

// 3. Cada usuario solo puede ver sus contactos, editarlos o borrarlos.
// @dev I will focus on the minimal proxy version of the agenda contract, the factory version would be more simple but less efficient

/**
 * @title Agenda_3
 * @notice Agenda contract that will be used to create agendas in the Agenda_3_minimal_proxy contract
 * @dev This contract use the OpenZeppelin OwnableUpgradeable contract to manage the owner of the agenda and
 *      the Initializable contract to be able to use the initialize function when the contract is cloned
 */
contract Agenda_3 is Initializable, OwnableUpgradeable {
    mapping(address => string) agenda;
    mapping(string => address) agendaReverse;
    address[] contacts;

    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
    }

    /**
     * @notice Set a contact in the agenda
     * @param addr The address of the contact
     * @param name The name of the contact
     */
    function setContact(address addr, string memory name) public onlyOwner {
        require(agendaReverse[name] == address(0), "A contact with this name already exists");
        require(bytes(agenda[addr]).length == 0, "A contact with this address already exists");
        agenda[addr] = name;
        agendaReverse[name] = addr;
        contacts.push(addr);
    }

    /**
     * @notice Update a contact in the agenda
     * @param addr The address of the contact
     * @param name The name of the contact
     */
    function updateContact(address addr, string memory name) public onlyOwner {
        require(bytes(agenda[addr]).length > 0, "The contact does not exist");
        require(agendaReverse[name] == address(0), "A contact with this name already exists");
        agenda[addr] = name;
        agendaReverse[name] = addr;
    }

    /**
     * @notice Get a contact from the agenda
     * @param addr The address of the contact
     * @return The name of the contact
     */
    function getContactName(address addr) public view onlyOwner returns (string memory) {
        require(bytes(agenda[addr]).length > 0, "The contact does not exist");
        return agenda[addr];
    }

    /**
     * @notice Get a contact address from the agenda
     * @param name The name of the contact
     * @return The address of the contact
     */
    function getContactAddress(string memory name) public view onlyOwner returns (address) {
        require(agendaReverse[name] != address(0), "The contact does not exist");
        return agendaReverse[name];
    }

    /**
     * @notice Get all contacts from the agenda
     * @return The list of contacts
     */
    function getAllContactsAddress() public view onlyOwner returns (address[] memory) {
        return contacts;
    }

    // FUNCTIONS THAT SHOULD BE ON THE FRONTEND

    /**
     * @notice Get all contacts name from the agenda
     * @return The list of contacts
     * @dev This function should be on the frontend
     */
    function getAllContactsName() public view onlyOwner returns (string[] memory) {
        uint256 length = contacts.length;
        string[] memory names = new string[](length);
        for (uint256 i = 0; i < length; i++) {
            names[i] = agenda[contacts[i]];
        }
        return names;
    }
}

/**
 * @title Agenda_3_minimal_proxy
 * @notice This contract allows users to create their own agenda using minimal proxy
 * @dev This contract uses the Clones library from OpenZeppelin to create efficient clones of the Agenda_3 contract
 *      To test the Agenda_3 contract in the Remix IDE, you can get the address of the Agenda_3 contract and use it to interact with the contract
 */
contract Agenda_3_minimal_proxy {
    using Clones for address;
    // The address of the Agenda_3 contract that will be used as a template

    address public agenda;
    // The list of all agendas created
    address[] public agendas;

    constructor() {
        agenda = address(new Agenda_3());
    }

    function createClone() external returns (address) {
        address clone = agenda.clone();
        Agenda_3(clone).initialize(msg.sender);
        agendas.push(clone);
        return clone;
    }
}

// --------------------------------------------------------------------------------------------------------------------------------------

// 4. Un usuario puede delegar el acceso de solo lectura de su agenda a otro usuario por un tiempo limitado
/**
 * @title Agenda_4
 * @notice Agenda contract that will be used to create agendas in the Agenda_3_minimal_proxy contract
 * @dev This contract use the OpenZeppelin OwnableUpgradeable contract to manage the owner of the agenda and
 *      the Initializable contract to be able to use the initialize function when the contract is cloned
 */
contract Agenda_4 is Initializable, OwnableUpgradeable {
    mapping(address => string) agenda;
    mapping(string => address) agendaReverse;
    mapping(address => uint256) public expirationDates;
    address[] contacts;

    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
    }

    modifier userAllowed() {
        require(
            msg.sender == owner() || expirationDates[msg.sender] > block.timestamp,
            "You are not allowed to access this agenda"
        );
        _;
    }

    /**
     * @notice Allow the access of the agenda to another user for a limited time
     * @param addr The address of the contact
     * @param time The time in minutes until the access is allowed
     */
    function allowAccess(address addr, uint256 time) public onlyOwner {
        require(time > 0, "The allowed time must be > 0");
        expirationDates[addr] = block.timestamp + (time * 60);
    }

    /**
     * @notice Set a contact in the agenda
     * @param addr The address of the contact
     * @param name The name of the contact
     */
    function setContact(address addr, string memory name) public onlyOwner {
        require(agendaReverse[name] == address(0), "A contact with this name already exists");
        require(bytes(agenda[addr]).length == 0, "A contact with this address already exists");
        agenda[addr] = name;
        agendaReverse[name] = addr;
        contacts.push(addr);
    }

    /**
     * @notice Update a contact in the agenda
     * @param addr The address of the contact
     * @param name The name of the contact
     */
    function updateContact(address addr, string memory name) public onlyOwner {
        require(bytes(agenda[addr]).length > 0, "The contact does not exist");
        require(agendaReverse[name] == address(0), "A contact with this name already exists");
        agenda[addr] = name;
        agendaReverse[name] = addr;
    }

    /**
     * @notice Get a contact from the agenda
     * @param addr The address of the contact
     * @return The name of the contact
     */
    function getContactName(address addr) public view userAllowed returns (string memory) {
        require(bytes(agenda[addr]).length > 0, "The contact does not exist");
        return agenda[addr];
    }

    /**
     * @notice Get a contact address from the agenda
     * @param name The name of the contact
     * @return The address of the contact
     */
    function getContactAddress(string memory name) public view userAllowed returns (address) {
        require(agendaReverse[name] != address(0), "The contact does not exist");
        return agendaReverse[name];
    }

    /**
     * @notice Get all contacts from the agenda
     * @return The list of contacts
     */
    function getAllContactsAddress() public view userAllowed returns (address[] memory) {
        return contacts;
    }

    // FUNCTIONS THAT SHOULD BE ON THE FRONTEND

    /**
     * @notice Get all contacts name from the agenda
     * @return The list of contacts
     * @dev This function should be on the frontend
     */
    function getAllContactsName() public view userAllowed returns (string[] memory) {
        uint256 length = contacts.length;
        string[] memory names = new string[](length);
        for (uint256 i = 0; i < length; i++) {
            names[i] = agenda[contacts[i]];
        }
        return names;
    }
}

contract Agenda_4_minimal_proxy {
    using Clones for address;
    // The address of the Agenda_4 contract that will be used as a template

    address public agenda;
    // The list of all agendas created
    address[] public agendas;

    constructor() {
        agenda = address(new Agenda_4());
    }

    function createClone() external returns (address) {
        address clone = agenda.clone();
        Agenda_3(clone).initialize(msg.sender);
        agendas.push(clone);
        return clone;
    }
}

// 5. Se puede buscar tanto por dirección como por nombre
// Ya está implementado desde la primera versión de la agenda
