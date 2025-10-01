import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet1 = accounts.get("wallet_1")!;
const wallet2 = accounts.get("wallet_2")!;

describe("Asset Bridge Gaming Contract", () => {
  it("should register a game successfully", () => {
    const { result } = simnet.callPublicFn(
      "asset-bridge",
      "register-game",
      [
        Cl.stringUtf8("Fantasy Quest"),
        Cl.stringUtf8("Epic fantasy adventure game"),
        Cl.uint(300),
        Cl.stringUtf8("https://fantasyquest.com")
      ],
      deployer
    );
    expect(result).toBeOk(Cl.uint(1));
  });

  it("should mint gaming asset by authorized game developer", () => {
    // First register a game
    simnet.callPublicFn(
      "asset-bridge",
      "register-game",
      [
        Cl.stringUtf8("Fantasy Quest"),
        Cl.stringUtf8("Epic fantasy adventure game"),
        Cl.uint(300),
        Cl.stringUtf8("https://fantasyquest.com")
      ],
      deployer
    );

    // Then mint an asset
    const { result } = simnet.callPublicFn(
      "asset-bridge",
      "mint-gaming-asset",
      [
        Cl.principal(wallet1),
        Cl.uint(1), // game-id
        Cl.uint(1), // TYPE_CHARACTER
        Cl.stringUtf8("Dragon Warrior"),
        Cl.stringUtf8("A legendary warrior with dragon powers"),
        Cl.uint(5), // RARITY_LEGENDARY
        Cl.uint(50),
        Cl.stringUtf8("https://metadata.fantasyquest.com/dragon-warrior")
      ],
      deployer
    );
    expect(result).toBeOk(Cl.uint(1));
  });

  it("should fail to mint asset by unauthorized user", () => {
    // Register a game
    simnet.callPublicFn(
      "asset-bridge",
      "register-game",
      [
        Cl.stringUtf8("Fantasy Quest"),
        Cl.stringUtf8("Epic fantasy adventure game"),
        Cl.uint(300),
        Cl.stringUtf8("https://fantasyquest.com")
      ],
      deployer
    );

    // Try to mint from unauthorized account
    const { result } = simnet.callPublicFn(
      "asset-bridge",
      "mint-gaming-asset",
      [
        Cl.principal(wallet2),
        Cl.uint(1),
        Cl.uint(1),
        Cl.stringUtf8("Fake Asset"),
        Cl.stringUtf8("This should not work"),
        Cl.uint(1),
        Cl.uint(1),
        Cl.stringUtf8("fake-uri")
      ],
      wallet1
    );
    expect(result).toBeErr(Cl.uint(100)); // ERR_NOT_AUTHORIZED
  });

  it("should transfer asset between players", () => {
    // Register game and mint asset
    simnet.callPublicFn(
      "asset-bridge",
      "register-game",
      [
        Cl.stringUtf8("Fantasy Quest"),
        Cl.stringUtf8("Epic fantasy adventure game"),
        Cl.uint(300),
        Cl.stringUtf8("https://fantasyquest.com")
      ],
      deployer
    );

    simnet.callPublicFn(
      "asset-bridge",
      "mint-gaming-asset",
      [
        Cl.principal(wallet1),
        Cl.uint(1),
        Cl.uint(1),
        Cl.stringUtf8("Dragon Sword"),
        Cl.stringUtf8("A powerful magical sword"),
        Cl.uint(3), // RARE
        Cl.uint(25),
        Cl.stringUtf8("https://metadata.fantasyquest.com/dragon-sword")
      ],
      deployer
    );

    // Transfer asset
    const { result } = simnet.callPublicFn(
      "asset-bridge",
      "transfer-asset",
      [Cl.uint(1), Cl.principal(wallet2)],
      wallet1
    );
    expect(result).toBeOk(Cl.uint(1));
  });

  it("should perform cross-game asset transfer", () => {
    // Register two games
    simnet.callPublicFn(
      "asset-bridge",
      "register-game",
      [
        Cl.stringUtf8("Fantasy Quest"),
        Cl.stringUtf8("Epic fantasy adventure game"),
        Cl.uint(300),
        Cl.stringUtf8("https://fantasyquest.com")
      ],
      deployer
    );

    simnet.callPublicFn(
      "asset-bridge",
      "register-game",
      [
        Cl.stringUtf8("Space Warriors"),
        Cl.stringUtf8("Futuristic space combat game"),
        Cl.uint(250),
        Cl.stringUtf8("https://spacewarriors.com")
      ],
      wallet1
    );

    // Mint asset in first game
    simnet.callPublicFn(
      "asset-bridge",
      "mint-gaming-asset",
      [
        Cl.principal(wallet2),
        Cl.uint(1), // Fantasy Quest
        Cl.uint(1),
        Cl.stringUtf8("Magic Crystal"),
        Cl.stringUtf8("A mystical energy source"),
        Cl.uint(2), // UNCOMMON
        Cl.uint(10),
        Cl.stringUtf8("https://metadata.fantasyquest.com/magic-crystal")
      ],
      deployer
    );

    // Transfer asset to second game
    const { result } = simnet.callPublicFn(
      "asset-bridge",
      "cross-game-transfer",
      [Cl.uint(1), Cl.uint(2)], // asset-id, target game
      wallet2
    );
    expect(result).toBeOk(Cl.uint(1));
  });

  it("should retrieve asset details and statistics", () => {
    // Setup: register game and mint asset
    simnet.callPublicFn(
      "asset-bridge",
      "register-game",
      [
        Cl.stringUtf8("Fantasy Quest"),
        Cl.stringUtf8("Epic fantasy adventure game"),
        Cl.uint(300),
        Cl.stringUtf8("https://fantasyquest.com")
      ],
      deployer
    );

    simnet.callPublicFn(
      "asset-bridge",
      "mint-gaming-asset",
      [
        Cl.principal(wallet1),
        Cl.uint(1),
        Cl.uint(5), // TYPE_COLLECTIBLE
        Cl.stringUtf8("Golden Crown"),
        Cl.stringUtf8("A crown worn by ancient kings"),
        Cl.uint(6), // MYTHIC
        Cl.uint(1),
        Cl.stringUtf8("https://metadata.fantasyquest.com/golden-crown")
      ],
      deployer
    );

    // Get asset details
    const { result: assetDetails } = simnet.callReadOnlyFn(
      "asset-bridge",
      "get-asset-details",
      [Cl.uint(1)],
      deployer
    );
    
    expect(assetDetails).toBeDefined();
    expect(assetDetails.value).toBeDefined();
  });

  it("should get marketplace statistics", () => {
    // Register a game
    simnet.callPublicFn(
      "asset-bridge",
      "register-game",
      [
        Cl.stringUtf8("Fantasy Quest"),
        Cl.stringUtf8("Epic fantasy adventure game"),
        Cl.uint(300),
        Cl.stringUtf8("https://fantasyquest.com")
      ],
      deployer
    );

    // Get marketplace stats
    const { result: stats } = simnet.callReadOnlyFn(
      "asset-bridge",
      "get-marketplace-stats",
      [],
      deployer
    );

    const marketStats = stats.data;
    expect(marketStats["total-games"]).toStrictEqual(Cl.uint(1));
    expect(marketStats["total-assets"]).toStrictEqual(Cl.uint(0));
    expect(marketStats["total-volume"]).toStrictEqual(Cl.uint(0));
    expect(marketStats["marketplace-fee"]).toStrictEqual(Cl.uint(250)); // 2.5%
  });
});
