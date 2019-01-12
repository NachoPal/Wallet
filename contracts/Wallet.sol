pragma solidity 0.4.24;
pragma experimental ABIEncoderV2;

import "./Mixins/Pausable.sol";

contract Wallet is Pausable {
  modifier isPayee(_address) {
    require(
      payees[_address].allowed == true,
      "Address is not a Payee"
    );
    _;
  }

  struct Payee {
      bool allowed;
      bool whitelisted;
  }

  mapping (address => Payee) payees;
  mapping (address => uint) tokens;

  constructor(
    address[] _payees,
    bool[] _whitelisted,
    address[] _tokens,
    uint[] _dayliLimit
  )
    public
    payable
  {
    addPayees(_payees, _whitelisted);
    addERC20tokens(_tokens, _dayliLimit);
    owner = msg.sender;
  }

  function addPayees(
    address[] _payees,
    bool[] _whitelisted,
  )
    public
    onlyOwner
  {
    require(
      _payees.length == _whitelisted.length,
      "Payees and Whitelisted arrays do not have same length"
    );

    for(uint i = 0; i < _payees.length; i++) {
      Payee memory payee = new Payee({
            allowed: true,
            whitelisted: _whitelisted[i];
      });

      payees[_payees[i]] = payee;
    }
  }

  function addPayee(
    address _payee,
    bool _whitelisted
  )
    public
    onlyOwner
    isNotPayee
  {
    payees[_payee] = new Payee({allowed: true, whitelisted: _whitelisted});
  }

  function removePayee(
    address _payee,
    bool _whitelisted
  )
    public
    onlyOwner
    isPayee(_payee)
  {
    payees[_payee].allowed = false;
    payees[_payee].whitelisted = false;
  }

  function addERC20tokens(
    address[] _tokens,
    uint[] _dayliLimit
  )
    public
    onlyOwner
  {
    require(
      _tokens.length == _dayliLimit.length,
      "Tokens and DayliLimit arrays do not have same length"
    );

    for(uint i = 0; i < _tokens.length; i++) {
      tokens[_tokens[i]] = _dayliLimit[i];
    }
  }

  function addERC20token(
    address _token,
    uint _dayliLimit
  )
    public
    onlyOwner
  {
    tokens[_token] = _dayliLimit;
  }

  function removeERC20token(
    address _token,
  )
    public
    onlyOwner
  {
    tokens[_token] = 0;
  }


//VER COMO CONTROLO SI ES PAYYE O NO, sicon modifer, llamada a function o duplicidade de requieres
