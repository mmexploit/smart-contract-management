// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Contracts is Ownable {
    address public ownerAddress;
    address payable public paymentAddress;
    uint256 totalAmount = 0;

    constructor(address userAddress) Ownable(userAddress) {
        ownerAddress = userAddress;
        paymentAddress = payable(userAddress);
    }

    event Received(address indexed sender, uint256 amount);

    enum ContractState {
        Created,
        Sealed,
        Canceled,
        Executed
    }
    enum ContractType {
        Consensus,
        Majority
    }

    struct Contract {
        string name;
        uint256 _contractId;
        ContractState contractState;
        ContractType contractType;
        uint32 numberOfParticipants;
        uint256 amount;
        address payableUserAddress;
        address payeeAddress;
        address[] forVotes;
        address[] againstVotes;
        bool hasPaidToContractAdmin;
    }

    mapping(uint256 => Contract) ContractMgt;
    mapping(string => uint256[]) OrgContracts;
    mapping(address => uint256[]) ContractingParties;

    function getTotalAmount() external view onlyOwner returns (uint256) {
        return totalAmount;
    }

    receive() external payable {
        totalAmount += msg.value;
        emit Received(ownerAddress, msg.value);
    }

    function payToContractAdmin(uint256 _contractId) external payable {
        Contract memory currentContract = ContractMgt[_contractId];

        // Ensure that the contract address is payable
        address payable contractAddress = payable(address(this));

        // Transfer the funds to the contract address
        require(msg.value == (currentContract.amount), "Incorrect amount sent");

        // Call the updateContractStatus function
        (bool success, ) = contractAddress.call(
            abi.encodeWithSignature(
                "updateContractStatus(uint256)",
                _contractId
            )
        );

        require(success, "Payment is not completed");
    }

    function updateContractStatus(uint256 _contractId)
        public
        payable
        returns (bool)
    {
        ContractMgt[_contractId].hasPaidToContractAdmin = true;
        return true;
    }
}
