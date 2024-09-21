import {
  aptos,
  getAccountFromPrivateKey,
  compilePackage,
  getPackageBytes,
  publishPackage,
  submitTx,
  getAdminAccount,
} from "../util";
import { Account } from "@aptos-labs/ts-sdk";
import { readFile, writeFile } from "fs/promises";
import { getRegisterBiUwUTx } from "../transactions";
import * as path from "path";
import * as os from "os";

const adminAccount = getAdminAccount();

export async function createCoin(name: string, symbol: string) {
  const coinAccount = Account.generate();
  await aptos.fundAccount({
    accountAddress: coinAccount.accountAddress,
    amount: 100_000_000,
  });

  await compilePackage(
    path.resolve(__dirname, "../../move/vtuber_coin"),
    path.resolve(os.tmpdir(), "vtuber_coin.json"),
    [{ name: "vtuber_coin", address: coinAccount.accountAddress }],
  );
  const { metadataBytes, moduleBytecode } = await getPackageBytes(
    path.resolve(os.tmpdir(), "vtuber_coin.json"),
  );
  await publishPackage(coinAccount, metadataBytes, moduleBytecode);

  let tx = await aptos.transaction.build.simple({
    sender: coinAccount.accountAddress,
    data: {
      function: `${coinAccount.accountAddress}::vtuber_coin::initialize`,
      functionArguments: [name, symbol],
    },
  });
  await submitTx(coinAccount, tx);

  let data = await readFile("coin-accounts-list.json", "utf-8");
  let jsonData = JSON.parse(data);
  jsonData.coinAccounts.push({
    address: coinAccount.accountAddress.toString(),
    privateKey: coinAccount.privateKey.toString(),
  });
  await writeFile("coin-accounts-list.json", JSON.stringify(jsonData, null, 2));

  tx = await getRegisterBiUwUTx(coinAccount.accountAddress.toString());
  await submitTx(coinAccount, tx);

  return coinAccount.privateKey.toString();
}

export async function mintCoin(
  coinPrivateKey: string,
  userAddress: string,
  amount: number,
) {
  const coinAccount = getAccountFromPrivateKey(coinPrivateKey);
  const tx = await aptos.transaction.build.simple({
    sender: coinAccount.accountAddress,
    data: {
      function: `0x1::managed_coin::mint`,
      typeArguments: [`${coinAccount.accountAddress}::vtuber_coin::VtuberCoin`],
      functionArguments: [userAddress, amount],
    },
  });
  await submitTx(coinAccount, tx);
}

export async function mintBiUwU(userAddress: string, amount: number) {
  const tx = await aptos.transaction.build.simple({
    sender: adminAccount.accountAddress,
    data: {
      function: `0x1::managed_coin::mint`,
      typeArguments: [`${adminAccount.accountAddress}::biuwu_coin::BiUwU`],
      functionArguments: [userAddress, amount],
    },
  });
  await submitTx(adminAccount, tx);
}
