pragma solidity 0.4.24;

import "./Mixins/Pausable.sol";

/** @title Wallet. */
contract Wallet is Pausable {

    //---- MODIFIERS

    /** @dev Check if an address is 0x0.
     *  @param _address Address to be checked.
     */
    modifier notNull(address _address) {
        require(
            address(_address) != address(0),
            "Payee address can not be 0x0"
        );
        _;
      }

    /** @dev Check if an address is a Payee.
     *  @param _address Address to be checked.
     */
    modifier onlyPayee(address _address) {
        require(
            payees[_address].allowed == true,
            "Address is not a Payee"
        );
        _;
    }

    /** @dev Check if Wallet has enough balance.
     *  @param _value Value to be compared.
     */
    modifier enoughBalance(uint _value) {
        require(
            address(this).balance >= _value,
            "Wallet does not have enough ETH"
        );
        _;
    }

    //---- EVENTS

    /** @dev Event to log a Payee is added.
     *  @param payee Address of the Payee.
     */
    event PayeeAdded(address payee);

    /** @dev Event to log a Payee is removed.
     *  @param payee Address of the Payee.
     */
    event PayeeRemoved(address payee);

    /** @dev Event to log a Payee is whitelisted.
     *  @param payee Address of the Payee.
     */
    event PayeeWhitelisted(address payee);

    /** @dev Event to log a Payee is blacklisted.
     *  @param payee Address of the Payee.
     */
    event PayeeBlacklisted(address payee);

    /** @dev Event to log the daily limit to withdraw is changed.
     *  @param dailyLimit New amount limit.
     */
    event DailyLimitChanged(uint dailyLimit);

    /** @dev Event to log a Payee withdraws funds.
     *  @param payee Address of the Payee.
     *  @param value Amount withdrawn
     */
    event PayeeWithdrawal(address indexed payee, uint value);

    /** @dev Event to log the Owner withdraws funds.
     *  @param value Amount withdrawn
     */
    event OwnerWhitdrawal(uint value);

    /** @dev Event to log a Deposit is done.
     *  @param sender Address of the sender of the deposit.
     *  @param value Amount deposited.
     */
    event Deposit(
        address indexed sender,
        uint value
    );

    //---- STORAGE VARIABLES

    struct Payee {
        bool allowed;
        bool whitelisted;
        uint firstDailyWithdrawalTime;
        uint dailySpent;
    }

    struct Withdrawal {
        bool allowed;
        bool dailyUpdate;
    }

    mapping (address => Payee) public payees;
    uint public dailyLimit;

    /** @dev Constructor: Initialize Wallet
     *  @param _payees Array of payees address allowed to withdraw funds
     *  @param _whitelisted Array of bools defining if the payees from _payees arrays
     *         are or not whitelisted.
     *  @param _dailyLimit Maximum funds to be withdrawn every 24 hours
     */
    constructor(
        address[] _payees,
        bool[] _whitelisted,
        uint _dailyLimit
    )
        public
        payable
    {
        if(_payees.length > 0) {
            addPayees(_payees, _whitelisted);
        }

        dailyLimit = _dailyLimit;
    }

    //---- EXTERNAL functions

     /** @dev Whitelist a Payee to allow them to withdraw without restrictions
      *  @param _payee Address of the Payee.
      */
     function whitelistPayee(address _payee)
         external
         onlyOwner
     {
         require(
             isPayee(_payee) && !isWhitelisted(_payee),
             "Address can not be whitelisted"
         );
         payees[_payee].whitelisted = true;

         emit PayeeWhitelisted(_payee);
     }

     /** @dev Blacklist a Payee to apply daily withdrawal restrictions
      *  @param _payee Address of the Payee.
      */
     function blacklistPayee(address _payee)
         external
         onlyOwner
     {
         require(
             isPayee(_payee) && isWhitelisted(_payee),
             "Address can not be blacklisted"
         );
         payees[_payee].whitelisted = false;
         emit PayeeBlacklisted(_payee);
     }

     /** @dev Set daily withdrawal limits to blacklisted payees
      *  @param _dailyLimit New withdrawal limit amount
      */
     function setDailyLimit(uint _dailyLimit)
         external
         onlyOwner
     {
         require(dailyLimit != _dailyLimit,
           "Same dalyLimit can not be set"
         );
         dailyLimit = _dailyLimit;
         emit DailyLimitChanged(_dailyLimit);
     }

     /** @dev Payee calls this function to withdraw some funds
      *  @param _value Amount to be withdrawn.
      */
     function payeeWithdraws(uint _value)
         external
         whenNotPaused
         onlyPayee(msg.sender)
         enoughBalance(_value)
     {
         if(payees[msg.sender].whitelisted == true) {
             address(msg.sender).transfer(_value);
             emit PayeeWithdrawal(msg.sender, _value);
         } else {
             Withdrawal memory withdrawalState = payeeWithdrawalState(msg.sender,_value);
             require(
                 withdrawalState.allowed,
                 "Payee is not allowed to withdraw"
             );
             if(withdrawalState.dailyUpdate) {
                 payees[msg.sender].firstDailyWithdrawalTime = now;
                 payees[msg.sender].dailySpent = _value;
             } else {
                 payees[msg.sender].dailySpent += _value;
             }
             address(msg.sender).transfer(_value);
             emit PayeeWithdrawal(msg.sender, _value);
         }
     }

     /** @dev Owner withdraws some funds
      *  @param _value Amount to be withdrawn.
      */
     function ownerWithdraws(uint _value)
         external
         onlyOwner
     {
         address(msg.sender).transfer(_value);
         emit OwnerWhitdrawal(_value);
     }

     /** @dev Destruct contract and send balance to the owner.
      */
     function kill() external onlyOwner {
         selfdestruct(owner());
     }

     //---- PUBLIC functions

     /** @dev Add multiples payees
      *  @param _payees Array of payees address allowed to withdraw funds
      *  @param _whitelisted Array of bools defining if the payees from _payees arrays
      *         are or not whitelisted.
      */
     function addPayees(
         address[] _payees,
         bool[] _whitelisted
     )
         public
         onlyOwner
     {
         require(
             _payees.length == _whitelisted.length,
             "Payees and Whitelisted arrays do not have same length"
         );

         for(uint i = 0; i < _payees.length; i++) {
             addPayee(_payees[i], _whitelisted[i]);
         }
    }

    /** @dev Add a single payee
     *  @param _payee Payees address allowed to withdraw funds
     *  @param _whitelisted Bools defining if the payee is or not whitelisted.
     */
    function addPayee(
         address _payee,
         bool _whitelisted
    )
         public
         onlyOwner
         notNull(_payee)
    {
         require(
             !isPayee(_payee),
             "Address is already a Payee"
         );

         payees[_payee] = Payee({
             allowed: true,
             whitelisted: _whitelisted,
             firstDailyWithdrawalTime: 0,
             dailySpent: 0
         });

         emit PayeeAdded(_payee);
    }

     /** @dev Remove a single payee
      *  @param _payee Payees address to be removed
      */
     function removePayee(
         address _payee
     )
         public
         onlyOwner
     {
         require(
             isPayee(_payee),
             "Address is not a valid Payee"
         );

         payees[_payee].allowed = false;
         payees[_payee].whitelisted = false;
         payees[_payee].firstDailyWithdrawalTime = 0;
         payees[_payee].dailySpent = 0;

         emit PayeeRemoved(_payee);
    }

    /** @dev Check if an adress is a Payee
     *  @param _payee Address to be checked
     */
    function isPayee(address _payee) public view returns(bool) {
        return payees[_payee].allowed;
    }

    /** @dev Check if an adress is a whitelisted
     *  @param _payee Address to be checked
     */
    function isWhitelisted(address _payee) public view returns(bool) {
        require(
          isPayee(_payee),
          "Address is not a valid Payee"
        );
        return payees[_payee].whitelisted;
    }

    /** @dev Fallback to receive ETH and fail laudly if some data is sent to it
     */
    function() public payable {
        require(
            msg.data.length == 0,
            "Unidentified function signature"
        );

        if(msg.value > 0) {
            emit Deposit(msg.sender, msg.value);
        }
    }

    //---- INTERNAL functions

    /** @dev Get the whithdrawal's state of a certain payee for a certain
     *  withdrawal amount.
     *  @param _payee Address to be checked
     *  @param _value Amount to be withdrawn
     */
    function payeeWithdrawalState(
        address _payee,
        uint _value
    )
        internal view
        returns(Withdrawal)
    {
        uint allowedWithdrawalTime = payees[_payee].firstDailyWithdrawalTime + 1 days;
        uint remainingAmount;

        //Avoiding uint underflow
        if(dailyLimit > payees[_payee].dailySpent) {
            remainingAmount = dailyLimit - payees[_payee].dailySpent;
        } else { //Might happen if dailyLimit has been reduced
            remainingAmount = 0;
        }

        if(now >= allowedWithdrawalTime) { //24h have passed since first daily withdrawal
            if(_value <= dailyLimit) {
                return getWithdrawalState(true, true);
            } else {
                return getWithdrawalState(false, false);
            }
        } else { //24h have not passed since first daily withdrawal
            if(_value <= remainingAmount) {
                return getWithdrawalState(true, false);
            } else {
                return getWithdrawalState(false, false);
            }
        }
    }

    /** @dev Returns Withdrawal memory struct
     *  @param _allowed The withdrawal has been allowed
     *  @param _dailyUpdate Payee's withdrawal state should be updated
     */
    function getWithdrawalState(
        bool _allowed,
        bool _dailyUpdate
    )
        internal
        pure
        returns(Withdrawal)
    {
        Withdrawal memory withdrawalState = Withdrawal({
            allowed: _allowed,
            dailyUpdate: _dailyUpdate
        });
        return withdrawalState;
    }
}
