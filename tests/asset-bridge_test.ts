import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Should register a game successfully",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    
    const block = chain.mineBlock([
      Tx.contractCall(
        'asset-bridge',
        'register-game',
        [
          types.utf8('Fantasy Quest'),
          types.utf8('Epic fantasy adventure game with magical creatures'),
          types.uint(300), // 3% revenue share
          types.utf8('https://fantasyquest.com')
        ],
        deployer.address
      ),
    ]);
    
    assertEquals(block.receipts.length, 1);
    assertEquals(block.receipts[0].result.expectOk(), types.uint(1));
  },
});

Clarinet.test({
  name: "Should mint gaming asset by authorized game developer",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const player1 = accounts.get('wallet_1')!;
    
    // First register a game
    let block = chain.mineBlock([
      Tx.contractCall(
        'asset-bridge',
        'register-game',
        [
          types.utf8('Fantasy Quest'),
          types.utf8('Epic fantasy adventure game'),
          types.uint(300),
          types.utf8('https://fantasyquest.com')
        ],
        deployer.address
      ),
    ]);
    
    // Then mint an asset
    block = chain.mineBlock([
      Tx.contractCall(
        'asset-bridge',
        'mint-gaming-asset',
        [
          types.principal(player1.address),
          types.uint(1), // game-id
          types.uint(1), // TYPE_CHARACTER
          types.utf8('Dragon Warrior'),
          types.utf8('A legendary warrior with dragon powers'),
          types.uint(5), // RARITY_LEGENDARY
          types.uint(50),
          types.utf8('https://metadata.fantasyquest.com/dragon-warrior')
        ],
        deployer.address
      ),
    ]);
    
    assertEquals(block.receipts.length, 1);
    assertEquals(block.receipts[0].result.expectOk(), types.uint(1));
  },
});

Clarinet.test({
  name: "Should fail to mint asset by unauthorized user",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const unauthorized = accounts.get('wallet_1')!;
    const player = accounts.get('wallet_2')!;
    
    // Register a game
    let block = chain.mineBlock([
      Tx.contractCall(
        'asset-bridge',
        'register-game',
        [
          types.utf8('Fantasy Quest'),
          types.utf8('Epic fantasy adventure game'),
          types.uint(300),
          types.utf8('https://fantasyquest.com')
        ],
        deployer.address
      ),
    ]);
    
    // Try to mint from unauthorized account
    block = chain.mineBlock([
      Tx.contractCall(
        'asset-bridge',
        'mint-gaming-asset',
        [
          types.principal(player.address),
          types.uint(1),
          types.uint(1),
          types.utf8('Fake Asset'),
          types.utf8('This should not work'),
          types.uint(1),
          types.uint(1),
          types.utf8('fake-uri')
        ],
        unauthorized.address
      ),
    ]);
    
    assertEquals(block.receipts.length, 1);
    assertEquals(block.receipts[0].result.expectErr(), types.uint(100)); // ERR_NOT_AUTHORIZED
  },
});

Clarinet.test({
  name: "Should transfer asset between players",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const player1 = accounts.get('wallet_1')!;
    const player2 = accounts.get('wallet_2')!;
    
    // Register game and mint asset
    let block = chain.mineBlock([
      Tx.contractCall('asset-bridge', 'register-game', [
        types.utf8('Fantasy Quest'),
        types.utf8('Epic fantasy adventure game'),
        types.uint(300),
        types.utf8('https://fantasyquest.com')
      ], deployer.address),
      
      Tx.contractCall('asset-bridge', 'mint-gaming-asset', [
        types.principal(player1.address),
        types.uint(1),
        types.uint(1),
        types.utf8('Dragon Sword'),
        types.utf8('A powerful magical sword'),
        types.uint(3), // RARE
        types.uint(25),
        types.utf8('https://metadata.fantasyquest.com/dragon-sword')
      ], deployer.address),
    ]);
    
    // Transfer asset
    block = chain.mineBlock([
      Tx.contractCall(
        'asset-bridge',
        'transfer-asset',
        [
          types.uint(1), // asset-id
          types.principal(player2.address)
        ],
        player1.address
      ),
    ]);
    
    assertEquals(block.receipts.length, 1);
    assertEquals(block.receipts[0].result.expectOk(), types.uint(1));
  },
});

Clarinet.test({
  name: "Should list and sell asset on marketplace",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const seller = accounts.get('wallet_1')!;
    const buyer = accounts.get('wallet_2')!;
    
    // Setup: register game, mint asset
    let block = chain.mineBlock([
      Tx.contractCall('asset-bridge', 'register-game', [
        types.utf8('Fantasy Quest'),
        types.utf8('Epic fantasy adventure game'),
        types.uint(300),
        types.utf8('https://fantasyquest.com')
      ], deployer.address),
      
      Tx.contractCall('asset-bridge', 'mint-gaming-asset', [
        types.principal(seller.address),
        types.uint(1),
        types.uint(2), // TYPE_WEAPON
        types.utf8('Flame Blade'),
        types.utf8('A sword engulfed in eternal flames'),
        types.uint(4), // EPIC
        types.uint(40),
        types.utf8('https://metadata.fantasyquest.com/flame-blade')
      ], deployer.address),
    ]);
    
    // List asset for sale
    block = chain.mineBlock([
      Tx.contractCall(
        'asset-bridge',
        'list-asset-for-sale',
        [
          types.uint(1), // asset-id
          types.uint(1000000), // price in microSTX
          types.uint(100) // duration in blocks
        ],
        seller.address
      ),
    ]);
    
    assertEquals(block.receipts[0].result.expectOk(), types.uint(1));
    
    // Buy asset
    block = chain.mineBlock([
      Tx.contractCall(
        'asset-bridge',
        'buy-asset',
        [types.uint(1)],
        buyer.address
      ),
    ]);
    
    assertEquals(block.receipts[0].result.expectOk(), types.uint(1));
  },
});

