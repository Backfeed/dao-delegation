# Dao Delegation

The VoteDelegator contract provides way of delegating your votes in theDAO.

It is meant as a quick way of adding delegation to the DAO
without having to change theDAO contract

The contract can be seen as a generic container that can be adapted to particular use cases. 

*It's proof-of-concept code, not production ready in any way*


# Use Cases

## "tentative 'no' voting"

One can pool a set of 'no' votes in a Delegator contract, and only cast the 'no' vote if a) the quorum will be met also without these votes and (2) the no votes are more then the yes votes. This mitigates the cost of voting No somewhat because it will only block your votes if it is strictly necessary.

## Liquid democracy style delegation

Delegate your vote to a contract controlled by a known expert. You can undelegate your delegate whenever you want.
(The next step would be to delegate your votes to different delegates, depending on the proposal. This will take some more work to code)

## Last-minute voting

Delegate your vote to a contract that will only copy your vote to the DAO in the last N minutes before the deadline. This will keep your tokens locked up a minimum as possible.

## Backfeed style delegation

Pool your tokens together with others, and use the Backfeed protocol to decide together on the best course of action.


# Usage

(Here, "theDAO" refers to the DAO contract on the blockchain, and
"theDelegator" to a VoteDelegator contract on the blockchain)

1. Tell the DAO that VoteDelegator is allowed to handle your DAO tokens 

        theDAO.approve(address(theDelegator), amount_of_tokens)

1. Put your DAO tokens in control of the VoteDelegator:

        theDelegator.delegate(amount_of_tokens)

1. Optionally you can vote by calling the `vote` function on the 
   delegator contract (exactly as you would vote in the DAO)

        theDelegator.vote(_proposalID, _supportsProposal)

    the Delegator contract will then register your vote internally, 
    
    In the current example contract, the VoteDelegator will only vote in the DAO itself when the majority of the token holders that delegated their vote to this contract voted yes/no).

1. If you want to remove your delegation and have your DAO tokens back, call:

        theDelegator.undelegate()

    This will make it so that the VoteDelegator will not use your tokens 
    for new votes any more. Your tokens my still be locked in a current vote,
    so you'll have to wait until they are unlocked to call "undelegate" again
    to transfer them back to you.
