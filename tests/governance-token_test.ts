import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.5.1/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

Clarinet.test({
  name: "Wrap Voting: Token Minting and Basic Functionality",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;

    let block = chain.mineBlock([
      Tx.contractCall('governance-token', 'mint-tokens', 
        [types.principal(wallet1.address), types.uint(1000000)], 
        deployer.address
      )
    ]);

    // Assert successful token minting
    block.receipts[0].result.expectOk();

    // Check token balance
    let balance = chain.callReadOnlyFn('governance-token', 'get-token-balance', 
      [types.principal(wallet1.address)], 
      wallet1.address
    );
    balance.result.expectOk().expectUint(1000000);
  }
});

Clarinet.test({
  name: "Wrap Voting: Proposal Creation and Voting",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;

    // Mint tokens for voting
    chain.mineBlock([
      Tx.contractCall('governance-token', 'mint-tokens', 
        [types.principal(wallet1.address), types.uint(1000000)], 
        deployer.address
      ),
      Tx.contractCall('governance-token', 'mint-tokens', 
        [types.principal(wallet2.address), types.uint(500000)], 
        deployer.address
      )
    ]);

    // Create a proposal
    let createProposalBlock = chain.mineBlock([
      Tx.contractCall('governance-token', 'create-proposal', 
        [
          types.ascii("Token Upgrade Proposal"), 
          types.ascii("Proposal to upgrade governance mechanism"), 
          types.uint(100)
        ], 
        wallet1.address
      )
    ]);

    createProposalBlock.receipts[0].result.expectOk().expectUint(1);

    // Vote on the proposal
    let voteBlock = chain.mineBlock([
      Tx.contractCall('governance-token', 'vote-on-proposal', 
        [types.uint(1), types.bool(true)], 
        wallet1.address
      ),
      Tx.contractCall('governance-token', 'vote-on-proposal', 
        [types.uint(1), types.bool(false)], 
        wallet2.address
      )
    ]);

    voteBlock.receipts[0].result.expectOk();
    voteBlock.receipts[1].result.expectOk();

    // Verify proposal details
    let proposalDetails = chain.callReadOnlyFn('governance-token', 'get-proposal-details', 
      [types.uint(1)], 
      deployer.address
    );
    
    // Detailed assertions can be added here to verify vote counts
  }
});