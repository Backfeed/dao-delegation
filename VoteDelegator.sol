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
    //  maps daoProposalIDs to indices in proposals 
    mapping (uint => uint) proposal_idx;

    // maps user addresses to tokenaccounts managed by this contract
    address[] accounts;
    // map delegator addresses to account indexes
    mapping (address => uint) accounts_idx;
    
    struct Proposal {
    	// the proposalID in the DAO
    	uint proposalID;
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

	function getAccount(address _delegator) returns (DelegatedTokenAccount) {
		// get a DelegatedTokenAccount for this user
		DelegatedTokenAccount  account;
		address account_address = accounts[accounts_idx[msg.sender]];

		if (account_address == 0) {
			account = new DelegatedTokenAccount(thedao_address, _delegator);
			accounts[accounts_idx[_delegator]] = address(account);
		} else {
			account = DelegatedTokenAccount(account_address);
		}
		return account;
	}

	function delegate(uint256 _value) returns (bool success) {

		DAO thedao = DAO(thedao_address);
		if (balances[msg.sender] > 0) {
			// for reasons of mental sanity, a user can only delegate his tokens 
			// once to this delegator. (This can be fixed with some more bookkeeping)
			throw;
		}

		if (thedao.allowance(msg.sender, address(this)) < _value) {
			// Please call approve(address(this), _value) on the DAO contract
			throw;
		}

		// get the account of the sender
		DelegatedTokenAccount account = getAccount(msg.sender);

		// transfer _value tokens to the senders Delegatedaccount
		if(thedao.transferFrom(msg.sender, address(account), _value)){
			// create a corresponding amount of VoteTokens
			balances[msg.sender] += _value;
			totalDelegatedTokens += _value;
		} else {
			// if transfer fails, do nothing
			throw;
		}
	}

	function undelegate() returns (bool success) {
		// get the account
		DelegatedTokenAccount account = getAccount(msg.sender);

		// close the account - it will not participate in any new votes
		// TODO:
		// account.active = false;

		// update all talleys of open proposals where this user has voted
		// this is not needed, because if the funds are free
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

		// now ty to get the tokens back to msg.sender
		account.returnTokens();

		// remove all vote tokens
		balances[msg.sender] = 0;
	}

	function vote(uint _proposalID, bool _supportsProposal) {

		if (balances[msg.sender] == 0) {
			throw;
		}
		Proposal proposal;
		// get (or create) the Proposal
		if (proposal_idx[_proposalID] == 0) {
			// we have a new proposal
			proposal_idx[_proposalID] = proposals.length + 1;	
        	proposal = proposals[proposal_idx[_proposalID]];
        	proposal.proposalID = _proposalID;
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
		copyVote(proposal);
	}
    function vote_in_thedao(
        uint _proposalID,
        bool _supportsProposal
    ) {
		for (uint i=0;i<accounts.length;i++) {
			address account_adress = accounts[i];
			DelegatedTokenAccount(account_adress).vote(_proposalID, _supportsProposal);
		}
	}


	function copyVote(Proposal proposal) private returns (uint voteID) {
		// Actually vote for the DAO
		// this is where the magic of the contract is supposed to happen
		// we can insert here any logic that seems reasonable:
		// 		- majority votes
		//		- follow the leader votes
		//		- an implementation of the Backfeed Protocol
		// for demonstration purposes, we implement a simple majority rule
		// if more than half of the tokens votes yea (or nay), we copy
		// that vote to the DAO for *all* tokens
		DAO thedao = DAO(thedao_address);
		if (2 * proposal.yea >= totalSupply) {
			vote_in_thedao(proposal.proposalID, true);
			proposal.closed = true;
		}
		if (2 * proposal.nay >= totalSupply) {
			vote_in_thedao(proposal.proposalID, false);
			proposal.closed = true;
		}
	}

}


contract DelegatedTokenAccount {
	/*	
		an account to manage tokens for a user

	*/
	address owner;
	address thedao_address;
	address delegator;
	// true if this account is used for voting
	bool public active;

	// The constructor sets the address of the dao and the delegator
    function DelegatedTokenAccount(
    	address _thedao_address,
    	address _delegator) {
		owner = msg.sender;
		thedao_address = _thedao_address;
		delegator = _delegator;
		active = true;
    }

	function returnTokens() {
		if (msg.sender != owner) {
			throw;
		}	
		DAO thedao = DAO(thedao_address);
		uint balance = thedao.balanceOf(address(this));
		thedao.transfer(delegator, balance);
	}

	function vote(
        uint _proposalID,
        bool _supportsProposal
    ) returns (uint _voteID) {
    	if (msg.sender != owner) {
    		throw;	
    	}
		DAO thedao = DAO(thedao_address);
		return thedao.vote(_proposalID, _supportsProposal);
	}
}