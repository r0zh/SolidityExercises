// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

/**
* Programa en solidity que simula una agenda
*/

// 1. Cada entrada de la agenda está compuesta por una dirección ETH y un nombre
contract Agenda_1{
    mapping(address direccion => string nombre) agenda;

    function setContact(address direccion, string memory nombre) public {
        agenda[direccion] = nombre;
    }

    function getContact(address direccion) public view returns (string memory) {
        return agenda[direccion];
    }
}

// 2. Cada usuario pueda crear su propia agenda
contract Agenda_2{
    mapping(uint idAgenda => mapping(address direccion => string nombre) agenda) public agendas;

    function setContact(uint idAgenda, address direccion, string memory nombre) public {
        agendas[idAgenda][direccion] = nombre;
    }

    function getContact(uint idAgenda, address direccion) public view returns (string memory) {
        return agendas[idAgenda][direccion];
    }

}

// 3. Cada usuario solo puede ver sus contactos, editarlos o borrarlos.
contract Agenda_3{
    mapping(address owner => mapping(address direccion => string nombre) agenda) public agendas;

    function setContact(address direccion, string memory nombre) public {
        agendas[tx.origin][direccion] = nombre;
    }

    function getContact(address direccion) public view returns (string memory) {
        return agendas[tx.origin][direccion];
    }
}

// 4. Un usuario puede delegar el acceso de solo lectura de su agenda a otro usuario por un tiempo limitado
contract Agenda_4{
    struct Agenda {
        address allowedUser;
        uint allowedTime;
        mapping(address direccion => string nombre) agenda;
    }

    mapping(address owner => Agenda agenda) agendas;

    function setAllowedUser(address agendaOwner, address allowedUser, uint allowedTime) public {
        // Quien manda la transacción es el propietario de la agenda
        require(tx.origin == agendaOwner, "Solo el propietario puede setear los permisos");
        if (tx.origin == agendaOwner) {
            agendas[agendaOwner].allowedUser = allowedUser;
            agendas[agendaOwner].allowedTime = block.timestamp + allowedTime;
        }
    }

    function setContact(address agendaOwner, address direccion, string memory nombre) public {
        // Quien manda la transacción es el propietario de la agenda
        require(tx.origin == agendaOwner, "Solo el propietario puede escribir en su agenda");
        if(tx.origin == agendaOwner){
            agendas[agendaOwner].agenda[direccion] = nombre;
        }
    }

    function getContact(address agendaOwner, address direccion) public view returns (string memory)  {
        // Quien manda la transaccion tiene acceso de lectura a la agenda
        require(tx.origin == agendas[agendaOwner].allowedUser || tx.origin == agendaOwner, "Solo el propietario o el usuario autorizado puede leer la agenda");
        require(tx.origin == agendaOwner || (tx.origin == agendas[agendaOwner].allowedUser && (block.timestamp <= agendas[agendaOwner].allowedTime)), "El tiempo de acceso del usuario autorizado ha expirado ");
        if (tx.origin != agendaOwner && (tx.origin != agendas[agendaOwner].allowedUser || agendas[agendaOwner].allowedTime <= block.timestamp)){
            return "";
        } else {
            return agendas[agendaOwner].agenda[direccion];
        }
    }
}

// 5. Se puede buscar tanto por dirección como por nombre
contract Agenda_5{
    mapping(address direccion => string nombre) agenda;
    mapping(string nombre => address direccion) agendaReverse;

    function setContact(address direccion, string memory nombre) public {
        agenda[direccion] = nombre;
        agendaReverse[nombre] = direccion;
    }

    function getContactName(address direccion) public view returns (string memory) {
        return agenda[direccion];
    }

    function getContactAddress(string memory nombre) public view returns (address) {
        return agendaReverse[nombre];
    }
}