Clarinet.test({
  name: "Should perform cross-game asset transfer",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const dev2 = accounts.get('wallet_1')!;
    const player = accounts.get('wallet_2')!;
    
    // Register two games
    let block = chain.mineBlock([
      Tx.contractCall('asset-bridge', 'register-game', [
        types.utf8('Fantasy Quest'),
        types.utf8('Epic fantasy adventure game'),
        types.uint(300),
        types.utf8('https://fantasyquest.com')
      ], deployer.address),
      
      Tx.contractCall('asset-bridge', 'register-game', [
        types.utf8('Space Warriors'),
        types.utf8('Futuristic space combat game'),
        types.uint(250),
        types.utf8('https://spacewarriors.com')
      ], dev2.address),
    ]);
    
    // Mint asset in first game
    block = chain.mineBlock([
      Tx.contractCall('asset-bridge', 'mint-gaming-asset', [
        types.principal(player.address),
        types.uint(1), // Fantasy Quest
        types.uint(1),
        types.utf8('Magic Crystal'),
        types.utf8('A mystical energy source'),
        types.uint(2), // UNCOMMON
        types.uint(10),
        types.utf8('https://metadata.fantasyquest.com/magic-crystal')
      ], deployer.address),
    ]);
    
    // Transfer asset to second game
    block = chain.mineBlock([
      Tx.contractCall(
        'asset-bridge',
        'cross-game-transfer',
        [
          types.uint(1), // asset-id
          types.uint(2)  // target Space Warriors game
        ],
        player.address
      ),
    ]);
    
    assertEquals(block.receipts[0].result.expectOk(), types.uint(1));
  },
});

Clarinet.test({
  name: "Should retrieve asset details and statistics",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const player = accounts.get('wallet_1')!;
    
    // Setup: register game and mint asset
    let block = chain.mineBlock([
      Tx.contractCall('asset-bridge', 'register-game', [
        types.utf8('Fantasy Quest'),
        types.utf8('Epic fantasy adventure game'),
        types.uint(300),
        types.utf8('https://fantasyquest.com')
      ], deployer.address),
      
      Tx.contractCall('asset-bridge', 'mint-gaming-asset', [
        types.principal(player.address),
        types.uint(1),
        types.uint(5), // TYPE_COLLECTIBLE
        types.utf8('Golden Crown'),
        types.utf8('A crown worn by ancient kings'),
        types.uint(6), // MYTHIC
        types.uint(1),
        types.utf8('https://metadata.fantasyquest.com/golden-crown')
      ], deployer.address),
    ]);
    
    // Get asset details
    const assetDetails = chain.callReadOnlyFn(
      'asset-bridge',
      'get-asset-details',
      [types.uint(1)],
      deployer.address
    );
    
    const asset = assetDetails.result.expectSome().expectTuple();
    assertEquals(asset['name'], types.utf8('Golden Crown'));
    assertEquals(asset['rarity'], types.uint(6));
    assertEquals(asset['asset-type'], types.uint(5));
    
    // Get asset statistics
    const stats = chain.callReadOnlyFn(
      'asset-bridge',
      'get-asset-statistics',
      [types.uint(1)],
      deployer.address
    );
    
    const statistics = stats.result.expectSome().expectTuple();
    assertEquals(statistics['total-transfers'], types.uint(0));
    assertEquals(statistics['total-sales'], types.uint(0));
  },
});

Clarinet.test({
  name: "Should get marketplace statistics",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    
    // Register a game
    let block = chain.mineBlock([
      Tx.contractCall('asset-bridge', 'register-game', [
        types.utf8('Fantasy Quest'),
        types.utf8('Epic fantasy adventure game'),
        types.uint(300),
        types.utf8('https://fantasyquest.com')
      ], deployer.address),
    ]);
    
    // Get marketplace stats
    const stats = chain.callReadOnlyFn(
      'asset-bridge',
      'get-marketplace-stats',
      [],
      deployer.address
    );
    
    const marketStats = stats.result.expectTuple();
    assertEquals(marketStats['total-games'], types.uint(1));
    assertEquals(marketStats['total-assets'], types.uint(0));
    assertEquals(marketStats['total-volume'], types.uint(0));
    assertEquals(marketStats['marketplace-fee'], types.uint(250)); // 2.5%
  },
});