// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

/**
 * @title First exercise of the Solidity Programming Language module
 * @author Roberto Sánchez Martín
 */

/**
 * @title SimpleStorage
 * @notice Original SimpleStorage contract
 */
contract SimpleStorage {
    uint256 storedData;

    function set(uint256 x) public {
        storedData = x;
    }

    function get() public view returns (uint256) {
        return storedData;
    }
}

/**
 * 1. Modifica el contrato para que el valor almacenado lo combine usando una operación elemental con el valor anterior.
 * Por ejemplo, para la multiplicación, si tengo 2 y almaceno 4, debería guardar 8.
 */

// 1.1 Para implementar la operación usa una función pure con dos argumentos
/**
 * @title SimpleStorage1_1
 * @notice SimpleStorage contract with arithmetic operations, using pure functions.
 */
contract SimpleStorage1_1 {
    uint256 storedData;

    /**
     * @notice Sets the stored data by summing the current stored data with the input value.
     * @param x The value to be added to the stored data.
     */
    function set(uint256 x) public {
        storedData = sum(storedData, x);
    }

    /**
     * @notice Sums two unsigned integers.
     * @return The sum of the input values.
     */
    function sum(uint256 x, uint256 y) public pure returns (uint256) {
        return x + y;
    }

    /**
     * @notice Subtracts two unsigned integers.
     * @return The difference between the input values.
     */
    function substract(uint256 x, uint256 y) public pure returns (uint256) {
        return x - y;
    }

    /**
     * @notice Multiplies two unsigned integers.
     * @return The product of the input values.
     */
    function multiplication(uint256 x, uint256 y) public pure returns (uint256) {
        return x * y;
    }

    /**
     * @notice Divides two unsigned integers.
     * @return The quotient of the input values.
     * @dev This function does not handle division by zero.
     */
    function division(uint256 x, uint256 y) public pure returns (uint256) {
        return x / y;
    }

    /**
     * @notice Returns the stored data.
     * @return The stored data.
     */
    function get() public view returns (uint256) {
        return storedData;
    }
}

// 1.2 Para implementar la operación usa una función view con un solo argumento
/**
 * @title SimpleStorage1_2
 * @notice SimpleStorage contract with arithmetic operations, using view functions.
 */
contract SimpleStorage1_2 {
    uint256 storedData;

    /**
     * @notice Sets the stored data by summing the current stored data with the input value.
     * @param x The value to be added to the stored data.
     */
    function set(uint256 x) public {
        storedData = sum(x);
    }

    /**
     * @notice Sums the input value with the stored data.
     * @return The sum of the input value and the stored data.
     */
    function sum(uint256 x) public view returns (uint256) {
        return storedData + x;
    }

    /**
     * @notice Subtracts the stored data from the input value.
     * @return The difference between the input value and the stored data.
     */
    function substract(uint256 x) public view returns (uint256) {
        return storedData - x;
    }

    /**
     * @notice Multiplies the input value with the stored data.
     * @return The product of the input value and the stored data.
     */
    function multiplication(uint256 x) public view returns (uint256) {
        return storedData * x;
    }

    /**
     * @notice Divides the input value by the stored data.
     * @return The quotient of the input value and the stored data.
     * @dev This function does not handle division by zero.
     */
    function division(uint256 x) public view returns (uint256) {
        require(x != 0, "Division by zero is not allowed.");
        return storedData / x;
    }

    /**
     * @notice Returns the stored data.
     * @return The stored data.
     */
    function get() public view returns (uint256) {
        return storedData;
    }
}

// --------------------------------------------------------------------------------------------------------------------------------------

/**
 * 2. Observa el coste de almacenar el valor modificado y de consultar cual sería el valor nuevo llamando directamente
 * a las funciones view y pure que no modifican el estado.
 */

/**
 * El coste de almacenar el valor modificado es mayor que el coste de consultar el nuevo valor usando las funciones view y pure,
 * ya que almacena el valor en la blockchain, lo que implica un coste de gas. En cambio, las funciones view y pure no modifican el estado,
 * por lo que su coste es menor o nulo.
 */

// --------------------------------------------------------------------------------------------------------------------------------------

/**
 * 3. Comprueba errores de desbordamiento y división por cero con las operaciones aritméticas.
 */

