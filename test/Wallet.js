const chaiAsPromised = require("chai-as-promised");
const chai = require("chai");
const txHelper = require('./helpers/transactions');
const getTxData = txHelper.getTxData;
const getAbiByFunctionNames = txHelper.getAbiByFunctionNames;

chai.use(chaiAsPromised);
const expect = chai.expect;

const WalletArtifacts = artifacts.require("Wallet");

contract('MultiSigWallet', (ACCOUNTS) => {

  const WALLET_OWNER = ACCOUNTS[0];
  const PAYEE_BLACK = ACCOUNTS[1]; //Blacklisted
  const PAYEE_WHITE = ACCOUNTS[2]; //Whitelisted
  const PAYEE_3 = ACCOUNTS[3];
  const PAYEE_4 = ACCOUNTS[4];
  const NOT_OWNER = ACCOUNTS[5];

  const DAILY_LIMIT = 1000000000000000000; //1 ETH
  const NEW_DAILY_LIMIT = 2000000000000000000; //2 ETH
  const DEPOSIT = NEW_DAILY_LIMIT * 10; //20 ETH

  const ONE_DAY = 24 * 60 * 60 * 1000;

  let Wallet;
  let timeTravel;

  before("Contracts instances", async () => {
    Wallet = await WalletArtifacts.deployed();

    timeTravel = function(time) {
      return new Promise((resolve, reject) => {
          web3.currentProvider.send({
          jsonrpc: "2.0",
          method: "evm_increaseTime",
          params: [time],
          id: new Date().getSeconds()
        }, (err, result) => {
          if(err){ return reject(err) }
          return resolve(result)
        });
      });
    };
  });

  describe("Deployment", () => {
    it("should initialize the payees", async () => {
      const payee1 = await Wallet.payees(PAYEE_BLACK);
      const payee2 = await Wallet.payees(PAYEE_WHITE);

      assert.deepEqual(
        {
          allowed: true,
          whitelisted: false,
          firstDailyWithdrawalTime: web3.utils.toBN(0)
        },
        {
          allowed: payee1.allowed,
          whitelisted: payee1.whitelisted,
          firstDailyWithdrawalTime: payee1.firstDailyWithdrawalTime
        },
        "Payee1 was not stored properly"
      );

      assert.deepEqual(
        {
          allowed: true,
          whitelisted: true,
          firstDailyWithdrawalTime: web3.utils.toBN(0)
        },
        {
          allowed: payee2.allowed,
          whitelisted: payee2.whitelisted,
          firstDailyWithdrawalTime: payee2.firstDailyWithdrawalTime
        },
        "Payee2 was not stored properly"
      );
    });

    it("should initialize the daily limit", async () => {
      const dailyLimit = await Wallet.dailyLimit();

      assert.deepEqual(
        web3.utils.toBN(DAILY_LIMIT),
        dailyLimit,
        "Daily limit was not initialized properly"
      );
    });
  });

  describe("Owner", () => {
    describe("#addPayees", () => {
      it("should store the payees", async () => {
        await Wallet.addPayees(
          [PAYEE_3, PAYEE_4],
          [true, false],
          {from: WALLET_OWNER}
        );

        const payee3 = await Wallet.payees(PAYEE_3);
        const payee4 = await Wallet.payees(PAYEE_4);

        assert.deepEqual(
          {allowed: true, whitelisted: true, firstDailyWithdrawalTime: web3.utils.toBN(0)},
          {
            allowed: payee3.allowed,
            whitelisted: payee3.whitelisted,
            firstDailyWithdrawalTime: payee3.firstDailyWithdrawalTime
          },
          "Payee3 was not stored properly"
        );

        assert.deepEqual(
          {allowed: true, whitelisted: false, firstDailyWithdrawalTime: web3.utils.toBN(0)},
          {
            allowed: payee4.allowed,
            whitelisted: payee4.whitelisted,
            firstDailyWithdrawalTime: payee4.firstDailyWithdrawalTime
          },
          "Payee4 was not stored properly"
        );
      });

      it("should revert if not Owner", async () => {
        await expect(
          Wallet.addPayees(
            [NOT_OWNER],
            [true],
            {from: NOT_OWNER}
          )
        ).to.eventually.be.rejectedWith("revert");
      });
    });
    describe("#addPayee", () => {
      it("should revert adding an existing payee", async () => {
        await expect(
          Wallet.addPayee(PAYEE_4, {from: WALLET_OWNER})
        ).to.eventually.be.rejectedWith("revert");
      });
    });
    describe("#whitelistPayee", () => {
      it("should whitelist a payee", async () => {
        await Wallet.whitelistPayee(PAYEE_4, {from: WALLET_OWNER});
        const whitelisted = await Wallet.isWhitelisted(PAYEE_4);

        assert.equal(true, whitelisted, "Payee was not whitelisted properly");
      });

      it("should revert whitelisting a whitelisted payee", async () => {
        await expect(
          Wallet.whitelistPayee(PAYEE_4, {from: WALLET_OWNER})
        ).to.eventually.be.rejectedWith("revert");
      });

      it("should revert if not Owner", async () => {
        await expect(
          Wallet.whitelistPayee(PAYEE_BLACK, {from: NOT_OWNER})
        ).to.eventually.be.rejectedWith("revert");
      });
    });

    describe("#blacklistPayee", () => {
      it("should blacklist a payee", async () => {
        await Wallet.blacklistPayee(PAYEE_4, {from: WALLET_OWNER});
        const blacklisted = await Wallet.isWhitelisted(PAYEE_4);

        assert.equal(false, blacklisted, "Payee was not balcklisted properly");
      });

      it("should revert blacklisting a blacklisted payee", async () => {
        await expect(
          Wallet.blacklistPayee(PAYEE_4, {from: WALLET_OWNER})
        ).to.eventually.be.rejectedWith("revert");
      });

      it("should revert if not Owner", async () => {
        await expect(
          Wallet.blacklistPayee(PAYEE_WHITE, {from: NOT_OWNER})
        ).to.eventually.be.rejectedWith("revert");
      });
    });

    describe("#removePayee", () => {
      it("should remove a payee", async () => {
        await Wallet.removePayee(PAYEE_4, {from: WALLET_OWNER});
        const payee4 = await Wallet.payees(PAYEE_4);

        assert.deepEqual(
          {allowed: false, whitelisted: false, firstDailyWithdrawalTime: web3.utils.toBN(0)},
          {
            allowed: payee4.allowed,
            whitelisted: payee4.whitelisted,
            firstDailyWithdrawalTime: payee4.firstDailyWithdrawalTime
          },
          "Payee4 was not removed properly"
        );
      });

      it("should revert removing nonexistent payee", async () => {
        await expect(
          Wallet.removePayee(PAYEE_4, {from: WALLET_OWNER})
        ).to.eventually.be.rejectedWith("revert");
      });

      it("should revert if not Owner", async () => {
        await expect(
          Wallet.removePayee(PAYEE_BLACK, {from: NOT_OWNER})
        ).to.eventually.be.rejectedWith("revert");
      });
    });

    describe("#setDailyLimit", () => {
      it("should set a new daily limit", async () => {
        await Wallet.setDailyLimit(
          web3.utils.toBN(NEW_DAILY_LIMIT), {from: WALLET_OWNER}
        );

        const newDailyLimit = await Wallet.dailyLimit();

        assert.deepEqual(
          web3.utils.toBN(NEW_DAILY_LIMIT),
          newDailyLimit,
          "Daily limit was not set properly"
        );
      });

      it("should revert setting same daily limit", async () => {
        await expect(
          Wallet.setDailyLimit(
            web3.utils.toBN(NEW_DAILY_LIMIT), {from: WALLET_OWNER}
          )
        ).to.eventually.be.rejectedWith("revert");
      });

      it("should revert if not Owner", async () => {
        await expect(
          Wallet.setDailyLimit(
            web3.utils.toBN(DAILY_LIMIT), {from: NOT_OWNER}
          )
        ).to.eventually.be.rejectedWith("revert");
      });
    });

    describe("#deposit (fallback)", () => {
      it("should deposit ETH in the wallet", async () => {
        await web3.eth.sendTransaction({
          from: WALLET_OWNER,
          to: Wallet.address,
          value: web3.utils.toBN(DEPOSIT)
        });

        const walletBalance = await web3.eth.getBalance(Wallet.address);

        assert.equal(
          DEPOSIT,
          walletBalance,
          "ETH was not deposited properly"
        );
      });
    });
  });

  describe("Payee - Whitelisted", () => {
    describe("#payeeWithdraws", () => {
      it("should withdraw more than daily limit from wallet", async () => {
        const  initialWalletBalance = await web3.eth.getBalance(Wallet.address);

        await Wallet.payeeWithdraws(
          web3.utils.toBN(NEW_DAILY_LIMIT * 2),
          {from: PAYEE_WHITE}
        );

        const finalWalletBalance = await web3.eth.getBalance(Wallet.address);

        assert.deepEqual(
          initialWalletBalance - finalWalletBalance,
          NEW_DAILY_LIMIT * 2,
          "Whitelisted payee did not withdraw ETH properly"
        );
      });
    });
  });

  describe("Payee - Blacklisted", () => {
    describe("#payeeWithdraws", () => {
      it("should withdraw daily limit from wallet", async () => {
        const initialWalletBalance = await web3.eth.getBalance(Wallet.address);

        await Wallet.payeeWithdraws(
          web3.utils.toBN(NEW_DAILY_LIMIT / 2),
          {from: PAYEE_BLACK}
        );

        await Wallet.payeeWithdraws(
          web3.utils.toBN(NEW_DAILY_LIMIT / 2),
          {from: PAYEE_BLACK}
        );

        const finalWalletBalance = await web3.eth.getBalance(Wallet.address);

        assert.deepEqual(
          initialWalletBalance - finalWalletBalance,
          NEW_DAILY_LIMIT,
          "Whitelisted payee did not withdraw ETH properly"
        );
      });

      it("should revert exceding daily limit", async () => {
        expect(
          Wallet.payeeWithdraws(
            web3.utils.toBN(NEW_DAILY_LIMIT + 1),
            {from: PAYEE_BLACK}
          )
        ).to.eventually.be.rejectedWith("revert")
      });

      it("should withdraw after one day has passed", async () => {
        timeTravel((Date.now() + ONE_DAY)/1000);

        await Wallet.payeeWithdraws(
          web3.utils.toBN(NEW_DAILY_LIMIT / 2),
          {from: PAYEE_BLACK}
        );

        await Wallet.payeeWithdraws(
          web3.utils.toBN(NEW_DAILY_LIMIT / 2),
          {from: PAYEE_BLACK}
        );
      });

      it("should revert exceding daily limit", async () => {
        expect(
          Wallet.payeeWithdraws(
            web3.utils.toBN(NEW_DAILY_LIMIT + 1),
            {from: PAYEE_BLACK}
          )
        ).to.eventually.be.rejectedWith("revert")
      });
    });
  });
});
