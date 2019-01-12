var Wallet = artifacts.require("./Wallet.sol");

module.exports = function(deployer) {
  deployer.deploy(
    Wallet,
    [
      "0x16f1b1cb43c0744f85b52104f6a7c3cc60cd3c49",
      "0xf204b4b3b0a4656e8e818d6c051679162f426999"
    ],
    [false, true],
    100000000000000,
    {value: 100000000000000000}
  );
};
