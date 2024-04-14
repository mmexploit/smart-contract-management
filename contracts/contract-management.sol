// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12 <0.9.0;

import "./contracts.sol";

contract ContractManagment is Contracts {
    constructor() Contracts(msg.sender) {}

    enum VoteType {
        voteFor,
        voteAgainst
    }

    event UserAssigned(uint256 id, address participantAdd, uint256[] ids);
    event newContractCreated(string name, uint256 contractId);
    event contractorSealed(address userAddress);
    event contractorClosed(address userAddress);
    event contractorRegistered(address userAddress, uint256 contractId);
    event contractorAdded(address userAddress, uint256 contractId);
    event contractExecuted(address userAddress, uint256 contractId);

    function createContract(
        string memory _name,
        address _userAddress,
        address[] memory participants,
        string memory _organizationId,
        ContractType _contractType,
        uint256 amount
    ) external returns (uint256) {
        require(
            participants.length % 2 != 0,
            "An even number of particpants is not allowed."
        );

        uint256 _id = uint256(
            keccak256(abi.encodePacked(block.timestamp, msg.sender))
        );

        Contract storage newContract = ContractMgt[_id];
        newContract.name = _name;
        newContract._contractId = _id;
        newContract.contractState = ContractState.Created;
        newContract.payableUserAddress = payable(_userAddress);
        newContract.payeeAddress = payable(msg.sender);
        newContract.contractType = _contractType;
        newContract.numberOfParticipants = uint32(participants.length);
        newContract.amount = amount;

        for (uint256 i = 0; i < uint256(participants.length); i++) {
            ContractingParties[participants[i]].push(_id);
            emit UserAssigned(
                _id,
                participants[i],
                ContractingParties[participants[i]]
            );
        }

        OrgContracts[_organizationId].push(_id);

        emit newContractCreated(_name, _id);
        return _id;
    }

    function sealContract(uint256 _contractId) external returns (bool) {
        require(
            ContractMgt[_contractId].contractState == ContractState.Created,
            "Contract can not be sealed"
        );
        require(
            ContractMgt[_contractId].hasPaidToContractAdmin,
            "Contract has not paid. It can not be sealed"
        );

        ContractMgt[_contractId].contractState = ContractState.Sealed;

        return true;
    }

    function getMyOrgContracts(string memory _orgId)
        external
        view
        returns (Contract[] memory)
    {
        uint256[] memory contractIds = OrgContracts[_orgId];

        Contract[] memory contracts = new Contract[](contractIds.length);

        for (uint256 i = 0; i < contractIds.length; i++) {
            contracts[i] = ContractMgt[contractIds[i]];
        }

        return contracts;
    }

    function getMyAssignedContracts()
        external
        view
        returns (Contract[] memory)
    {
        uint256[] memory contractIds = ContractingParties[msg.sender];

        Contract[] memory contracts = new Contract[](contractIds.length);

        for (uint256 i = 0; i < contractIds.length; i++) {
            contracts[i] = ContractMgt[contractIds[i]];
        }

        return contracts;
    }

    function getContract(uint256 _contractId)
        external
        view
        returns (Contract memory)
    {
        return ContractMgt[_contractId];
    }

    function castVote(uint256 _contractId, VoteType _voteType)
        external
        returns (bool)
    {
        Contract storage contractItem = ContractMgt[_contractId];
        require(
            contractItem.contractState == ContractState.Sealed,
            "Voting on this contract is not allowed."
        );
        if (_voteType == VoteType.voteFor) {
            contractItem.forVotes.push(msg.sender);
            executeContract(_contractId);
        } else if (_voteType == VoteType.voteAgainst) {
            contractItem.againstVotes.push(msg.sender);
            executeContract(_contractId);
        }

        return true;
    }

    function executeContract(uint256 _contractId) internal returns (bool) {
        if (ContractMgt[_contractId].contractType == ContractType.Majority) {
            executeMajorityContract(_contractId);
            emit contractExecuted(msg.sender, _contractId);
            return true;
        }

        return false;
    }

    function hasVoted(uint256 _contractId)
        public
        view
        returns (bool)
    {
        Contract memory contractItem = ContractMgt[_contractId];
        for (uint256 i = 0; i < contractItem.numberOfParticipants; i++) {
            if (
                (contractItem.forVotes[i] == msg.sender) ||
                (contractItem.againstVotes[i] == msg.sender)
            ) {
                return true;
            }
        }
        return false;
    }

    function executeMajorityContract(uint256 _contractId)
        internal
        returns (bool)
    {
        Contract memory _contractItem = ContractMgt[_contractId];

        if (
            _contractItem.forVotes.length >
            _contractItem.numberOfParticipants / 2
        ) {
            makePayment(_contractItem.payableUserAddress, _contractItem.amount);
        } else if (
            _contractItem.againstVotes.length >
            _contractItem.numberOfParticipants / 2
        ) {
            makePayment(_contractItem.payeeAddress, _contractItem.amount);
        } else {
            return false;
        }
        _contractItem.contractState = ContractState.Executed;

        ContractMgt[_contractId] = _contractItem;
        return true;
    }

    function makePayment(address _to, uint256 _amount) public payable {
        require(_to != address(0), "Invalid recipient address");
        require(_amount > 0, "Amount must be greater than zero");

        (bool success, ) = _to.call{value: _amount}("");
        require(success, "Transfer failed");
    }
}
