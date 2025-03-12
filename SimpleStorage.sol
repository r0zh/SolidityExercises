// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

/**
 * 1. Modifica el contrato para que el valor almacenado lo combine usando una operación elemental con el valor anterior. 
 * Por ejemplo, para la multiplicación, si tengo 2 y almaceno 4, debería guardar 8.
*/

// 1.1 Para implementar la operación usa una función pure con dos argumentos
contract SimpleStorage1_1 {
    uint storedData;

    function set(uint x) public {
        storedData = x;
    }

    function sum(uint x, uint data) public pure returns (uint) {
        return x + data;
    }

    function substract(uint x, uint data) public pure returns (uint) {
        return x - data;
    }

    function multiplication(uint x, uint data) public pure returns (uint){
        return x * data;
    }

    function division(uint x, uint data) public pure returns (uint) {
        return x / data;
    }

    function get() public view returns (uint) {
        return storedData;
    }
}

// 1.2 Para implementar la operación usa una función view con un solo argumento
contract SimpleStorage1_2 {
    uint storedData;

    function set(uint x) public {
        storedData = x;
    }

    function sum(uint x) public view returns (uint) {
        return x + storedData;
    }

    function substract(uint x) public view returns (uint) {
        return x - storedData;
    }

    function multiplication(uint x) public view returns (uint) {
        return x * storedData;
    }

    function get() public view returns (uint) {
        return storedData;
    }
}

// 5. Implementa una restricción para que solo quién escriba un valor pueda leerlo, si es otro usuario debe recibir 0.
contract SimpleStorage5 {
    uint storedData;
    address last;

    function set(uint x) public {
        // Suponiendo que "quien escriba el valor" se refiere al emisor de la transaccion
        last = tx.origin;
        storedData = x;
    }

    function get() public view returns (uint) {
        require(last == tx.origin, "Solo puede leer el valor quien lo ha escrito");

        if (tx.origin != last){
            return 0;
        } else {
            return storedData;
        }
    }
}

// 6. Usa un constructor para darle el valor inicial.
contract SimpleStorage6{
    uint storedData;

    constructor(){
        storedData = 50;
    }

    function set(uint x) public {
        storedData = x;
    }

    function get() public view returns (uint) {
        return storedData;
    }
}

// 7. Implementa una restricción para que solo quién despliega el contrato puede actualizar los valores.
contract SimpleStorage7{
    uint storedData;
    address deployer;

    constructor(){
        // Suponiendo que "quién despliega el contrato" se refiere al emisor de la transaccion
        deployer = tx.origin;
    }

    function set(uint x) public {
        require(deployer == tx.origin, "Solo el que despliega el contrato puede actualizar los valores.");
        if(deployer == tx.origin){
            storedData = x;
        }
    }
    
    function get() public view returns(uint) {
        return storedData;
    }
}