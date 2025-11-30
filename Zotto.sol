// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Zottery is IERC20, Ownable, VRFConsumerBaseV2 {
    using SafeMath for uint256;

    // ERC20 mappings
    mapping(address => uint) public balances;
    mapping(address => mapping(address => uint)) public _allowance;

    // Token details
    uint public _decimals = 18;
    uint public _totalSupply = 10_000_000_000 * 10 ** 18;
    string public _symbol = "ZLOT";
    string public _name = "ZK LOTTERY";

    // Special wallets
    address jackpotWallet = address(this);
    address lpWallet = address(this);
    address stakersWallet = address(this);
    address questWallet = 0xE0bF232273Bc010662288DC8dE3f1119C79D4136;
    address marketingWallet = 0xE0bF232273Bc010662288DC8dE3f1119C79D4136;

    // Pool contract
    address poolContract;

    // Lottery variables
    uint minimumLotterySize = 100;
    uint lotteryEnd;
    uint lotteryCooldown = 15 minutes;
    uint lotteryAmount;

    address[] lotteryAddress;
    uint lastIndex = 0;
    mapping(address => uint) public lottery;
    mapping(address => uint) public lotteryIndex;

    // Burn variables
    uint burnedAmount;
    address[] burnersAddress;
    uint lastBurnIndex = 0;
    mapping(address => uint) public burned;

    // Events
    event Burn(address from, uint amount);
    event Jackpot(address winner, uint amountWon, uint winnersTicketSize, uint totalLotteryParticipation);

    // --- ERC20 standard functions ---
    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function decimals() external view returns (uint) {
        return _decimals;
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return balances[account];
    }

    function allowance(address account, address spender) external view override returns (uint256) {
        return _allowance[account][spender];
    }

    function approve(address spender, uint amount) external override returns (bool) {
        require(spender != address(0), "ERC20: spender is the zero address");
        require(amount > 0, "Amount must be greater than zero");

        _allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function increaseAllowance(address spender, uint amount) public returns (bool) {
        require(spender != address(0), "ERC20: spender is the zero address");
        require(amount > 0, "Amount must be greater than zero");

        _allowance[msg.sender][spender] = _allowance[msg.sender][spender].add(amount);
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function withdraw() external onlyOwner {
        require(address(this).balance > 0, "Nothing to withdraw");
        payable(owner()).transfer(address(this).balance);
    }

    // --- Wallet getters and setters ---
    function getJackpotWallet() external view returns (address) {
        return jackpotWallet;
    }

    function getLpWallet() external view returns (address) {
        return lpWallet;
    }

    function getStakersWallet() external view returns (address) {
        return stakersWallet;
    }

    function getQuestWallet() external view returns (address) {
        return questWallet;
    }

    function getMarketingWallet() external view returns (address) {
        return marketingWallet;
    }

    function getMinimumLotterySize() external view returns (uint) {
        return minimumLotterySize;
    }

    function getLotteryEnd() external view returns (uint) {
        return lotteryEnd;
    }

    function getTotalLotteryParticipation() external view returns (uint) {
        return lotteryAmount;
    }

    function getUsersLotterySize(address wallet) external view returns (uint) {
        return lottery[wallet];
    }

    function getLotteryRewardSize() external view returns (uint) {
        return balances[jackpotWallet];
    }

    function getTotalBurnParticipation() external view returns (uint) {
        return burnedAmount;
    }

    function getUsersBurnSize(address wallet) external view returns (uint) {
        return burned[wallet];
    }

    function setLpWallet(address wallet) external onlyOwner returns (bool) {
        lpWallet = wallet;
        return true;
    }

    function setStakersWallet(address wallet) external onlyOwner returns (bool) {
        stakersWallet = wallet;
        return true;
    }

    function setQuestWallet(address wallet) external onlyOwner returns (bool) {
        questWallet = wallet;
        return true;
    }

    function setMarketingWallet(address wallet) external onlyOwner returns (bool) {
        marketingWallet = wallet;
        return true;
    }

    function getPoolContract() external view returns (address) {
        return poolContract;
    }

    function setPoolContract(address wallet) external onlyOwner returns (bool) {
        poolContract = wallet;
        return true;
    }

    // --- Transfers ---
    function transfer(address recipient, uint amount) external override returns (bool) {
        require(amount > 0, "Transfer amount must be greater than zero");
        require(balances[msg.sender] >= amount, "Balance too low");

        return doTransfer(msg.sender, recipient, amount);
    }

    function transferFrom(address from, address to, uint amount) external override returns (bool) {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(balances[from] >= amount, "Balance too low");
        require(_allowance[from][msg.sender] >= amount, "Allowance too low");

        _allowance[from][msg.sender] = _allowance[from][msg.sender].sub(amount);
        return doTransfer(from, to, amount);
    }

    // --- Internal Transfer Handler ---
    function doTransfer(address from, address to, uint amount) internal returns (bool) {
        uint afterTax;

        if (to == address(0)) {
            if (s_requestId == 0) {
                afterTax = burnIncrease(from, amount);
            } else if (s_randomWords != 0) {
                jackpotWinner(s_randomWords % (lotteryAmount.add(burnedAmount)));
                afterTax = burnIncrease(from, amount);
            } else {
                if (
                    from == lpWallet || from == stakersWallet || from == questWallet ||
                    from == marketingWallet || from == jackpotWallet || from == owner()
                ) {
                    afterTax = amount;
                } else {
                    afterTax = deductTaxes(amount);
                    _totalSupply = _totalSupply.sub(afterTax);
                }
            }
        } else {
            if (s_requestId == 0) {
                afterTax = getTaxes(from, to, amount);
            } else if (s_randomWords != 0) {
                jackpotWinner(s_randomWords % (lotteryAmount.add(burnedAmount)));
                afterTax = getTaxes(from, to, amount);
            } else {
                if (
                    from == lpWallet || from == stakersWallet || from == questWallet ||
                    from == marketingWallet || from == jackpotWallet || from == owner() ||
                    to == lpWallet || to == stakersWallet || to == questWallet ||
                    to == marketingWallet || to == jackpotWallet || to == owner()
                ) {
                    afterTax = amount;
                } else {
                    afterTax = deductTaxes(amount);
                }
            }
        }

        balances[from] = balances[from].sub(amount);
        balances[to] = balances[to].add(afterTax);

        if (to != address(0)) emit Transfer(from, to, afterTax);
        return true;
    }

    // --- Burn functions ---
    function burn(uint amount) external returns (bool) {
        require(amount > 0, "Transfer amount must be greater than zero");
        require(balances[msg.sender] >= amount, "Balance too low");

        uint afterTax;

        if (s_requestId == 0) {
            afterTax = burnIncrease(msg.sender, amount);
        } else if (s_randomWords != 0) {
            jackpotWinner(s_randomWords % (lotteryAmount.add(burnedAmount)));
            afterTax = burnIncrease(msg.sender, amount);
        } else if (
            msg.sender == lpWallet || msg.sender == stakersWallet || msg.sender == questWallet ||
            msg.sender == marketingWallet || msg.sender == jackpotWallet || msg.sender == owner()
        ) {
            afterTax = amount;
            _totalSupply = _totalSupply.sub(amount);
        } else {
            afterTax = deductTaxes(amount);
            _totalSupply = _totalSupply.sub(afterTax);
        }

        balances[msg.sender] = balances[msg.sender].sub(amount);
        balances[address(0)] = balances[address(0)].add(afterTax);
        emit Burn(msg.sender, afterTax);
        return true;
    }

    function burnIncrease(address wallet, uint amount) internal returns (uint) {
        if (
            wallet != lpWallet && wallet != stakersWallet && wallet != questWallet &&
            wallet != marketingWallet && wallet != jackpotWallet && wallet != owner()
        ) {
            if (burned[wallet] == 0) {
                burnersAddress.push(wallet);
                ++lastBurnIndex;
            }
            burned[wallet] = burned[wallet].add(amount);
            amount = deductTaxes(amount);
            _totalSupply = _totalSupply.sub(amount);
            emit Burn(wallet, amount);
            return amount;
        }

        _totalSupply = _totalSupply.sub(amount);
        emit Burn(wallet, amount);
        return amount;
    }

    // --- Taxation ---
    function deductTaxes(uint amount) internal returns (uint) {
        uint taxes = amount.div(200); // 0.5%
        balances[jackpotWallet] = balances[jackpotWallet].add(taxes.mul(6)).add(amount % 200);
        balances[lpWallet] = balances[lpWallet].add(taxes);
        balances[stakersWallet] = balances[stakersWallet].add(taxes);
        balances[questWallet] = balances[questWallet].add(taxes);
        balances[marketingWallet] = balances[marketingWallet].add(taxes);

        return (taxes.mul(190)).add(amount % 200);
    }

    function getTaxes(address from, address to, uint amount) internal returns (uint) {
        uint check = checkSenderAndReciver(from, to);

        if (check == 0) return amount;
        else if (check == 1 && amount >= minimumLotterySize && s_requestId == 0)
            increaseLotterySize(to, amount);
        else if (lottery[from] != 0 && s_requestId == 0)
            decreaseLotterySize(from, amount);

        return deductTaxes(amount);
    }

    function checkSenderAndReciver(address from, address to) internal view returns (uint) {
        if (from == poolContract) return 1;
        if (
            from == lpWallet || from == stakersWallet || from == questWallet || from == marketingWallet ||
            from == jackpotWallet || from == owner() ||
            to == lpWallet || to == stakersWallet || to == questWallet || to == marketingWallet ||
            to == jackpotWallet || to == owner()
        ) return 0;
        return 2;
    }

    // --- Lottery management ---
    function increaseLotterySize(address wallet, uint amount) internal {
        if (block.timestamp > lotteryEnd) distributeJackpot();

        if (lottery[wallet] == 0) {
            lotteryIndex[wallet] = lastIndex;
            lotteryAddress.push(wallet);
            ++lastIndex;
        }

        lottery[wallet] = lottery[wallet].add(amount);
        lotteryAmount = lotteryAmount.add(amount);
    }

    function decreaseLotterySize(address wallet, uint amount) internal {
        if (block.timestamp > lotteryEnd) distributeJackpot();
        else if (lottery[wallet] > minimumLotterySize.add(amount)) {
            lotteryAmount = lotteryAmount.sub(amount);
            lottery[wallet] = lottery[wallet].sub(amount);
        } else {
            lotteryAmount = lotteryAmount.sub(lottery[wallet]);
            lottery[wallet] = 0;
            lotteryAddress[lotteryIndex[wallet]] = lotteryAddress[lastIndex - 1];
            lotteryIndex[lotteryAddress[lastIndex - 1]] = lotteryIndex[wallet];
            lotteryAddress.pop();
            --lastIndex;
        }
    }

    // --- Chainlink VRF ---
    address vrfCoordinator = 0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D;
    VRFCoordinatorV2Interface immutable COORDINATOR;
    uint64 immutable s_subscriptionId = 12173;
    bytes32 immutable s_keyHash = 0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15;

    uint32 constant CALLBACK_GAS_LIMIT = 100000;
    uint16 constant REQUEST_CONFIRMATIONS = 3;
    uint32 constant NUM_WORDS = 1;

    uint256 public s_requestId = 0;
    uint s_randomWords = 0;

    event ReturnedRandomness(uint256[] randomWords);

    constructor() VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        balances[msg.sender] = _totalSupply;
        lotteryEnd = block.timestamp + lotteryCooldown;
    }

    function requestRandomWords() internal {
        s_requestId = COORDINATOR.requestRandomWords(
            s_keyHash,
            s_subscriptionId,
            REQUEST_CONFIRMATIONS,
            CALLBACK_GAS_LIMIT,
            NUM_WORDS
        );
    }

    function fulfillRandomWords(uint256, uint256[] memory randomWords) internal override {
        s_randomWords = randomWords[0];
        emit ReturnedRandomness(randomWords);
    }

    function distributeJackpot() internal {
        requestRandomWords();
    }

    function jackpotWinner(uint random) internal {
        address winner;
        uint winnersTicketSize;
        uint amountWon = balances[jackpotWallet];
        uint totalLotteryParticipation = lotteryAmount.add(burnedAmount);
        uint count = 0;

        if (random <= burnedAmount) {
            for (uint i = 0; i < lastBurnIndex; ++i) {
                count = count.add(burned[burnersAddress[i]]);
                if (random < count) {
                    winner = burnersAddress[i];
                    winnersTicketSize = burned[winner];
                    break;
                }
            }
        } else {
            random = random.sub(burnedAmount);
            for (uint i = 0; i < lastIndex; ++i) {
                count = count.add(lottery[lotteryAddress[i]]);
                if (random < count) {
                    winner = lotteryAddress[i];
                    winnersTicketSize = lottery[winner];
                    break;
                }
            }
        }

        balances[jackpotWallet] = 0;
        balances[winner] = balances[winner].add(deductTaxes(amountWon));

        for (uint i = lastIndex; i > 0; --i) {
            lottery[lotteryAddress[i - 1]] = 0;
            lotteryAddress.pop();
        }

        lotteryAmount = 0;
        lotteryEnd = block.timestamp + lotteryCooldown;
        minimumLotterySize = (balances[poolContract].div(poolContract.balance)).div(10);
        s_requestId = 0;

        emit Jackpot(winner, amountWon, winnersTicketSize, totalLotteryParticipation);
    }

}
