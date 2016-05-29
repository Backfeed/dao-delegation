/*
	This is just a proof-of-concept 
	The contract compiles, but has never been deployed, let alone been tested properly
	Use it at your own risk
*/


/*
	The VoteDelegator Contract provides simple way of delegating your votes in theDAO

	It is meant as a quick way of adding delegation to the DAO
	without having to change theDAO contract in any way
	
	It works like this. ("theDAO" refers to the DAO contact on the blockchain, and
	theDelegator to a Delegator Instance on the blockchain)
	
	  1) Tell the TheDAO that VoteDelegator is allowed to handle your DAO tokens 

		 	theDAO.approve(address(theDelegator), amount_of_tokens)
	
      2) put your DAO tokens in control of theDelegator:

            theDelegator.delegate(amount_of_tokens)

	  3) Now you can vote by simply calling the "vote" function on the 
		 delegator contract (exactly as you would vote on the DAO)

			 theDelegator.vote(_proposalID, _supportsProposal)

         the Delegator contract will then register your vote, but only copy this vote
		 to the DAO itself if certain conditions are met (in this contract, a simple majority count)

	  4) If you want to remove your delegation and have your DAO tokens back, call:

		 	theDelegator.undelegate()

		Unfortunately, this function will only work when the Delegator tokens are not
		locked into a vote. If the delegated tokens are locked, then your share of the tokens 
		will be freed as soon as the voting period is over.
		You will have to call "undelegate" again to transfer them back to you.
*/

import "./theDAO/Token.sol";
import "./theDAO/DAO.sol";

contract VoteDelegatorInterface {
	// the address of TheDAO
    address thedao_address;

    // proposals that have been voted on
    Proposal[] proposals;
    //  maps daoProposalIDs to indices in proposals for easier administration 
    mapping (uint => uint) proposal_idx;
    
    struct Proposal {
    	// the proposalID in the DAO
    	uint dao_proposalID;
        // True if the proposal's vote has been cast in the DAO
        bool closed;
        // Number of Tokens in favor of the proposal
        uint yea;
        // Number of Tokens opposed to the proposal
        uint nay;
        // Simple mapping to check if a shareholder has voted for it
        mapping (address => bool) votedYes;
        // Simple mapping to check if a shareholder has voted against it
        mapping (address => bool) votedNo;
    }

    // Used to restrict access to certain functions to only Token Holders
    modifier onlyTokenholders {}	

    /// Total amount of tokens delegated
    uint256 totalDelegatedTokens;

    /// @notice Delegate _amount of tokens to this contract
    /// 	transfer the DAO tokens (in the DAO) in to msg.sender
    /// 	a corresponding amount of DelegatorTokens will be created 
    function delegate(
    	uint256 _value
    ) returns (bool success);

    /// @notice Transferthe DAO tokens (in the DAO) back to msg.sender
    /// 	burn the corresponding DelegatorTokens
    function undelegate() returns (bool success);

    /// @notice Vote on proposal `_proposalID` with `_supportsProposal`
    /// @param _proposalID The proposal ID
    /// @param _supportsProposal Yes/No - support of the proposal
    /// @return The vote ID.
    function castvote(
        uint _proposalID,
        bool _supportsProposal
    ) onlyTokenholders returns (uint _voteID);

}


contract VoteDelegator is Token, VoteDelegatorInterface {

	function VoteDelegator(address _thedao_address) {
		// constructor function
		thedao_address = _thedao_address;
	}	

	function delegate(uint256 _value) returns (bool success) {
		DAO thedao = DAO(thedao_address);
		// try to transfer _value amount of DAO tokens to the present contract
		if (balances[msg.sender] > 0) {
			// for reasons of simplicity, a user can only delegate his tokens 
			// once to this delegator
			throw;
		}

		if (thedao.allowance(msg.sender, address(this)) < _value) {
			// 'Please call approve(address(this), _value) on the DAO contract'
			throw;
		}
		if(thedao.transferFrom(msg.sender, address(this), _value)){
			// create a corresponding amount of VoteTokens
			balances[msg.sender] = _value;
			totalDelegatedTokens += _value;
		} else {
			// if transfer fails, do nothing
			throw;
		}
	}

	function undelegate() returns (bool success) {
		DAO thedao = DAO(thedao_address);
		// try to transfer _value amount of DAO tokens from the present contract
		// back to msg.sender 
		uint amount_to_transfer = balances[msg.sender];

		// then pay the msg.sender from there
		if(thedao.transfer(msg.sender, amount_to_transfer)){
			// we update all talleys of open proposals where this user has voted
			for (uint i=0;i<proposals.length;i++) {
				Proposal p = proposals[i];
				if (!p.closed) {
					if (p.votedYes[msg.sender]) {
						p.yea -= balances[msg.sender];
					}
					if (p.votedNo[msg.sender]) {
						p.nay -= balances[msg.sender];
					}
				}
			}
			// remove all vote tokens
			balances[msg.sender] = 0;
		} else {
			// if transfer fails, this is probably becauase your tokens are locked up
			// TODO: FIXME: if this contract votes often, your tokens may be locked up 
			// for a long time. 
			throw;
		}
	}


	function vote(uint _proposalID, bool _supportsProposal)  returns (uint _voteID) {
		// check if we have already transfered the DAO tokens to the contract address
		if (balances[msg.sender] == 0) {
			throw;
		}

		// get (or create) the Proposal
		Proposal proposal;
		if (proposal_idx[_proposalID] == 0) {
			proposal_idx[_proposalID] = proposals.length + 1;	
        	proposal = proposals[proposal_idx[_proposalID]];
        	proposal.dao_proposalID = _proposalID;
		} else {
        	proposal = proposals[proposal_idx[_proposalID]];
        }

        // if the proposal is closed, don't bother
        if (proposal.closed) {
        	throw;
        }
		// if the user already voted, don't let her vote again
		if (proposal.votedYes[msg.sender] || proposal.votedNo[msg.sender]) {
			throw;
		}
		if (_supportsProposal) {
			proposal.yea += balances[msg.sender];
			proposal.votedYes[msg.sender] = true;
		} else {
			proposal.nay += balances[msg.sender];
			proposal.votedNo[msg.sender] = true;

		}
		// for demonstration purposes, we implement a simple majority rule
		// if more than half of the tokens votes yea (or nay), we copy
		// that vote to the DAO for *all* tokens
		DAO thedao = DAO(thedao_address);
		if (2 * proposal.yea >= totalSupply) {
			thedao.vote(_proposalID, true);
			proposal.closed = true;
		}
		if (2 * proposal.nay >= totalSupply) {
			thedao.vote(_proposalID, false);
			proposal.closed = true;
		}
	}
}


contract DAOUnlockedTokenStorage {
	/* a contract to handle the set tokens of a VoteDelegator contract
	that are not to be locked in a (next) vote
	*/

	address creator;
	address thedao_address;

    modifier noEther() {if (msg.value > 0) throw; _}

	function DAOUnlockedTokenStorage() {
		// constructor function 
		creator = msg.sender;
	}

	function transfer(address _to, uint256 _amount) noEther returns (bool success) {
		if (msg.sender != creator) {
			throw;
		}
		DAO thedao = DAO(thedao_address);
		thedao.transfer(_to, _amount);
	}
   
}