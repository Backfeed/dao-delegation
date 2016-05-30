/*
	This is a proof-of-concept.

	The contract compiles, but:
		- it has never been deployed
		- it has not been tested properly
		- it has not been security-audited
		- it has not been optimised for gas usage
		- it needs events
	Use it at your own risk
*/


/*
	The VoteDelegator contract provides way of delegating your votes in theDAO

	It is meant as a quick way of adding delegation to the DAO
	without having to change theDAO contract itself
	
	It works as follows. 
	(Here, "theDAO" refers to the DAO contract on the blockchain, and
	"theDelegator" to a VoteDelegator contract on the blockchain)
	
 	1)  Tell the The DAO that VoteDelegator is allowed to handle your DAO tokens 

		 	theDAO.approve(address(theDelegator), amount_of_tokens)
	
    2)  put your DAO tokens in control of the VoteDelegator:

            theDelegator.delegate(amount_of_tokens)

	3)  Now you can vote by simply calling the "vote" function on the 
		delegator contract (exactly as you would vote in the DAO)

			 theDelegator.vote(_proposalID, _supportsProposal)

        the Delegator contract will then register your vote internally, 
        the Delegator will only vote in the DAO itself when certain
		conditions are met (in this contract, a simple majority count)

	4)  If you want to remove your delegation and have your DAO tokens back, call:

		 	theDelegator.undelegate()

	    This will make it so that the VoteDelegator will not use your tokens 
	    for new votes any more. Your tokens my still be locked in a current vote,
		so you'll have to wait until they are unlocked to call "undelegate" again
		to transfer them back to you.
*/

/*
	Some use cases are:
		- last-minute voting to keep you tokens locked up as little as possible	
		- "tentative 'no' voting"
		- liquid democracy style delegation
		- delegate your vote to a Backfeed reputation system
*/


import "./theDAO/DAO.sol";


contract VoteDelegatorInterface {
	// the address of TheDAO
    address thedao_address;

    // proposals that have been voted on
    Proposal[] proposals;
    // maps daoProposalIDs to an index in proposals 
    mapping (uint => uint) proposal_idx;

    // accounts with tokens managed by this contract
    address[] accounts;
    // map delegator addresses to in indexes in accounts
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

    /// Total amount of tokens delegated
    uint256 totalSupply;

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
    function vote(
        uint _proposalID,
        bool _supportsProposal
    );

}


contract VoteDelegator is VoteDelegatorInterface {

	function VoteDelegator(address _thedao_address) {
		// constructor function
		thedao_address = _thedao_address;
	}	

	function getAccount(address _delegator) internal returns (DelegatedTokenAccount) {
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

	function delegate(uint256 _value) public returns (bool success) {

		DAO thedao = DAO(thedao_address);
		// get the account of the sender
		DelegatedTokenAccount account = getAccount(msg.sender);
		if (account.getBalance() > 0) {
			// for reasons of mental sanity, a user can only delegate his tokens 
			// once to this delegator. (This can be fixed with some more bookkeeping)
			throw;
		}

		if (thedao.allowance(msg.sender, address(this)) < _value) {
			// Please call approve(address(this), _value) on the DAO contract
			throw;
		}

		// transfer _value tokens to the senders Delegatedaccount
		if(thedao.transferFrom(msg.sender, address(account), _value)){
			totalSupply += _value;
			return true;
		} else {
			// if transfer fails, do nothing
			throw;
		}
	}

	function undelegate() public returns (bool success) {
		// get the account
		DelegatedTokenAccount account = getAccount(msg.sender);

		// close the account - it will not participate in any new votes
		if (account.is_active()) {
			account.disactivate();

			totalSupply -= account.getBalance();

			// update all talleys of open proposals where this user has voted
			// this is not needed, because if the funds are free
			for (uint i=0;i<proposals.length;i++) {
				Proposal p = proposals[i];
				if (!p.closed) {
					if (p.votedYes[msg.sender]) {
						p.yea -= account.getBalance();
					}
					if (p.votedNo[msg.sender]) {
						p.nay -= account.getBalance();
					}
				}
			}
		}

		// now ty to get the tokens back to msg.sender
		account.returnTokens();
		return true;

	}

	function vote(uint _proposalID, bool _supportsProposal) public {
		// get the account of the sender
		DelegatedTokenAccount account = getAccount(msg.sender);
		if (account.getBalance() == 0) {
			throw;
		}
		Proposal proposal;
		// get (or create) the Proposal
		if (proposal_idx[_proposalID] == 0) {
			// TODO: check if the proposal exists in the DAO

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
			proposal.yea += account.getBalance();
			proposal.votedYes[msg.sender] = true;
		} else {
			proposal.nay += account.getBalance();
			proposal.votedNo[msg.sender] = true;
		}
		copyVote(proposal);
	}

    function vote_in_thedao(
        uint _proposalID,
        bool _supportsProposal
    ) internal {
    	// vote with *all* active accounts for this proposal
		for (uint i=0;i<accounts.length;i++) {
			address account_adress = accounts[i];
			DelegatedTokenAccount account = DelegatedTokenAccount(account_adress);
			if (account.is_active()) {
				account.vote(_proposalID, _supportsProposal);
			}
		}
	}


	function copyVote(Proposal proposal) internal {
		/* 
		Actually vote for the DAO
		   this is where the magic of the contract is supposed to happen
		   we can insert here any logic that seems reasonable:
		   		- majority votes
		  		- follow the leader votes
		  		- an implementation of the Backfeed Protocol
		   for demonstration purposes, we implement a simple majority rule
		   if more than half of the tokens votes yea (or nay), we copy
		   that vote to the DAO for *all* tokens
		*/
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
	// the address that the tokens are delegated to
	address owner;
	// the address of the delegator of the tokens
	address delegator;
	// the address of the DAO
	address thedao_address;
	// true if this account is used for voting
	bool active;

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
		// return all tokens in this account to the delegator
		if (msg.sender != owner) {
			throw;
		}	
		DAO thedao = DAO(thedao_address);
		uint balance = thedao.balanceOf(address(this));
		thedao.transfer(delegator, balance);
	}

	function getBalance() returns (uint _balance) {
		// return the balance of this acccount (in the DAO)
		DAO thedao = DAO(thedao_address);
		uint balance = thedao.balanceOf(address(this));
	}

	function disactivate() {
		active = false;
	}

	function is_active() returns (bool _is_active) {
		return active;	
	}

	function vote(
        uint _proposalID,
        bool _supportsProposal
    ) returns (uint _voteID) {
    	// vote in the DAO
    	if (msg.sender != owner) {
    		throw;	
    	}
		DAO thedao = DAO(thedao_address);
		return thedao.vote(_proposalID, _supportsProposal);
	}
}