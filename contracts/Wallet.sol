pragma solidity 0.4.24;
//pragma experimental ABIEncoderV2;

import "./Mixins/Pausable.sol";

contract Wallet is Pausable {

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
      uint lastWithdrawalAt;
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
      lastWithdrawalAt: 0
    });
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
    payees[_payee].lastWithdrawalAt = 0;
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
    require(
      payeeCanWithdraw(msg.sender,_value),
      "Payee can not withdraw"
    );

    address(msg.sender).transfer(_value);
    payees[msg.sender].lastWithdrawalAt = now;
  }

  function payeeCanWithdraw(
    address _payee,
    uint _value
  )
    public view
    returns(bool)
  {
    if(payees[_payee].whitelisted == true) {
      return true;
    }

    uint withdrawTime = payees[_payee].lastWithdrawalAt + 1 days;

    if(now >= withdrawTime && _value <= dailyLimit) {
      return true;
    }
    return false;
  }

  function ownerWithdraws(uint _value)
    external
    onlyOwner
    enoughBalance(_value)
  {
    address(msg.sender).transfer(_value);
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
