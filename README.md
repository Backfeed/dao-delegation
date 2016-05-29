# dao-delegation

The VoteDelegator contract provides way of delegating your votes in theDAO

It is meant as a quick way of adding delegation to the DAO
without having to change theDAO contract

It works like this. 

(Here, "theDAO" refers to the DAO contract on the blockchain, and
"theDelegator" to a VoteDelegator contract on the blockchain)

1)  Tell the The DAO that VoteDelegator is allowed to handle your DAO tokens 

        theDAO.approve(address(theDelegator), amount_of_tokens)

2)  put your DAO tokens in control of the VoteDelegator:

        theDelegator.delegate(amount_of_tokens)

3)  Now you can vote by simply calling the "vote" function on the 
delegator contract (exactly as you would vote on the DAO)

         theDelegator.vote(_proposalID, _supportsProposal)

the Delegator contract will then register your vote internally, 
the Delegator will only vote in the DAO itself when certain
conditions are met (in this contract, if the majority of the token holders
that delegated their vote to this contract voted yes/no)

4)  If you want to remove your delegation and have your DAO tokens back, call:

        theDelegator.undelegate()

This will make it so that the VoteDelegator will not use your tokens 
for new votes any more. Your tokens my still be locked in a current vote,
so you'll have to wait until they are unlocked to call "undelegate" again
to transfer them back to you.

Some use cases are:

- "tentative 'no' voting"
- liquid democracy style delegation
- last-minute voting to keep you tokens locked up as little as possible 
- delegate your vote to a Backfeed reputation system
