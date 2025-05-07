// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

/**
 * @title Bank
 * @dev A simple bank contract that allows deposits, withdrawals, and loans
 */
contract Bank {
    struct Loan {
        uint256 amount;
        uint256 startDate;
    }

    mapping(address => uint256) private balances;
    mapping(address => Loan) private loans;
    uint256 public deposited;
    address immutable owner; // immutable for gas optimization

    constructor() payable {
        deposited += msg.value;
        owner = msg.sender;
    }

    /**
     * @dev Returns the total balance of the bank contract
     */
    function checkBankBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev Allows users to deposit funds into their account
     */
    function deposit() external payable {
        balances[msg.sender] += msg.value;
        deposited += msg.value;
    }

    /**
     * @dev Allows users to withdraw funds from their account
     * @param amount The amount to withdraw
     */
    function withdraw(uint256 amount) external {
        address borrower = msg.sender;

        require(balances[borrower] >= amount, "You don't have enough money in the bank");
        require(address(this).balance >= amount, "The bank doesn't have enough funds to pay you");

        balances[borrower] -= amount;
        deposited -= amount;

        payable(borrower).transfer(amount);
    }

    /**
     * @dev Returns the balance of the caller's account
     */
    function checkBalance() external view returns (uint256) {
        return balances[msg.sender];
    }

    /**
     * @dev Allows users to take out a loan
     * @param amount The loan amount requested
     */
    function getLoan(uint256 amount) external {
        address borrower = msg.sender;

        // Check that user doesn't borrow more than 95% of bank balance
        require(amount <= (deposited * 95) / 100, "You are trying to borrow more than 95% of bank balance");

        uint256 realBalance = balances[borrower] - loans[borrower].amount;
        // Check that user doesn't borrow more than half their real balance
        require(amount <= realBalance / 2, "You can't borrow more than half your real balance in the bank");

        // If this is a new loan, set the start date
        if (loans[borrower].amount == 0) {
            loans[borrower].startDate = block.timestamp;
        }

        loans[borrower].amount += amount;
        balances[borrower] += amount;
    }

    /**
     * @dev Calculates the interest on a loan
     * @param borrower The address of the borrower
     * @return The interest amount (1 wei per hour)
     */
    function computeInterest(address borrower) public view returns (uint256) {
        // Interest = 1 wei per hour
        require(loans[borrower].amount > 0, "That address does not have a loan");
        return (block.timestamp - loans[borrower].startDate) / 3600;
    }

    /**
     * @dev Calculates the total amount to repay a loan (principal + interest)
     * @param borrower The address of the borrower
     * @return The total repayment amount
     */
    function computeLoanRepayment(address borrower) public view returns (uint256) {
        return loans[borrower].amount + computeInterest(borrower);
    }

    /**
     * @dev Allows borrowers to repay their loan with ETH
     */
    function payLoanWithEth() external payable {
        address borrower = msg.sender;
        uint256 repaymentAmount = computeLoanRepayment(borrower);

        require(msg.value == repaymentAmount, "You need to pay the exact amount to resolve your loan");

        uint256 interest = computeInterest(borrower);
        payable(owner).transfer(interest);
        deposited += loans[borrower].amount;
        loans[borrower].amount = 0;
    }

    /**
     * @dev Allows borrowers to repay their loan from their bank account
     */
    function payLoanFromBankAcount() external {
        address borrower = msg.sender;
        uint256 repaymentAmount = computeLoanRepayment(borrower);
        uint256 realBalance = balances[borrower] - loans[borrower].amount;

        require(realBalance >= repaymentAmount, "You don't have enough money in the bank to pay the loan");

        balances[borrower] -= repaymentAmount;
        uint256 interest = computeInterest(borrower);
        payable(owner).transfer(interest);
        deposited -= interest;
        loans[borrower].amount = 0;
    }

    /**
     * @dev Returns the caller's outstanding loan amount plus interest
     */
    function checkLoan() external view returns (uint256) {
        require(loans[msg.sender].amount > 0, "That address doesn't have any loans");
        return computeLoanRepayment(msg.sender);
    }

    /**
     * @dev Returns a specific borrower's outstanding loan amount plus interest
     * @param borrower The address of the borrower
     */
    function checkBorrowerLoan(address borrower) external view returns (uint256) {
        require(loans[borrower].amount > 0, "That address doesn't have any loans");
        return computeLoanRepayment(borrower);
    }

    /**
     * @notice Allows the contract to receive ETH
     * @dev If someone sends ETH to the contract, it will be added to the deposited amount as a donation
     */
    receive() external payable {
        deposited += msg.value;
    }
}