/**
 * Es posible que ocurran errores de desbordamiento y división por cero en las operaciones aritméticas.
 * En el caso de errores de desbordamiento podemos mitigarlos de la siguiente forma (visto en Módulo 3 - Auditoría de Smart Contracts):
 * 1. Asegurar que las variables no pueden nunca llegar a rangos que causen overflow (por diseño o mediante require()).
 * 2. Usar "checked math" verificando la operación antes de ejecutarla y revertir si ocurre.
 * 3. Usar la libreria SafeMath de OpenZeppelin.
 * 4. Usar Solidity 0.8.0 o superior, que incluye verificación de overflow y underflow por defecto, salvo en unchecked, assembly y casts.
 *
 * En el caso de división por cero, podemos usar require() para asegurarnos de que el divisor no es cero antes de realizar la operación:
 */

/**
 * @title SimpleStorage3
 * @notice SimpleStorage contract that handles division by zero.
 */
contract SimpleStorage3 {
    uint256 storedData;

    /**
     * @notice Sets the stored data by dividing the current stored data by the input value.
     * @param x The value to divide the stored data by.
     */
    function set(uint256 x) public {
        storedData = division(storedData, x);
    }

    /**
     * @notice Divides two unsigned integers.
     * @return The quotient of the input values.
     * @dev This function handles division by zero.<
     */
    function division(uint256 x, uint256 y) public pure returns (uint256) {
        require(y != 0, "Division by zero is not allowed.");
        return x / y;
    }
}

// --------------------------------------------------------------------------------------------------------------------------------------

/**
 * 4. Comprueba si el tamaño/tipo del valor a almacenar influyen en el coste
 */

/**
 * El tipo del valor a almacenar si influye en el coste de almacenamiento en la blockchain.
 * Tipos de datos más pequeños (como uint8) ocupan menos espacio y, por lo tanto, son más baratos de almacenar, en cambio,
 * tipos de datos más grandes (como uint256) ocupan más espacio y son más caros de almacenar.
 * Sin embargo una vez establecido el tipo de dato, el tamaño no influye en el coste de almacenamiento, es decir,
 * almacenar un 1 en un uint8 es igual de caro que almacenar un 255 en un uint8.
 */

// ---------------------------------------------------------------------------------------------------------------------------------------

// 5. Implementa una restricción para que solo quién escriba un valor pueda leerlo, si es otro usuario debe recibir 0.

/**
 * @title SimpleStorage5
 * @notice SimpleStorage contract with access control for reading the stored data.
 * @dev I'm using tx.origin to get the address of the user, but this is susceptible to phishing attacks.
 *      We could use msg.sender instead, but the user must be the one who calls the function.
 */
contract SimpleStorage5 {
    uint256 storedData;
    address last;

    /**
     * @notice Sets the stored data and records the address of the user.
     * @param x The value to be stored.
     */
    function set(uint256 x) public {
        last = tx.origin;
        storedData = x;
    }

    /**
     * @notice Gets the stored data if the caller is the last user who set it.
     * @return The stored data or 0 if the caller is not the last user.
     */
    function get() public view returns (uint256) {
        if (tx.origin != last) {
            return 0;
        } else {
            return storedData;
        }
    }
}

// ---------------------------------------------------------------------------------------------------------------------------------------

// 6. Usa un constructor para darle el valor inicial.
/**
 * @title SimpleStorage6
 * @notice SimpleStorage contract with a constructor to set the initial value.
 */
contract SimpleStorage6 {
    uint256 storedData;

    /**
     * @notice Constructor that sets the initial value of storedData.
     */
    constructor(uint256 x) {
        storedData = x;
    }

    /**
     * @notice Sets the stored data.
     * @param x The value to be stored.
     */
    function set(uint256 x) public {
        storedData = x;
    }

    /**
     * @notice Gets the stored data.
     * @return The stored data.
     */
    function get() public view returns (uint256) {
        return storedData;
    }
}

// ---------------------------------------------------------------------------------------------------------------------------------------

// 7. Implementa una restricción para que solo quién despliega el contrato puede actualizar los valores.

/**
 * @title SimpleStorage7
 * @notice SimpleStorage contract with access control for updating values.
 * @dev I'm using tx.origin to get the address of the user, but this is susceptible to phishing attacks.
 *      We could use msg.sender instead, but the user must be the one who calls the function.
 */
contract SimpleStorage7 {
    uint256 storedData;
    address deployer;

    /**
     * @notice Constructor that sets the deployer address.
     */
    constructor() {
        deployer = tx.origin;
    }

    /**
     * @notice Sets the stored data if the caller is the deployer.
     * @param x The value to be stored.
     */
    function set(uint256 x) public {
        require(
            deployer == tx.origin,
            "Solo el que despliega el contrato puede actualizar los valores"
        );
        storedData = x;
    }

    /**
     * @notice Gets the stored data.
     * @return The stored data.
     */
    function get() public view returns (uint256) {
        return storedData;
    }
}
