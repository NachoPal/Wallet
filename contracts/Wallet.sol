pragma solidity 0.4.24;
pragma experimental ABIEncoderV2;

import "./Mixins/Pausable.sol";
import "./Mixins/SafeMath.sol";

contract Wallet is Pausable {

  using SafeMath for uint256;

  modifier onlyPayee(address _address) {
    require(
      payees[_address].allowed == true,
      "Address is not a Payee"
    );
    _;
  }

  modifier enoughBalance(uint _value) {
    require(
      address(this).balance >= _value,
      "Wallet does not have enough ETH"
    );
    _;
  }

  event PayeeAdded(address payee);
  event PayeeRemoved(address payee);
  event PayeeWhitelisted(address payee);
  event PayeeBlacklisted(address payee);
  event DailyLimitChanged(uint dailyLimit);
  event PayeeWithdrawal(address indexed payee, uint value);
  event OwnerWhitdrawal(uint value);

  /** @dev Event to log a Deposit has been made.
   *  @param sender Address of the sender of the deposit.
   *  @param value Value deposited.
   */
  event Deposit(
      address indexed sender,
      uint value
  );

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

  function addPayee(
    address _payee,
    bool _whitelisted
  )
    public
    onlyOwner
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

  function setDailyLimit(
    uint _dailyLimit
  )
    external
    onlyOwner
  {
    require(dailyLimit != _dailyLimit,
      "Same dalyLimit can not be set"
    );
    dailyLimit = _dailyLimit;
    emit DailyLimitChanged(_dailyLimit);
  }

  function isPayee(address _payee) public view returns(bool) {
    return payees[_payee].allowed;
  }

  function isWhitelisted(address _payee) public view returns(bool) {
    return payees[_payee].whitelisted;
  }

  function payeeWithdraws(uint _value)
    external
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

  function payeeWithdrawalState(
    address _payee,
    uint _value
  )
    internal view
    returns(Withdrawal)
  {
    uint allowedWithdrawalTime = payees[_payee].firstDailyWithdrawalTime + 1 days;
    uint remainingAmount;

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

  function ownerWithdraws(uint _value)
    external
    onlyOwner
  {
    address(msg.sender).transfer(_value);
    emit OwnerWhitdrawal(_value);
  }

  function kill() external onlyOwner {
      selfdestruct(owner());
  }

  function() public payable {
      require(
        msg.data.length == 0,
        "Unidentified function signature"
      );

      if (msg.value > 0) {
        emit Deposit(msg.sender, msg.value);
      }
  }
}
